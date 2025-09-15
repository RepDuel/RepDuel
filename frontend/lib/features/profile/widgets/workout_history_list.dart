// frontend/lib/features/profile/widgets/workout_history_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/routine_submission_read.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../../core/providers/score_events_provider.dart';

class WorkoutHistoryList extends ConsumerWidget {
  final String userId;

  const WorkoutHistoryList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Small, safe listener: when scoreEvents changes (a routine/score was saved),
    // invalidate history so it refetches next build.
    ref.listen<int>(scoreEventsProvider, (prev, next) {
      ref.invalidate(workoutHistoryProvider(userId));
    });

    final historyAsyncValue = ref.watch(workoutHistoryProvider(userId));
    final authStateAsyncValue = ref.watch(authProvider);

    final userMultiplier =
        authStateAsyncValue.valueOrNull?.user?.weightMultiplier ?? 1.0;
    final isLbs = userMultiplier > 1.5;
    const kgToLbs = 2.20462;
    final unit = isLbs ? 'lb' : 'kg';

    num toUserUnit(num kg) => isLbs ? (kg * kgToLbs) : kg;

    String formatNum(num n) =>
        (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

    String scenarioTitle(String id) {
      return id
          .split('_')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }

    return historyAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No workouts logged yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = screenWidth > 700;
        const minWidth = 300.0;
        const maxWidth = 600.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((entry) {
            final totalVolumeUser = entry.scenarios.fold<double>(
              0.0,
              (sum, s) => sum + toUserUnit(s.totalVolume),
            );

            final Map<String, List<RoutineScenarioSubmission>> grouped = {};
            for (final s in entry.scenarios) {
              grouped.putIfAbsent(s.scenarioId, () => []).add(s);
            }

            return Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isWide ? minWidth : double.infinity,
                  maxWidth: isWide ? maxWidth : double.infinity,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time: ${formatNum(entry.duration)} minutes',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      ...grouped.entries.expand((grp) {
                        final scenarioName = scenarioTitle(grp.key);
                        final items = <Widget>[
                          Text(
                            '$scenarioName:',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ];

                        // Build set lines in incrementing order with 1-based index
                        for (var i = 0; i < grp.value.length; i++) {
                          final s = grp.value[i];
                          final isBodyweightScenario = grp.key.startsWith('bodyweight_');
                          final weightUser = toUserUnit(s.weight);
                          final reps = s.reps;

                          // Skip any set with 0 reps
                          if (reps <= 0) continue;

                          // Determine if this is a bodyweight set (only when the scenario is bodyweight)
                          final isBodyweightSet = isBodyweightScenario && s.weight == 0;

                          // For weighted exercises: only show sets with positive weight
                          if (!isBodyweightSet && weightUser <= 0) continue;

                          final setLabel = Text(
                            'Set ${i + 1}: ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );

                          // Pluralize reps label
                          final repsLabel = reps == 1 ? 'rep' : 'reps';
                          // Text for the set
                          final setText = isBodyweightSet
                              ? '$reps $repsLabel'
                              : '${formatNum(weightUser)} $unit x $reps $repsLabel';

                          items.add(
                            RichText(
                              text: TextSpan(
                                children: [
                                  WidgetSpan(child: setLabel),
                                  TextSpan(
                                    text: setText,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        items.add(const SizedBox(height: 8));
                        return items;
                      }),
                      Text(
                        'Total Volume: ${formatNum(totalVolumeUser)} $unit',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
