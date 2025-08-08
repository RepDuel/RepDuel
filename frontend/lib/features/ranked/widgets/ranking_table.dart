// frontend/lib/features/ranked/widgets/ranking_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../utils/rank_utils.dart';
import '../../../core/providers/auth_provider.dart';

class RankingTable extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Get user multiplier from the auth provider
    final userMultiplier =
        ref.read(authStateProvider).user?.weightMultiplier ?? 1.0;

    if (liftStandards == null) {
      return const Center(
        child: Text(
          'No ranking data available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final defaultLifts = ['Squat', 'Bench', 'Deadlift'];
    final allLifts = {
      for (var lift in defaultLifts)
        lift: _normalizeAndGetScore(lift, userHighScores),
    };

    // Calculate individual energies and average
    final energies = allLifts.entries.map((entry) {
      final liftKey = entry.key.toLowerCase();
      final score =
          entry.value * userMultiplier; // Multiply score by userMultiplier
      return RankUtils.getInterpolatedEnergy(
          score: score, // Use adjusted score
          thresholds: liftStandards!,
          liftKey: liftKey,
          userMultiplier: userMultiplier);
    }).toList();

    final averageEnergy = energies.isNotEmpty
        ? energies.reduce((a, b) => a + b) / energies.length
        : 0.0;

    final overallRank = _getRankFromEnergy(averageEnergy);
    final overallColor = RankUtils.getRankColor(overallRank);

    // Notify parent of computed energy
    onEnergyComputed(averageEnergy.round(), overallRank);

    return Column(
      children: [
        // Display overall energy and rank
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Overall Energy: ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${averageEnergy.round()}',
              style: TextStyle(
                color: overallColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/images/ranks/${overallRank.toLowerCase()}.svg',
              height: 24,
              width: 24,
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard, color: Colors.blue),
              onPressed: onEnergyLeaderboardTapped,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _RankingTableHeader(),
        const SizedBox(height: 12),
        ...allLifts.entries.map(
          (entry) => _RankingRow(
            lift: entry.key,
            score: entry.value * userMultiplier, // Pass adjusted score
            standards: liftStandards!,
            onTap: () => onLiftTapped(entry.key),
            onLeaderboardTap: () =>
                onLeaderboardTapped(scenarioIds[entry.key]!),
            userMultiplier: userMultiplier, // Pass multiplier here
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onViewBenchmarks,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('View Benchmarks'),
        ),
      ],
    );
  }

  double _normalizeAndGetScore(String lift, Map<String, double> scores) =>
      scores.entries
          .firstWhere(
            (e) =>
                e.key.toLowerCase() == lift.toLowerCase() ||
                (lift == 'Bench' && e.key.toLowerCase().contains('bench')),
            orElse: () => const MapEntry('', 0.0),
          )
          .value;

  String _getRankFromEnergy(double energy) {
    final entries = RankUtils.rankEnergy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in entries) {
      if (energy >= entry.value) return entry.key;
    }
    return 'Unranked';
  }
}

class _RankingTableHeader extends StatelessWidget {
  const _RankingTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 2, child: Text('Lift', style: _headerStyle)),
        Expanded(
            flex: 2, child: Center(child: Text('Score', style: _headerStyle))),
        Expanded(
            flex: 2,
            child: Center(child: Text('Progress', style: _headerStyle))),
        Expanded(
            flex: 2, child: Center(child: Text('Rank', style: _headerStyle))),
        Expanded(
          flex: 2,
          child: Text('Energy', style: _headerStyle),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );
}

class _RankingRow extends StatelessWidget {
  final String lift;
  final double score;
  final Map<String, dynamic> standards;
  final VoidCallback onTap;
  final VoidCallback onLeaderboardTap;
  final double userMultiplier;

  const _RankingRow({
    required this.lift,
    required this.score,
    required this.standards,
    required this.onTap,
    required this.onLeaderboardTap,
    required this.userMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final lowerLift = lift.toLowerCase();
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) => ((b.value['lifts'][lowerLift] ?? 0) as num)
          .compareTo((a.value['lifts'][lowerLift] ?? 0) as num));

    String? matchedRank;
    double currentThreshold = 0.0, nextThreshold = 0.0;

    // Round thresholds to the nearest 5
    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      final adjustedThreshold = (threshold.toDouble() * userMultiplier);
      final roundedThreshold = _roundToNearest5(adjustedThreshold);

      if (score >= roundedThreshold) {
        matchedRank = entry.key;
        currentThreshold = roundedThreshold;
        break;
      }
    }

    // If no match was found, set next threshold to the last available rounded value
    if (matchedRank == null) {
      nextThreshold = _roundToNearest5(
          (sortedRanks.last.value['lifts'][lowerLift] ?? 0) * userMultiplier);
    }

    // Calculate next threshold if matched
    if (matchedRank != null) {
      final currentIndex = sortedRanks.indexWhere((e) => e.key == matchedRank);
      nextThreshold = currentIndex > 0
          ? _roundToNearest5(
              (sortedRanks[currentIndex - 1].value['lifts'][lowerLift] ?? 0) *
                  userMultiplier)
          : currentThreshold;
    }

    final progress = nextThreshold > currentThreshold
        ? ((score - currentThreshold) / (nextThreshold - currentThreshold))
            .clamp(0.0, 1.0)
        : (matchedRank == null && nextThreshold > 0
            ? (score / nextThreshold).clamp(0.0, 1.0)
            : 1.0);

    final energy = RankUtils.getInterpolatedEnergy(
        score: score,
        thresholds: standards,
        liftKey: lowerLift,
        userMultiplier: userMultiplier);
    final iconPath =
        'assets/images/ranks/${matchedRank?.toLowerCase() ?? 'unranked'}.svg';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
                flex: 2,
                child: Text(lift, style: const TextStyle(color: Colors.white))),
            Expanded(
                flex: 2,
                child: Center(
                    child: Text(RankUtils.formatKg(score),
                        style: const TextStyle(color: Colors.white)))),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      color: RankUtils.getRankColor(matchedRank ?? 'Unranked'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${RankUtils.formatKg(score)} / ${RankUtils.formatKg(nextThreshold)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                  child: SvgPicture.asset(iconPath, height: 24, width: 24)),
            ),
            Expanded(
                flex: 1,
                child: Center(
                    child: Text(NumberFormat("###0").format(energy),
                        style: const TextStyle(color: Colors.white)))),
            Expanded(
                flex: 1,
                child: IconButton(
                    icon: const Icon(Icons.leaderboard, color: Colors.blue),
                    onPressed: onLeaderboardTap)),
          ],
        ),
      ),
    );
  }

  // Helper method to round a value to the nearest 5
  double _roundToNearest5(double value) {
    return (value / 5).round() * 5.0;
  }
}
