// frontend/lib/features/ranked/widgets/ranking_table.dart

import 'dart:async'; // For TimeoutException if used elsewhere
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart'; // For navigation
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For number formatting

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../utils/rank_utils.dart'; // Utility for rank calculations and colors

// Assume RankUtils has helper functions like:
// getInterpolatedEnergy, getRankColor, rankOrder, formatKg

class RankingTable extends ConsumerWidget { // Changed to ConsumerWidget
  final Map<String, dynamic>? liftStandards;
  final Map<String, double> userHighScores;
  final Function() onViewBenchmarks;
  final Function(String liftName) onLiftTapped;
  final Function(String scenarioId) onLeaderboardTapped;
  final VoidCallback onEnergyLeaderboardTapped;
  final Function(int energy, String rank) onEnergyComputed;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.userHighScores,
    required this.onViewBenchmarks,
    required this.onLiftTapped,
    required this.onLeaderboardTapped,
    required this.onEnergyLeaderboardTapped,
    required this.onEnergyComputed,
  });

  static const scenarioIds = {
    'Squat': 'back_squat',
    'Bench': 'barbell_bench_press',
    'Deadlift': 'deadlift',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef ref
    // Safely watch the auth provider to get AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()), // Show loading while auth state is loading
      error: (error, stackTrace) => Center(child: Text('Auth Error: $error', style: const TextStyle(color: Colors.red))), // Show error if auth fails
      data: (authState) { // authState is the actual AuthState object here
        // Safely access user data from the loaded AuthState.
        final user = authState.user;
        final token = authState.token; // Token might be needed for some actions

        // If user or token is null, user is not authenticated. Handle this state.
        if (user == null || token == null) {
          // This screen should ideally not be reachable if not authenticated due to router guards.
          // However, as a fallback, show a message prompting login.
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Please log in to view rankings.', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).go('/login'), // Navigate to login
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
        }

        // --- User is logged in and data is available ---
        final weightMultiplier = user.weightMultiplier ?? 1.0; // Safely access weightMultiplier

        // Check if liftStandards is available. If not, show a message.
        if (liftStandards == null) {
          return const Center(
            child: Text('No ranking data available', style: TextStyle(color: Colors.white)),
          );
        }

        // Prepare lift data using userMultiplier for display.
        final defaultLifts = ['Squat', 'Bench', 'Deadlift'];
        final allLifts = <String, double>{};
        for (var lift in defaultLifts) {
           final score = _normalizeAndGetScore(lift, userHighScores);
           allLifts[lift] = score * weightMultiplier; // Apply multiplier here for display
        }
        
        // Calculate energies and overall rank
        final energies = allLifts.entries.map((entry) {
          final liftKey = entry.key.toLowerCase();
          final score = entry.value; // Already applied multiplier
          return RankUtils.getInterpolatedEnergy(
              score: score,
              thresholds: liftStandards!, // Non-null assertion safe due to check above
              liftKey: liftKey,
              userMultiplier: weightMultiplier); // Pass multiplier for consistency
        }).toList();

        final averageEnergy = energies.isNotEmpty
            ? energies.reduce((a, b) => a + b) / energies.length
            : 0.0;
        final overallRank = _getRankFromEnergy(averageEnergy);
        final overallColor = getRankColor(overallRank);

        // Call the callback to compute energy
        onEnergyComputed(averageEnergy.round(), overallRank);

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Overall Energy: ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('${averageEnergy.round()}',
                    style: TextStyle(
                        color: overallColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                SvgPicture.asset(
                    'assets/images/ranks/${overallRank.toLowerCase()}.svg',
                    height: 24,
                    width: 24),
                IconButton(
                  icon: const Icon(Icons.leaderboard, color: Colors.blue),
                  onPressed: onEnergyLeaderboardTapped,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _RankingTableHeader(),
            const SizedBox(height: 12),
            // Map through allLifts to build ranking rows
            ...allLifts.entries.map(
              (entry) => _RankingRow(
                lift: entry.key,
                // Pass the already multiplied score
                score: entry.value, 
                standards: liftStandards!,
                onTap: () => onLiftTapped(entry.key),
                onLeaderboardTap: () => 
                    onLeaderboardTapped(scenarioIds[entry.key]!),
                userMultiplier: weightMultiplier, // Pass multiplier down
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onViewBenchmarks,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('View Benchmarks'),
            ),
          ],
        );
      },
    );
  }

  // Helper to get score, ensures lift key is found and returns 0.0 if not.
  double _normalizeAndGetScore(String lift, Map<String, double> scores) {
    final lowerCaseLift = lift.toLowerCase();
    // Direct access assuming scores map keys match lowercase lift names
    return scores[lowerCaseLift] ?? 0.0; 
  }

  // Helper to get rank from energy score.
  String _getRankFromEnergy(double energy) {
    // RankUtils.rankEnergy is assumed to be a Map<String, int> like {'Gold': 400, 'Silver': 300, ...}
    final entries = RankUtils.rankEnergy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by energy value
    for (final entry in entries) {
      if (energy >= entry.value) return entry.key;
    }
    return 'Unranked'; // Default rank if no threshold is met
  }
}

