// frontend/lib/features/ranked/widgets/score_history_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../providers/score_history_provider.dart';

class ScoreHistoryChart extends ConsumerWidget {
  final String scenarioId;
  final double weightMultiplier;

  const ScoreHistoryChart({
    super.key,
    required this.scenarioId,
    required this.weightMultiplier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scoreHistoryProvider(scenarioId));
    final primaryColor = Theme.of(context).colorScheme.primary;
    return historyAsync.when(
      loading: () => const Center(child: LoadingSpinner()),
      error: (e, s) => Center(child: Text(e.toString().replaceFirst("Exception: ", ""), style: const TextStyle(color: Colors.red, fontSize: 14))),
      data: (history) {
        if (history.length < 2) return const Center(child: Text("Log at least two workouts to see a graph.", style: TextStyle(color: Colors.white70)));
        
        // Apply weightMultiplier to the scores before calculating the max Y value
        final maxY = history.map((e) => e.score * weightMultiplier).reduce((a, b) => a > b ? a : b);
        final roundedMaxY = ((maxY / 10).ceil() * 10).toDouble();
        final yInterval = (roundedMaxY / 4).ceilToDouble();

        // Apply weightMultiplier to the scores when creating the FlSpots
        final spots = history.asMap().entries.map((entry) {
            final scaledScore = entry.value.score * weightMultiplier;
            return FlSpot(entry.key.toDouble(), scaledScore);
        }).toList();

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= history.length) {
                        return const SizedBox.shrink();
                      }
                      final date = history[index].date;
                      return Text(
                        DateFormat('MM/dd').format(date),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yInterval > 0 ? yInterval : 1,
                    // The 'value' passed here is already scaled because maxY is scaled
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              minY: 0,
              maxY: roundedMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
