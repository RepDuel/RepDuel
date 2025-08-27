// frontend/lib/features/ranked/utils/rank_utils.dart

import 'dart:convert'; // For jsonDecode if needed, though not directly used here
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http; // Needed for getUserRankColor
import 'package:intl/intl.dart'; // For number formatting
import 'package:flutter_svg/flutter_svg.dart'; // For SVG rendering

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import the auth provider
import '../../../core/providers/api_providers.dart'; // Import api_providers for energyApiProvider

// --- NEW ADDITIONS FOR RESULT SCREEN ---

/// A constant list defining the order of ranks from lowest to highest.
const List<String> rankOrder = [
  "Unranked", "Iron", "Bronze", "Silver", "Gold", "Platinum",
  "Diamond", "Jade", "Master", "Grandmaster", "Nova", "Astra", "Celestial"
];

/// A utility function to get the corresponding color for a given rank name.
/// This is now globally accessible.
Color getRankColor(String rank) {
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
      return Colors.white; // Default color for unranked or unknown ranks
  }
}


// --- EXISTING UTILITIES (MODIFIED FOR ASYNC/AUTH STATE) ---

class RankUtils {
  // Static map for energy thresholds per rank
  static const Map<String, int> rankEnergy = {
    'Iron': 100, 'Bronze': 200, 'Silver': 300, 'Gold': 400,
    'Platinum': 500, 'Diamond': 600, 'Jade': 700, 'Master': 800,
    'Grandmaster': 900, 'Nova': 1000, 'Astra': 1100, 'Celestial': 1200,
  };

