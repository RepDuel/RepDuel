import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/workout_history_provider.dart';
import '../../../core/models/routine_submission_read.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../theme/app_theme.dart';

class WorkoutHistoryList extends ConsumerWidget {
  final String userId;

  const WorkoutHistoryList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider(userId));

    final userMultiplier =
        ref.watch(authStateProvider).user?.weightMultiplier ?? 1.0;
    final isLbs = userMultiplier > 1.5;
    const kgToLbs = 2.20462;
    final unit = isLbs ? 'lb' : 'kg';

    num toUserUnit(num kg) => isLbs ? kg * kgToLbs : kg;

    String formatNum(num n) =>
        (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

    String scenarioTitle(String id) {
      return id
          .split('_')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }

    return history.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => const Text(
        'Failed to load workout history.',
        style: TextStyle(color: AppTheme.errorColor),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Text(
            'No workouts yet.',
            style: TextStyle(color: Colors.white),
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
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Time: ${formatNum(entry.duration)} minutes',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      ...grouped.entries.expand((grp) {
                        final scenarioName = scenarioTitle(grp.key);
                        final items = <Widget>[
                          Text(
                            '$scenarioName:',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ];

                        for (final s in grp.value) {
                          for (int i = 0; i < s.sets; i++) {
                            final weightUser = toUserUnit(s.weight);
                            items.add(Text(
                              '${formatNum(weightUser)}$unit x ${s.reps}',
                              style: const TextStyle(color: Colors.white),
                            ));
                          }
                        }

                        items.add(const SizedBox(height: 8));
                        return items;
                      }),
                      Text(
                        'Total Volume: ${formatNum(totalVolumeUser)}',
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