class _RankingTableHeader extends StatelessWidget {
  const _RankingTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Lift', style: _headerStyle)),
          Expanded(flex: 2, child: Center(child: Text('Score', style: _headerStyle))),
          Expanded(flex: 2, child: Center(child: Text('Progress', style: _headerStyle))),
          Expanded(flex: 2, child: Center(child: Text('Rank', style: _headerStyle))),
          Expanded(flex: 1, child: Center(child: Text('Energy', style: _headerStyle))),
          Expanded(flex: 1, child: SizedBox.shrink()), // For the leaderboard icon column
        ],
      ),
    );
  }

  static const _headerStyle =
      TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
}

class _RankingRow extends StatelessWidget {
  final String lift;
  final double score; // This score is already adjusted by weightMultiplier
  final Map<String, dynamic> standards;
  final VoidCallback onTap;
  final VoidCallback onLeaderboardTap;
  final double userMultiplier; // This is passed down but not directly used in _LiftValue as score is already adjusted

  const _RankingRow({
    required this.lift,
    required this.score,
    required this.standards,
    required this.onTap,
    required this.onLeaderboardTap,
    required this.userMultiplier, // Passed down but applied before reaching here
  });

  @override
  Widget build(BuildContext context) {
    final lowerLift = lift.toLowerCase();
    // Sort ranks by the lift's score in descending order.
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) {
        final scoreA = (a.value['lifts'][lowerLift] ?? 0) as num;
        final scoreB = (b.value['lifts'][lowerLift] ?? 0) as num;
        return scoreB.compareTo(scoreA); // Descending order
      });

    String? matchedRank;
    double currentThreshold = 0.0;
    double nextThreshold = 0.0; // Initialize nextThreshold

    // Find the user's current rank and threshold.
    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      final adjustedThreshold = threshold.toDouble() * userMultiplier;
      final roundedThreshold = _roundToNearest5(adjustedThreshold);

      if (score >= roundedThreshold) {
        matchedRank = entry.key;
        currentThreshold = roundedThreshold;
        break; // Found the rank
      }
    }
    
    // Determine the next threshold for progress calculation.
    if (matchedRank != null) {
      final currentIndex = sortedRanks.indexWhere((e) => e.key == matchedRank);
      if (currentIndex > 0) { // If not the highest rank
        nextThreshold = _roundToNearest5(
            (sortedRanks[currentIndex - 1].value['lifts'][lowerLift] ?? 0) * userMultiplier);
      } else { // If highest rank, set nextThreshold to current for full progress bar
        nextThreshold = currentThreshold; 
      }
    } else { // If no rank matched (user score is below the lowest standard)
      nextThreshold = _roundToNearest5(
          (sortedRanks.last.value['lifts'][lowerLift] ?? 0) * userMultiplier);
    }

    // Calculate progress towards the next rank.
    double progress = 0.0;
    if (nextThreshold > currentThreshold) {
      progress = ((score - currentThreshold) / (nextThreshold - currentThreshold)).clamp(0.0, 1.0);
    } else if (nextThreshold == currentThreshold && nextThreshold > 0) { 
      // If at max rank or next threshold is same as current, progress is 1.0
      progress = 1.0;
    } else if (nextThreshold > 0) { // Case where user score is below the lowest standard but has a threshold
        progress = (score / nextThreshold).clamp(0.0, 1.0);
    }


    final energy = RankUtils.getInterpolatedEnergy(
        score: score, // Use the score already adjusted by userMultiplier
        thresholds: standards, // Pass standards data
        liftKey: lowerLift, // Use lowercase lift name
        userMultiplier: userMultiplier); // Pass multiplier
        
    final iconPath = 'assets/images/ranks/${matchedRank?.toLowerCase() ?? 'unranked'}.svg';

    return GestureDetector(
      onTap: onTap, // Tap to view lift details/play screen
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(lift, style: const TextStyle(color: Colors.white))),
            Expanded(flex: 2, child: Center(child: Text(RankUtils.formatKg(score), style: const TextStyle(color: Colors.white)))), // Display score with formatting
            Expanded(
              flex: 2,
              child: Column( // Progress bar section
                children: [
                  SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(getRankColor(matchedRank ?? 'Unranked')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Display current score / next threshold
                  Text(
                      (matchedRank == null && nextThreshold == 0) ? RankUtils.formatKg(score) // Only show current score if no next threshold
                      : isMax ? 'MAX RANK' 
                      : '${RankUtils.formatKg(score)} / ${RankUtils.formatKg(nextThreshold)}', 
                      style: const TextStyle(color: Colors.white, fontSize: 12)
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Center(child: SvgPicture.asset(iconPath, height: 24, width: 24))),
            Expanded(flex: 1, child: Center(child: Text(NumberFormat("###0").format(energy), style: const TextStyle(color: Colors.white)))),
            Expanded(flex: 1, child: IconButton(icon: const Icon(Icons.leaderboard, color: Colors.blue), onPressed: onLeaderboardTap)),
          ],
        ),
      ),
    );
  }

  // Helper to round to the nearest 5.
  double _roundToNearest5(double value) {
    return (value / 5).round() * 5.0;
  }
}