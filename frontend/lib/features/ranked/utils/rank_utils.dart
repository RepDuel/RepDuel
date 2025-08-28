// frontend/lib/features/ranked/utils/rank_utils.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// All functions are now top-level for easy, direct access after import.

const Map<String, int> rankEnergy = {
  'Iron': 100, 'Bronze': 200, 'Silver': 300, 'Gold': 400,
  'Platinum': 500, 'Diamond': 600, 'Jade': 700, 'Master': 800,
  'Grandmaster': 900, 'Nova': 1000, 'Astra': 1100, 'Celestial': 1200,
};

Color getRankColor(String rank) {
  // Using toLowerCase() to make the matching case-insensitive and more robust.
  switch (rank.toLowerCase()) {
    case 'iron':
      return const Color(0xFF808080); // #808080
    case 'bronze':
      return const Color(0xFFcd7f32); // #cd7f32
    case 'silver':
      return const Color(0xFFc0c0c0); // #c0c0c0
    case 'gold':
      return const Color(0xFFefbf04); // #efbf04
    case 'platinum':
      return const Color(0xFF00ced1); // #00ced1
    case 'diamond':
      return const Color(0xFFb9f2ff); // #b9f2ff
    case 'jade':
      return const Color(0xFF62f40c); // #62f40c
    case 'master':
      return const Color(0xFFff00ff); // #ff00ff
    case 'grandmaster':
      return const Color(0xFFffde21); // #ffde21
    case 'nova':
      return const Color(0xFFa45ee5); // #a45ee5
    case 'astra':
      return const Color(0xFFff4040); // #ff4040
    case 'celestial':
      return const Color(0xFF00ffff); // #00ffff
    default:
      return Colors.white; // Default for "Unranked" or any unexpected value
  }
}

double getInterpolatedEnergy({
  required double score,
  required Map<String, dynamic> thresholds,
  required String liftKey,
  required double userMultiplier,
}) {
  final sorted = thresholds.entries.toList()
    ..sort((a, b) {
      final scoreA = (a.value['lifts'][liftKey] ?? 0) as num;
      final scoreB = (b.value['lifts'][liftKey] ?? 0) as num;
      return scoreA.compareTo(scoreB);
    });
  if (sorted.length < 2) return 0.0;
  final lowest = sorted.first;
  final lowestThreshold = ((lowest.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier);
  final lowestEnergy = rankEnergy[lowest.key]?.toDouble() ?? 100.0;
  if (score < lowestThreshold) {
    if (lowestThreshold == 0) return lowestEnergy;
    return ((score / lowestThreshold).clamp(0.0, 1.0) * lowestEnergy).roundToDouble();
  }
  for (int i = 0; i < sorted.length - 1; i++) {
    final currentRankData = sorted[i];
    final nextRankData = sorted[i + 1];
    final currentVal = ((currentRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier);
    final nextVal = ((nextRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier);
    final currentEnergy = rankEnergy[currentRankData.key]?.toDouble() ?? 0.0;
    final nextEnergy = rankEnergy[nextRankData.key]?.toDouble() ?? 0.0;
    if (score >= currentVal && score < nextVal) {
      if (nextVal == currentVal) return nextEnergy;
      final percent = (score - currentVal) / (nextVal - currentVal);
      return (currentEnergy + percent * (nextEnergy - currentEnergy)).roundToDouble();
    }
  }
  final topRankData = sorted.last;
  final secondLastRankData = sorted[sorted.length - 2];
  final topVal = ((topRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier);
  final secondLastVal = ((secondLastRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier);
  final topEnergy = rankEnergy[topRankData.key]?.toDouble() ?? 1200.0;
  final secondLastEnergy = rankEnergy[secondLastRankData.key]?.toDouble() ?? 1100.0;
  final stepScore = topVal - secondLastVal;
  if (stepScore == 0) return topEnergy;
  final stepEnergy = topEnergy - secondLastEnergy;
  final extraSteps = (score - topVal) / stepScore;
  return (topEnergy + extraSteps * stepEnergy).roundToDouble();
}

String formatKg(num value) {
  final formatter = NumberFormat("0.#"); 
  return formatter.format(value);
}