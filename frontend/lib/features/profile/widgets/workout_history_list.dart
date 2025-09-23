// frontend/lib/features/profile/widgets/workout_history_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repduel/widgets/loading_spinner.dart';

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

    String formatDuration(double minutes) {
      final totalSeconds = (minutes * 60).round();
      final hours = totalSeconds ~/ 3600;
      final minutesPart = (totalSeconds % 3600) ~/ 60;
      final seconds = totalSeconds % 60;

      if (hours > 0) {
        final twoDigitMinutes = minutesPart.toString().padLeft(2, '0');
        final twoDigitSeconds = seconds.toString().padLeft(2, '0');
        return '$hours:$twoDigitMinutes:$twoDigitSeconds';
      }

      if (minutesPart > 0) {
        final twoDigitSeconds = seconds.toString().padLeft(2, '0');
        return '$minutesPart:$twoDigitSeconds';
      }

      return '${seconds}s';
    }

    String scenarioTitle(String id) {
      return id
          .split('_')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }

    double measureTextWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout();

      return painter.size.width;
    }

    String formatDiscordTimestamp(String isoString) {
      final parsed = DateTime.tryParse(isoString);
      if (parsed == null) {
        return isoString;
      }

      final local = parsed.toLocal();
      final now = DateTime.now();
      final normalizedLocal = DateTime(local.year, local.month, local.day);
      final normalizedNow = DateTime(now.year, now.month, now.day);
      final diffDays = normalizedNow.difference(normalizedLocal).inDays;

      const weekdayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      String formatTime(DateTime dt) {
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      }

      if (diffDays == 0) {
        return 'Today at ${formatTime(local)}';
      }

      if (diffDays == 1) {
        return 'Yesterday at ${formatTime(local)}';
      }

      if (diffDays >= 2 && diffDays < 7) {
        return '${weekdayNames[local.weekday - 1]} at ${formatTime(local)}';
      }

      final monthName = monthNames[local.month - 1];
      final day = local.day;

      if (local.year == now.year) {
        return '$monthName $day at ${formatTime(local)}';
      }

      return '$monthName $day, ${local.year} at ${formatTime(local)}';
    }

    return historyAsyncValue.when(
      loading: () => const Center(child: LoadingSpinner()),
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
            final formattedDuration = formatDuration(entry.duration);
            final timestampLabel =
                formatDiscordTimestamp(entry.completionTimestamp);
            const timestampTextStyle = TextStyle(
              color: Colors.white54,
              fontSize: 12,
            );
            final measuredTimestampWidth =
                measureTextWidth(timestampLabel, timestampTextStyle);
            const maxTimestampWidth = 160.0;
            final timestampBoxWidth = measuredTimestampWidth > 0
                ? measuredTimestampWidth.clamp(0, maxTimestampWidth).toDouble()
                : 0.0;
            final titleRightPadding =
                timestampBoxWidth > 0 ? timestampBoxWidth + 12 : 0.0;

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
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: titleRightPadding),
                            child: Text(
                              entry.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Volume: ${formatNum(totalVolumeUser)} $unit',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Duration: $formattedDuration',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          ...grouped.entries.expand((grp) {
                            final scenarioName = scenarioTitle(grp.key);
                            final setItems = <Widget>[];

                            // Build set lines with 1-based, sequential numbering
                            var displayedSetIndex = 0;
                            for (var i = 0; i < grp.value.length; i++) {
                              final s = grp.value[i];
                              final isBodyweightScenario =
                                  grp.key.startsWith('bodyweight_');
                              final weightUser = toUserUnit(s.weight);
                              final reps = s.reps;

                              // Skip any set with 0 reps
                              if (reps <= 0) continue;

                              // Determine if this is a bodyweight set (only when the scenario is bodyweight)
                              final isBodyweightSet =
                                  isBodyweightScenario && s.weight == 0;

                              // For weighted exercises: only show sets with positive weight
                              if (!isBodyweightSet && weightUser <= 0) continue;

                              // Increment only for sets that are actually shown
                              displayedSetIndex += 1;

                              // Pluralize reps label
                              final repsLabel = reps == 1 ? 'rep' : 'reps';
                              // Text for the set
                              final setText = isBodyweightSet
                                  ? '$reps $repsLabel'
                                  : '${formatNum(weightUser)} $unit x $reps $repsLabel';

                              setItems.add(
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Set $displayedSetIndex: ',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: setText,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // If no visible sets, hide the scenario header entirely
                            if (displayedSetIndex == 0) {
                              return const <Widget>[];
                            }

                            return [
                              Text(
                                '$scenarioName:',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              ...setItems,
                              const SizedBox(height: 8),
                            ];
                          }),
                        ],
                      ),
                      if (timestampLabel.isNotEmpty)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: maxTimestampWidth,
                            ),
                            child: Text(
                              timestampLabel,
                              style: timestampTextStyle,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
