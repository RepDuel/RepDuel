// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/routine_details.dart';
import '../../../core/providers/api_providers.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
// Note: We don't import exercise_play_screen directly, we navigate to its route.

// A dedicated provider for fetching routine details.
// It's auto-disposing and takes the routineId as a parameter.
final routineDetailsProvider = FutureProvider.autoDispose.family<RoutineDetails, String>((ref, routineId) async {
  // Use our private http client which includes the auth token automatically.
  final client = ref.watch(privateHttpClientProvider);
  try {
    final response = await client.get('/routines/$routineId');
    return RoutineDetails.fromJson(response.data);
  } catch (e) {
    // The interceptor will handle token errors, but other network errors are caught here.
    throw Exception('Failed to load routine. Please check your connection and try again.');
  }
});


class ExerciseListScreen extends ConsumerWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  // A helper method for the "Finish Routine" button.
  // It's placed here because it's a specific action for this screen.
  Future<void> _finishRoutine(BuildContext context, WidgetRef ref) async {
    try {
      // In a real app, you might show a loading indicator on the button.
      // For now, we'll keep it simple.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finishing routine...'), backgroundColor: Colors.blue),
      );
      
      // Navigate away on success.
      // This is a simplified "finish" action. Your actual implementation might
      // submit final scores or stats here using the privateHttpClientProvider.
      context.go('/routines'); // Or wherever your main routines page is.

    } catch(e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new provider, passing in the routineId from the widget.
    final routineDetailsAsync = ref.watch(routineDetailsProvider(routineId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        // The title updates based on the provider's state.
        title: routineDetailsAsync.when(
          data: (details) => Text(details.name),
          loading: () => const Text('Loading Routine...'),
          error: (_, __) => const Text('Error'),
        ),
      ),
      body: routineDetailsAsync.when(
        // Use the provider's state to build the UI, replacing FutureBuilder.
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(
          child: ErrorDisplay(
            message: err.toString(),
            onRetry: () => ref.refresh(routineDetailsProvider(routineId)),
          ),
        ),
        data: (details) {
          if (details.scenarios.isEmpty) {
            return const Center(
              child: Text("This routine has no exercises.", style: TextStyle(color: Colors.grey)),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: details.scenarios.length,
                    itemBuilder: (context, index) {
                      final exercise = details.scenarios[index];
                      return Card(
                        color: Colors.white12,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(exercise.name, style: const TextStyle(color: Colors.white, fontSize: 18)),
                          subtitle: Text('Sets: ${exercise.sets} | Reps: ${exercise.reps}', style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.play_arrow, color: Colors.greenAccent, size: 28),
                          onTap: () {
                            // Navigate to the play screen using its route name.
                            // Pass exercise details in the `extra` parameter.
                            context.pushNamed('exercise-play', extra: exercise);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _finishRoutine(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                    child: const Text('Finish Routine'),
                  ),
                ),
                const SizedBox(height: 8),
                 SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.pop(), // Simply pop back
                    child: const Text('Quit Routine', style: TextStyle(color: Colors.red)),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom), // Safe area for bottom nav
              ],
            ),
          );
        },
      ),
    );
  }
}
