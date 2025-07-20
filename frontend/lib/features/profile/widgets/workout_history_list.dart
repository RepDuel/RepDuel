import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/workout_history_provider.dart';

class WorkoutHistoryList extends ConsumerWidget {
  final String userId;

  const WorkoutHistoryList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider(userId));

    return history.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => const Text(
        'Failed to load workout history.',
        style: TextStyle(color: Colors.red),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Text(
            'No workouts yet.',
            style: TextStyle(color: Colors.white),
          );
        }

        return Column(
          children: entries.map((entry) {
            final date = DateTime.parse(entry.completionTimestamp);
            final dateStr =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

            return ListTile(
              title: Text('Routine ID: ${entry.routineId}',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('$dateStr • ${entry.status}',
                  style: const TextStyle(color: Colors.grey)),
            );
          }).toList(),
        );
      },
    );
  }
}
