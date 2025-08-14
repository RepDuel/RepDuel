// frontend/lib/features/profile/widgets/energy_graph.dart

import 'dart:convert';

import '../../../core/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

class DailyEnergyEntry {
  final String date; // Format: "2025-07-11"
  final double totalEnergy;

  DailyEnergyEntry({required this.date, required this.totalEnergy});

  factory DailyEnergyEntry.fromJson(Map<String, dynamic> json) {
    return DailyEnergyEntry(
      date: json['date'],
      totalEnergy: (json['total_energy'] as num).toDouble(),
    );
  }
}

final energyGraphProvider =
    FutureProvider.family<List<DailyEnergyEntry>, String>((ref, userId) async {
  final res = await http.get(
    Uri.parse('${Env.baseUrl}/api/v1/energy/daily/$userId'),
    headers: {
      'Content-Type': 'application/json',
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to load energy history');
  }

  final List<dynamic> data = json.decode(res.body);
  return data.map((e) => DailyEnergyEntry.fromJson(e)).toList();
});

class EnergyGraph extends ConsumerWidget {
  final String userId;

  const EnergyGraph({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energyData = ref.watch(energyGraphProvider(userId));

    return energyData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => const Text(
        'Error loading data',
        style: TextStyle(color: Colors.red),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Text(
            'No energy data yet.',
            style: TextStyle(color: Colors.white),
          );
        }

        final maxY =
            entries.map((e) => e.totalEnergy).reduce((a, b) => a > b ? a : b);
        final roundedMaxY = ((maxY / 10).ceil() * 10).toDouble();
        final yInterval = (roundedMaxY / 4).ceilToDouble();

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
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final date = entries[index].date;
                      return Text(
                        date.substring(5), // MM-DD
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // --- THE FIX IS HERE ---
                    // Added reservedSize to ensure labels like "1080" have enough
                    // space and don't wrap to the next line.
                    reservedSize: 44,
                    interval: yInterval > 0 ? yInterval : 1,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              minY: 0,
              maxY: roundedMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    entries.length,
                    (i) => FlSpot(i.toDouble(), entries[i].totalEnergy),
                  ),
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true),
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}