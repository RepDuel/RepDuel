// frontend/lib/features/ranked/utils/rank_utils.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/providers/auth_provider.dart';
import '../../../core/providers/api_providers.dart';

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

  /// Calculate user's rank based on total score and standards
  static String calculateRank(
    double score,
    Map<String, dynamic>? standards,
  ) {
    if (standards == null) return 'Iron';

    final sortedRanks = standards.entries.toList()
      ..sort((a, b) =>
          (b.value['total'] as num).compareTo(a.value['total'] as num));

    for (final entry in sortedRanks) {
      final rankName = entry.key;
      final rankTotal = (entry.value['total'] as num).toDouble();

      if (score >= rankTotal) {
        return rankName;
      }
    }

    return 'Iron'; // fallback if score is below all ranks
  }

  /// Calculate progress toward next rank (0.0 to 1.0)
  static double calculateProgressPercentage(
    double score,
    String currentRank,
    Map<String, dynamic>? standards,
  ) {
    if (standards == null || !standards.containsKey(currentRank)) {
      return 0.0;
    }

    final sortedRanks = standards.entries.toList()
      ..sort((a, b) =>
          (b.value['total'] as num).compareTo(a.value['total'] as num));
    final rankNames = sortedRanks.map((e) => e.key).toList();
    final currentIndex = rankNames.indexOf(currentRank);

    if (currentIndex <= 0) return 1.0; // Already top rank or not found

    final nextRank = rankNames[currentIndex - 1];
    final currentBenchmark =
        (standards[currentRank]['total'] as num).toDouble();
    final nextBenchmark = (standards[nextRank]['total'] as num).toDouble();

    if (nextBenchmark == currentBenchmark) return 1.0;

    final rawProgress =
        (score - currentBenchmark) / (nextBenchmark - currentBenchmark);
    return rawProgress.clamp(0.0, 1.0);
  }

  static double getInterpolatedEnergy({
    required double score,
    required Map<String, dynamic> thresholds,
    required String liftKey,
    required double userMultiplier, // Add user multiplier as a parameter
  }) {
    final sorted = thresholds.entries.toList()
      ..sort((a, b) => ((a.value['lifts'][liftKey] ?? 0) as num)
          .compareTo((b.value['lifts'][liftKey] ?? 0) as num));

    if (sorted.length < 2) return 0.0;

    final lowest = sorted.first;
    final lowestThreshold = (lowest.value['lifts'][liftKey] ?? 0).toDouble() *
        userMultiplier; // Multiply threshold by user multiplier
    final lowestEnergy = rankEnergy[lowest.key]?.toDouble() ?? 100;

    // 🔻 Below Iron (interpolate from 0 to Iron)
    if (score < lowestThreshold) {
      final percent = (score / lowestThreshold).clamp(0.0, 1.0);
      return (percent * lowestEnergy).roundToDouble();
    }

    // 🔁 Between ranks
    for (int i = 0; i < sorted.length - 1; i++) {
      final current = sorted[i];
      final next = sorted[i + 1];

      final currentVal = (current.value['lifts'][liftKey] ?? 0).toDouble() *
          userMultiplier; // Multiply threshold by user multiplier
      final nextVal = (next.value['lifts'][liftKey] ?? 0).toDouble() *
          userMultiplier; // Multiply threshold by user multiplier

      if (score >= currentVal && score <= nextVal) {
        final percent = (score - currentVal) / (nextVal - currentVal);
        final currentEnergy = rankEnergy[current.key]?.toDouble() ?? 0.0;
        final nextEnergy = rankEnergy[next.key]?.toDouble() ?? 0.0;
        return ((currentEnergy + percent * (nextEnergy - currentEnergy)))
            .roundToDouble();
      }
    }

    // 🔺 Above top rank (extrapolation)
    final top = sorted.last;
    final secondLast = sorted[sorted.length - 2];

    final topVal = (top.value['lifts'][liftKey] ?? 0).toDouble() *
        userMultiplier; // Multiply threshold by user multiplier
    final secondVal = (secondLast.value['lifts'][liftKey] ?? 0).toDouble() *
        userMultiplier; // Multiply threshold by user multiplier
    final topEnergy = rankEnergy[top.key]?.toDouble() ?? 1200;
    final secondEnergy = rankEnergy[secondLast.key]?.toDouble() ?? 1100;

    final stepScore = topVal - secondVal;
    final stepEnergy = topEnergy - secondEnergy;

    final extraSteps = (score - topVal) / stepScore;
    return ((topEnergy + extraSteps * stepEnergy)).roundToDouble();
  }

  /// Determine color of rank
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
        return const Color(0xFFff00ff); // pink
      case 'Grandmaster':
        return const Color(0xFFffde21); // yellow
      case 'Nova':
        return const Color(0xFFa45ee5); // purple
      case 'Astra':
        return const Color(0xFFff4040); // red
      case 'Celestial':
        return const Color(0xFF00ffff); // cyan
      default:
        return Colors.white;
    }
  }

  /// Format values like double to 1 decimal place or fallback
  static String formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toStringAsFixed(1);
    return value.toString();
  }

  static String formatKg(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  /// Compute total from user's best lifts
  static double calculateUserTotal(Map<String, double> userHighScores) {
    return userHighScores.values.fold(0.0, (sum, lift) => sum + lift);
  }

  /// Compute user's full rank from their lift scores + standards
  static String getUserRankFromStandards(
    Map<String, dynamic> standards,
    Map<String, double> userHighScores,
  ) {
    final userTotal = calculateUserTotal(userHighScores);
    return calculateRank(userTotal, standards);
  }

  static Future<Color> getUserRankColor(WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      return Colors.grey; // Default color if user not found
    }

    // Get the user's energy from the API using their user ID
    final energyApiService = ref.read(energyApiProvider);
    final energy = await energyApiService.getLatestEnergy(user.id);

    // Determine rank based on energy
    if (energy >= 1200) return getRankColor('Celestial');
    if (energy >= 1100) return getRankColor('Astra');
    if (energy >= 1000) return getRankColor('Nova');
    if (energy >= 900) return getRankColor('Grandmaster');
    if (energy >= 800) return getRankColor('Master');
    if (energy >= 700) return getRankColor('Jade');
    if (energy >= 600) return getRankColor('Diamond');
    if (energy >= 500) return getRankColor('Platinum');
    if (energy >= 400) return getRankColor('Gold');
    if (energy >= 300) return getRankColor('Silver');
    if (energy >= 200) return getRankColor('Bronze');
    return getRankColor('Iron');
  }
}
