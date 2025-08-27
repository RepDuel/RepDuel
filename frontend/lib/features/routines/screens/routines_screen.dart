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

// The provider is correct and remains unchanged.
final routinesProvider = FutureProvider.autoDispose<List<Routine>>((ref) async {
  final user = ref.watch(authProvider.select((state) => state.valueOrNull?.user));
  if (user == null) return [];
  
  final client = ref.watch(privateHttpClientProvider);
  final response = await client.get('/routines/');
  final List data = response.data;
  return data.map((json) => Routine.fromJson(json)).toList();
});

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  void _onAddRoutinePressed(BuildContext context, WidgetRef ref, List<Routine> routines) {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) return;

    final isFree = user.subscriptionLevel == 'free';
    final hasReachedLimit = routines.where((r) => r.userId == user.id).length >= 3;

    if (isFree && hasReachedLimit) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text('Free users can create up to 3 custom routines. Upgrade to unlock more.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
      context.pushNamed('createRoutine');
    }
  }

  Future<void> _deleteRoutine(BuildContext context, WidgetRef ref, String routineId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete routine?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);
    final currentUserId = ref.watch(authProvider).valueOrNull?.user?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Routines'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(routinesProvider.future),
        child: routinesAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.refresh(routinesProvider))),
          data: (routines) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: routines.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (MediaQuery.of(context).size.width ~/ 250).clamp(2, 6),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65, // Adjusted aspect ratio
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AddRoutineCard(onPressed: () => _onAddRoutinePressed(context, ref, routines));
                }
                final routine = routines[index - 1];
                final canEditDelete = routine.userId != null && routine.userId == currentUserId;
                
                // --- THIS IS THE FIX ---
                // Wrap the display-only RoutineCard in a Stack to overlay interactive elements.
                return Stack(
                  children: [
                    // The main tappable area
                    GestureDetector(
                      onTap: () => context.pushNamed('exerciseList', pathParameters: {'routineId': routine.id}),
                      child: RoutineCard(
                        name: routine.name,
                        imageUrl: routine.imageUrl,
                        duration: '${routine.totalDurationMinutes} min',
                        difficultyLevel: 2, // This could come from the routine model
                      ),
                    ),
                    // The edit/delete menu, only shown if the user owns the routine
                    if (canEditDelete)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.pushNamed('editRoutine', extra: routine);
                            } else if (value == 'delete') {
                              _deleteRoutine(context, ref, routine.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                  ],
                );
                // --- END OF FIX ---
              },
            );
          },
        ),
      ),
    );
  }
}