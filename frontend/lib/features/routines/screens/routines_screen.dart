// frontend/lib/features/routines/screens/routines_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/routine.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../widgets/add_routine_card.dart';
import '../widgets/routine_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final routinesProvider = FutureProvider.autoDispose<List<Routine>>((ref) async {
  return ref.watch(authProvider).when(
        loading: () => Future.value([]),
        error: (e, s) => throw e,
        data: (authState) async {
          if (authState.user == null) return [];
          final client = ref.watch(privateHttpClientProvider);
          final response = await client.get('/routines/');
          final List data = response.data;
          return data.map((json) => Routine.fromJson(json)).toList();
        },
      );
});

// Stores the set of globally hidden routine IDs for the current user in SharedPreferences
final hiddenGlobalRoutinesProvider =
    StateNotifierProvider.autoDispose<HiddenRoutinesNotifier, Set<String>>(
        (ref) => HiddenRoutinesNotifier(ref));

class HiddenRoutinesNotifier extends StateNotifier<Set<String>> {
  final Ref ref;
  HiddenRoutinesNotifier(this.ref) : super(<String>{}) {
    _init();
    // Reload when user switches
    ref.listen(authProvider, (prev, next) {
      final prevId = prev?.valueOrNull?.user?.id.toString();
      final nextId = next.valueOrNull?.user?.id.toString();
      if (prevId != nextId) {
        _init();
      }
    });
  }

  String _prefsKeyFor(String? userId) => 'hidden_routines_${userId ?? 'anon'}';

  Future<void> _init() async {
    final userId = ref.read(authProvider).valueOrNull?.user?.id.toString();
    // Try server first
    try {
      final client = ref.read(privateHttpClientProvider);
      final res = await client.get('/users/me/hidden-routines');
      if (res.statusCode == 200) {
        final List data = res.data as List;
        state = data.map((e) => e.toString()).toSet();
        // mirror to local prefs as offline cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_prefsKeyFor(userId), state.toList());
        return;
      }
    } catch (_) {
      // fall through to local cache
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKeyFor(userId)) ?? <String>[];
    state = list.toSet();
  }

  Future<void> _persist() async {
    final userId = ref.read(authProvider).valueOrNull?.user?.id.toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyFor(userId), state.toList());
  }

  Future<void> hide(String id) async {
    if (state.contains(id)) return;
    // Optimistic update
    state = {...state, id};
    try {
      final client = ref.read(privateHttpClientProvider);
      await client.post('/users/me/hidden-routines/$id');
    } catch (_) {}
    await _persist();
  }

  Future<void> unhide(String id) async {
    if (!state.contains(id)) return;
    final next = {...state}..remove(id);
    state = next;
    try {
      final client = ref.read(privateHttpClientProvider);
      await client.delete('/users/me/hidden-routines/$id');
    } catch (_) {}
    await _persist();
  }

  Future<void> toggle(String id) async {
    if (state.contains(id)) {
      await unhide(id);
    } else {
      await hide(id);
    }
  }
}

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  Future<void> _onAddRoutinePressed(
      BuildContext context, WidgetRef ref, List<Routine> routines) async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) return;
    final isFree = user.subscriptionLevel == 'free';
    final hasReachedLimit =
        routines.where((r) => r.userId == user.id).length >= 3;
    if (isFree && hasReachedLimit) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
              'Free users can create up to 3 custom routines. Upgrade to unlock more.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/subscribe');
              },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );
    } else {
      final result = await context.pushNamed<bool>('createRoutine');
      if (result == true && context.mounted) {
        ref.invalidate(routinesProvider);
      }
    }
  }

  Future<void> _deleteRoutine(
      BuildContext context, WidgetRef ref, String routineId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final client = ref.read(privateHttpClientProvider);
        await client.delete('/routines/$routineId');
        ref.invalidate(routinesProvider);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);
    final currentUserId = ref.watch(authProvider).valueOrNull?.user?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(routinesProvider.future),
        child: routinesAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(
              child: ErrorDisplay(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(routinesProvider))),
          data: (routines) {
            final hidden = ref.watch(hiddenGlobalRoutinesProvider);
            // Filter out hidden global routines (those without a userId)
            final visibleRoutines = routines
                .where((r) => !(r.userId == null && hidden.contains(r.id)))
                .toList();
            if (visibleRoutines.isEmpty) {
              // Keeps the content scrollable to avoid overflow when centered.
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height * 0.7),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("No routines found.",
                            style: TextStyle(color: Colors.grey, fontSize: 18)),
                        const SizedBox(height: 8),
                        const Text("Pull down to refresh or create one!",
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 220,
                          child: AddRoutineCard(
                              onPressed: () =>
                                  _onAddRoutinePressed(context, ref, routines)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visibleRoutines.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    (MediaQuery.of(context).size.width ~/ 250).clamp(2, 6),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AddRoutineCard(
                      onPressed: () =>
                          _onAddRoutinePressed(context, ref, routines));
                }
                final routine = visibleRoutines[index - 1];
                final canEditDelete =
                    routine.userId != null && routine.userId == currentUserId;
                final isGlobal = routine.userId == null;
                final isHidden = hidden.contains(routine.id);

                return Stack(
                  children: [
                    GestureDetector(
                      // ✅ Navigate to RoutinePlay using Option A (pass the object via `extra`)
                      onTap: () =>
                          context.pushNamed('routinePlay', extra: routine),
                      child: RoutineCard(
                        name: routine.name,
                        imageUrl: routine.imageUrl,
                        duration: '${routine.totalDurationMinutes} min',
                        difficultyLevel: 2,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        icon:
                            const Icon(Icons.more_vert, color: Colors.white70),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            final result = await context.pushNamed<bool>(
                                'editRoutine',
                                extra: routine);
                            if (result == true && context.mounted) {
                              ref.invalidate(routinesProvider);
                            }
                          } else if (value == 'delete') {
                            _deleteRoutine(context, ref, routine.id);
                          } else if (value == 'hide') {
                            await ref
                                .read(hiddenGlobalRoutinesProvider.notifier)
                                .hide(routine.id);
                          } else if (value == 'unhide') {
                            await ref
                                .read(hiddenGlobalRoutinesProvider.notifier)
                                .unhide(routine.id);
                          }
                        },
                        itemBuilder: (context) {
                          final items = <PopupMenuEntry<String>>[];
                          if (canEditDelete) {
                            items.addAll(const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete',
                                      style: TextStyle(color: Colors.red))),
                            ]);
                          }
                          if (isGlobal) {
                            items.add(
                              PopupMenuItem(
                                  value: isHidden ? 'unhide' : 'hide',
                                  child: Text(isHidden ? 'Unhide' : 'Hide')),
                            );
                          }
                          return items;
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