  /// Calculate user's rank based on total score and standards.
  /// Assumes standards are fetched and available.
  static String calculateRank(
    double score,
    Map<String, dynamic>? standards, // standards can be null
  ) {
    if (standards == null) return 'Iron'; // Default to Iron if no standards data

    // Sort ranks by total score in descending order to find the highest applicable rank.
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) =>
          (b.value['total'] as num).compareTo(a.value['total'] as num)); // Descending sort

    for (final entry in sortedRanks) {
      final rankName = entry.key;
      // Get the total score benchmark for this rank.
      final rankTotal = (entry.value['total'] as num).toDouble();

      if (score >= rankTotal) {
        return rankName; // Return the rank name if score meets the threshold
      }
    }

    return 'Iron'; // Fallback rank if score is below the lowest benchmark (Iron)
  }

  /// Calculate progress percentage towards the next rank (0.0 to 1.0).
  static double calculateProgressPercentage(
    double score,
    String currentRank,
    Map<String, dynamic>? standards,
  ) {
    if (standards == null || currentRank == 'Celestial') {
      return 1.0; // If no standards or already max rank, progress is full
    }

    // Sort ranks by total score in ascending order to find current and next thresholds.
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) =>
          (a.value['total'] as num).compareTo(b.value['total'] as num)); // Ascending sort
    
    // Find the index of the current rank in the sorted list (lowest benchmark first).
    final currentIndex = sortedRanks.indexWhere((e) => e.key == currentRank);

    // If current rank is not found or is the lowest possible rank.
    if (currentIndex == -1 || currentIndex == 0) {
      // If currentRank is 'Iron' or lower, and we have a next rank above it.
      if (sortedRanks.length > 1) {
          final nextRankData = sortedRanks[1]; // The second item is the next rank up.
          final nextBenchmark = (nextRankData.value['total'] as num).toDouble();
          if (nextBenchmark > 0) {
              return (score / nextBenchmark).clamp(0.0, 1.0); // Progress towards the very first benchmark
          }
      }
      return 0.0; // Default to 0 if no meaningful next benchmark
    }

    // If current rank is found and not the lowest.
    final currentBenchmark = (standards[currentRank]['total'] as num).toDouble();
    final nextRank = sortedRanks[currentIndex + 1]; // Next rank up in ascending list
    final nextBenchmark = (nextRank.value['total'] as num).toDouble();

    if (nextBenchmark == currentBenchmark) return 1.0; // If benchmarks are the same, progress is full

    // Calculate raw progress and clamp between 0.0 and 1.0.
    final rawProgress = (score - currentBenchmark) / (nextBenchmark - currentBenchmark);
    return rawProgress.clamp(0.0, 1.0);
  }

  /// Calculate interpolated energy based on score, standards, and user multiplier.
  static double getInterpolatedEnergy({
    required double score, // User's score for the lift
    required Map<String, dynamic> thresholds, // Standard benchmarks
    required String liftKey, // The lift name (e.g., 'squat', 'bench')
    required double userMultiplier, // User's weight multiplier (e.g., 1.0 for kg, 2.2 for lbs)
  }) {
    // Sort ranks by the specific lift's score benchmark in ascending order.
    final sorted = thresholds.entries.toList()
      ..sort((a, b) {
        final scoreA = (a.value['lifts'][liftKey] ?? 0) as num;
        final scoreB = (b.value['lifts'][liftKey] ?? 0) as num;
        return scoreA.compareTo(scoreB); // Ascending sort
      });

    if (sorted.length < 2) return 0.0; // Need at least two ranks for interpolation

    // Get the lowest rank and its corresponding energy value.
    final lowest = sorted.first;
    final lowestThreshold = (lowest.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier;
    final lowestEnergy = rankEnergy[lowest.key]?.toDouble() ?? 100.0; // Default energy for Iron

    // Handle scores below the lowest threshold (interpolate between 0 energy and lowest rank energy).
    if (score < lowestThreshold) {
      // If lowest threshold is 0, avoid division by zero.
      if (lowestThreshold == 0) return lowestEnergy; 
      final percent = (score / lowestThreshold).clamp(0.0, 1.0);
      return (percent * lowestEnergy).roundToDouble();
    }

    // Iterate to find where the score falls between two ranks.
    for (int i = 0; i < sorted.length - 1; i++) {
      final currentRankData = sorted[i];
      final nextRankData = sorted[i + 1];

      // Get thresholds and energy values for current and next ranks, applying user multiplier.
      final currentVal = (currentRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier;
      final nextVal = (nextRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier;
      
      final currentEnergy = rankEnergy[currentRankData.key]?.toDouble() ?? 0.0;
      final nextEnergy = rankEnergy[nextRankData.key]?.toDouble() ?? 0.0;

      // If score is within the range of current and next rank benchmarks.
      if (score >= currentVal && score < nextVal) { // Use < nextVal to avoid double counting
        if (nextVal == currentVal) return nextEnergy; // Avoid division by zero if thresholds are identical

        final percent = (score - currentVal) / (nextVal - currentVal);
        return (currentEnergy + percent * (nextEnergy - currentEnergy)).roundToDouble();
      }
    }

    // Handle scores above the highest rank (extrapolate linearly).
    // Get the highest two ranks and their data.
    final topRankData = sorted.last;
    final secondLastRankData = sorted[sorted.length - 2]; // Second to last item

    final topVal = (topRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier;
    final secondLastVal = (secondLastRankData.value['lifts'][liftKey] ?? 0).toDouble() * userMultiplier;
    
    final topEnergy = rankEnergy[topRankData.key]?.toDouble() ?? 1200.0; // Use max energy
    final secondLastEnergy = rankEnergy[secondLastRankData.key]?.toDouble() ?? 1100.0; // Use second highest energy

    // Calculate the step difference in score and energy.
    final stepScore = topVal - secondLastVal;
    final stepEnergy = topEnergy - secondLastEnergy;

    // Avoid division by zero if stepScore is 0.
    if (stepScore == 0) return topEnergy; 

    final extraSteps = (score - topVal) / stepScore; // How many steps beyond the top benchmark
    return (topEnergy + extraSteps * stepEnergy).roundToDouble(); // Extrapolate energy
  }

  /// Format numbers with one decimal place if not a whole number.
  static String formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) return value.toStringAsFixed(1); // Fixed to 1 decimal place
    return value.toString();
  }

  /// Format KG values for display, ensuring whole numbers are shown as integers.
  static String formatKg(num value) {
    // Use NumberFormat for consistent formatting (e.g., 100.0 -> 100, 95.5 -> 95.5)
    final formatter = NumberFormat("0.#"); 
    return formatter.format(value);
  }

  /// Calculate the user's total score from their best lifts.
  static double calculateUserTotal(Map<String, double> userHighScores) {
    // Sum up the highest scores for each lift.
    return userHighScores.values.fold(0.0, (sum, liftScore) => sum + liftScore);
  }

  /// Get the user's overall rank based on their total score and the provided standards.
  static String getUserRankFromStandards(
    Map<String, dynamic> standards,
    Map<String, double> userHighScores,
  ) {
    final userTotal = calculateUserTotal(userHighScores); // Calculate total score
    return calculateRank(userTotal, standards); // Calculate rank based on total
  }

  /// Asynchronously get the user's rank color.
  /// This method now correctly accesses authProvider using ref.
  static Future<Color> getUserRankColor(WidgetRef ref) async {
    // Safely watch the authProvider to get AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);

    return authStateAsyncValue.when(
      data: (authState) { // When auth state is loaded
        final user = authState.user; // Safely get user
        if (user == null) {
          return Colors.grey; // Default color if user data is null (logged out)
        }

        // Get energy for the user. Note: This is an async call.
        // If energy calculation is complex and needs to be reactive, consider a dedicated provider.
        // For now, calling it directly.
        // **Potential Improvement:** If getLatestEnergy is slow or needs caching,
        // move it into a Riverpod provider.
        return getRankColorFromEnergy(user.energy ?? 0); // Assuming user object has an energy field
      },
      loading: () => Colors.grey, // Show grey while loading auth state
      error: (_, __) => Colors.red, // Show red if auth state fails
    );
  }

  // Helper to get rank color based on energy directly, using the globally available getRankColor.
  static String _getRankFromEnergy(double energy) {
    final entries = RankUtils.rankEnergy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by energy value
    for (final entry in entries) {
      if (energy >= entry.value) return entry.key;
    }
    return 'Unranked'; // Default if below lowest threshold
  }

  // Helper to get rank color based on energy. This function might be redundant if getRankColor handles all cases.
  // Moved the logic into getUserRankColor directly for better async handling.
  static Color getRankColorFromEnergy(double energy) {
      final rank = _getRankFromEnergy(energy);
      return getRankColor(rank); // Use the global getRankColor function
  }
}