// frontend/lib/features/routines/screens/routines_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/env.dart';
import '../../../core/models/routine.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/share_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/routine_row.dart';

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
      if (!mounted) return;
      if (res.statusCode == 200) {
        final List data = res.data as List;
        if (!mounted) return;
        state = data.map((e) => e.toString()).toSet();
        // mirror to local prefs as offline cache
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.setStringList(_prefsKeyFor(userId), state.toList());
        return;
      }
    } catch (_) {
      // fall through to local cache
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final list = prefs.getStringList(_prefsKeyFor(userId)) ?? <String>[];
    if (!mounted) return;
    state = list.toSet();
  }

  Future<void> _persist() async {
    final userId = ref.read(authProvider).valueOrNull?.user?.id.toString();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setStringList(_prefsKeyFor(userId), state.toList());
  }

  Future<void> hide(String id) async {
    if (state.contains(id)) return;
    if (!mounted) return;
    // Optimistic update
    state = {...state, id};
    try {
      final client = ref.read(privateHttpClientProvider);
      await client.post('/users/me/hidden-routines/$id');
    } catch (_) {}
    if (!mounted) return;
    await _persist();
  }

  Future<void> unhide(String id) async {
    if (!state.contains(id)) return;
    if (!mounted) return;
    final next = {...state}..remove(id);
    state = next;
    try {
      final client = ref.read(privateHttpClientProvider);
      await client.delete('/users/me/hidden-routines/$id');
    } catch (_) {}
    if (!mounted) return;
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

class _EmptyRoutinesState extends StatelessWidget {
  const _EmptyRoutinesState({
    required this.onCreateRoutine,
    required this.onImportRoutine,
  });

  final VoidCallback onCreateRoutine;
  final VoidCallback onImportRoutine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 56,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No routines yet',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your own training plan or import a routine to get started.',
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.8) ??
                      theme.colorScheme.onSurfaceVariant,
                ) ??
                TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: theme.textTheme.bodyMedium?.fontSize,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: onCreateRoutine,
                icon: const Icon(Icons.add),
                label: const Text('Create routine'),
              ),
              OutlinedButton.icon(
                onPressed: onImportRoutine,
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
            ],
          ),
        ],
      ),
    );
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
      if (!Env.paymentsEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscriptions are temporarily unavailable.'),
            ),
          );
        }
        return;
      }

      final shouldUpgrade = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
              'Free users can create up to 3 custom routines. Upgrade to unlock more.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );

      if (shouldUpgrade == true && context.mounted) {
        context.push(
          '/subscribe',
          extra: GoRouterState.of(context).uri.toString(),
        );
      }
    } else {
      final result = await context.pushNamed<bool>('createRoutine');
      if (result == true && context.mounted) {
        ref.invalidate(routinesProvider);
      }
    }
  }

  void _startQuickWorkout(BuildContext context) {
    context.pushNamed('freeWorkout');
  }

  Future<Routine?> _prepareRoutineForEditing(
      BuildContext context, WidgetRef ref, Routine routine) async {
    // Already owned by the user → edit in place
    if (routine.userId != null &&
        routine.userId == ref.read(authProvider).valueOrNull?.user?.id) {
      return routine;
    }

    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You need to be signed in to edit routines.')),
        );
      }
      return null;
    }

    // Clone the global routine into a user-owned copy.
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: LoadingSpinner()),
    );

    try {
      final client = ref.read(privateHttpClientProvider);
      final payload = {
        'name': routine.name,
        'image_url': routine.imageUrl,
        'scenarios': routine.scenarios
            .map((s) => {
                  'scenario_id': s.scenarioId,
                  // Backend expects a name; reuse id when unknown.
                  'name': s.scenarioId,
                  'sets': s.sets,
                  'reps': s.reps,
                })
            .toList(),
      };

      final response = await client.post('/routines/', data: payload);
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: response.data,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'Unexpected response when creating routine copy.',
        );
      }

      final cloned = Routine.fromJson(data);

      // Hide the global routine for this user so their customised copy is front-and-centre.
      await ref.read(hiddenGlobalRoutinesProvider.notifier).hide(routine.id);
      ref.invalidate(routinesProvider);
      return cloned;
    } on DioException catch (e) {
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail'] as String?)
          : e.message;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Failed to prepare routine for editing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to prepare routine: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (navigator.mounted) {
        navigator.pop();
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

  Future<void> _importRoutineByCode(
      BuildContext context, WidgetRef ref, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final normalized = code.trim().toUpperCase();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: LoadingSpinner()),
    );

    try {
      final client = ref.read(privateHttpClientProvider);
      final response = await client.post(
        '/routines/import',
        data: {'share_code': normalized},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final detail = response.data is Map<String, dynamic>
            ? (response.data['detail'] as String?)
            : null;
        throw Exception(detail ??
            'Failed to import routine (status ${response.statusCode}).');
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response when importing routine.');
      }

      final importedName = (data['name'] as String?) ?? 'Imported routine';
      ref.invalidate(routinesProvider);

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Added "$importedName" to your routines.')),
        );
      }
    } on DioException catch (err) {
      final message = err.response?.data is Map<String, dynamic>
          ? (err.response?.data['detail'] as String?)
          : err.message;
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(message ?? 'Failed to import routine.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (err) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(err.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (navigator.mounted) {
        navigator.pop();
      }
    }
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to import routines.')),
      );
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Import routine'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Share code',
                      hintText: 'e.g. ABCD1234',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Paste the share code you received to add the routine to your library.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = controller.text.trim().toUpperCase();
                    if (value.length < 4) {
                      setState(() {
                        errorText = 'Enter a valid share code.';
                      });
                      return;
                    }
                    Navigator.of(ctx).pop(value);
                  },
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (code != null && context.mounted) {
      await _importRoutineByCode(context, ref, code);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);
    final currentUserId = ref.watch(authProvider).valueOrNull?.user?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportDialog(context, ref),
        icon: const Icon(Icons.download),
        label: const Text('Import routine'),
      ),
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
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: QuickActionsBar(
                    onQuickWorkout: () => _startQuickWorkout(context),
                    onCreateRoutine: () =>
                        _onAddRoutinePressed(context, ref, routines),
                    onImportRoutine: () => _showImportDialog(context, ref),
                  ),
                ),
                if (visibleRoutines.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyRoutinesState(
                      onCreateRoutine: () =>
                          _onAddRoutinePressed(context, ref, routines),
                      onImportRoutine: () => _showImportDialog(context, ref),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: visibleRoutines.length,
                    separatorBuilder: (context, _) => Divider(
                      height: 1,
                      indent: 92,
                      endIndent: 12,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark
                                ? 0.2
                                : 0.4,
                          ),
                    ),
                    itemBuilder: (context, index) {
                      final routine = visibleRoutines[index];
                      final canEdit = routine.userId == null ||
                          routine.userId == currentUserId;
                      final canDelete =
                          routine.userId != null &&
                              routine.userId == currentUserId;
                      final isGlobal = routine.userId == null;
                      final isHidden = hidden.contains(routine.id);
                      final badges = <String>[];
                      if (routine.scenarios.isNotEmpty) {
                        badges.add(
                            '${routine.scenarios.length} exercise${routine.scenarios.length == 1 ? '' : 's'}');
                      }
                      if (routine.totalSets > 0) {
                        badges.add('${routine.totalSets} set${routine.totalSets == 1 ? '' : 's'}');
                      }
                      badges.add(isGlobal ? 'Global template' : 'My routine');

                      return RoutineRow(
                        title: routine.name,
                        imageUrl: routine.imageUrl,
                        durationMinutes: routine.totalDurationMinutes,
                        badges: badges,
                        onTap: () =>
                            context.pushNamed('routinePlay', extra: routine),
                        menuBuilder: (context) {
                          final items = <PopupMenuEntry<String>>[];
                          if (canEdit) {
                            items.add(const PopupMenuItem(
                                value: 'edit', child: Text('Edit')));
                          }
                          if (canDelete) {
                            items.add(
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                              ),
                            );
                          }
                          if (isGlobal) {
                            items.add(
                              PopupMenuItem(
                                value: isHidden ? 'unhide' : 'hide',
                                child: Text(isHidden ? 'Unhide' : 'Hide'),
                              ),
                            );
                          }
                          items.add(
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share code'),
                            ),
                          );
                          return items;
                        },
                        onMenuSelected: (value) async {
                          if (value == 'edit') {
                            final routineToEdit =
                                await _prepareRoutineForEditing(
                                    context, ref, routine);
                            if (routineToEdit == null) return;
                            if (!context.mounted) return;
                            final result = await context.pushNamed<bool>(
                              'editRoutine',
                              extra: routineToEdit,
                            );
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
                          } else if (value == 'share') {
                            await ref
                                .read(shareServiceProvider)
                                .showShareRoutineDialog(
                                  context: context,
                                  routineId: routine.id,
                                  routineName: routine.name,
                                );
                          }
                        },
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            );
          },
        ),
      ),
    );
  }
}
