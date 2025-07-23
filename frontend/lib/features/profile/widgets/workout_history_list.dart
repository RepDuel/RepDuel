// frontend/lib/features/profile/widgets/workout_history_list.dart

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
            final totalVolume = entry.scenarios
                .fold<double>(0.0, (sum, s) => sum + s.totalVolume);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Routine ID: ${entry.routineId}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Time: ${entry.duration} minutes',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Volume: ${totalVolume.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  ...entry.scenarios.map((s) {
                    return Text(
                      '${s.sets} × ${s.scenarioId}',
                      style: const TextStyle(color: Colors.white),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
