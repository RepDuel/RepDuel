// frontend/lib/features/ranked/utils/rank_utils.dart

import 'package:flutter/material.dart';

class RankUtils {
  static const Map<String, int> rankEnergy = {
    'Iron': 100,
    'Bronze': 200,
    'Silver': 300,
    'Gold': 400,
    'Platinum': 500,
    'Diamond': 600,
    'Jade': 700,
    'Master': 800,
    'Grandmaster': 900,
    'Nova': 1000,
    'Astra': 1100,
    'Celestial': 1200,
  };

  static String calculateRank(
    double score,
    Map<String, dynamic>? standards,
  ) {
    if (standards == null) return 'Iron';

    // Get ranks sorted from highest to lowest energy
    final sortedRanks = RankUtils.rankEnergy.keys.toList()
      ..sort((a, b) {
        final aTotal = standards[a]?['total'] ?? -1;
        final bTotal = standards[b]?['total'] ?? -1;
        return (bTotal as num).compareTo(aTotal as num);
      });

    // Find the highest rank the score qualifies for
    for (var rank in sortedRanks) {
      if (standards.containsKey(rank) && score >= standards[rank]['total']) {
        return rank;
      }
    }
    return 'Iron'; // Default if no rank matches
  }

  static double calculateProgressPercentage(
    double score,
    String currentRank,
    Map<String, dynamic>? standards,
  ) {
    if (standards == null || !standards.containsKey(currentRank)) {
      return 0.0;
    }

    final sortedRanks = rankEnergy.keys.toList()
      ..sort((a, b) => rankEnergy[b]!.compareTo(rankEnergy[a]!));
    final currentIndex = sortedRanks.indexOf(currentRank);

    if (currentIndex >= sortedRanks.length - 1) {
      return 1.0; // Already at highest rank
    }

    final nextRank = sortedRanks[currentIndex + 1];
    if (!standards.containsKey(nextRank)) return 1.0;

    final currentBenchmark = standards[currentRank]['total'];
    final nextBenchmark = standards[nextRank]['total'];

    // Prevent division by zero and ensure valid progress value
    if (nextBenchmark == currentBenchmark) return 1.0;

    return ((score - currentBenchmark) / (nextBenchmark - currentBenchmark))
        .clamp(0.0, 1.0);
  }

  static Color getRankColor(String rank) {
    switch (rank) {
      case 'Iron':
        return Colors.grey;
      case 'Bronze':
        return const Color(0xFFcd7f32);
      case 'Silver':
        return const Color(0xFFc0c0c0);
      case 'Gold':
        return const Color(0xFFefbf04);
      case 'Platinum':
        return const Color(0xFF00ced1);
      case 'Diamond':
        return const Color(0xFFb9f2ff);
      case 'Jade':
        return const Color(0xFF62f40c);
      case 'Master':
        return const Color(0xFFff00ff);
      case 'Grandmaster':
        return const Color(0xFFffde21);
      case 'Nova':
        return const Color(0xFFa45ee5);
      case 'Astra':
        return const Color(0xFFff4040);
      case 'Celestial':
        return const Color(0xFF00ffff);
      default:
        return Colors.white;
    }
  }

  static String formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toStringAsFixed(1);
    return value.toString();
  }
}
