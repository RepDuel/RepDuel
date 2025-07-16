// frontend/lib/features/ranked/widgets/ranking_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:frontend/features/ranked/utils/rank_utils.dart';

class RankingTable extends StatelessWidget {
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
    'Squat': 'a9b52e3a-248d-4a89-82ab-555be989de5b',
    'Bench': 'bf610e59-fb34-4e21-bc36-bdf0f6f7be4f',
    'Deadlift': '9b6cf826-e243-4d3e-81bd-dfe4a8a0c05e',
  };

  @override
  Widget build(BuildContext context) {
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
      final score = entry.value;
      return RankUtils.getInterpolatedEnergy(
        score: score,
        thresholds: liftStandards!,
        liftKey: liftKey,
      );
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
            score: entry.value,
            standards: liftStandards!,
            onTap: () => onLiftTapped(entry.key),
            onLeaderboardTap: () =>
                onLeaderboardTapped(scenarioIds[entry.key]!),
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
            flex: 1, child: Center(child: Text('Energy', style: _headerStyle))),
        Expanded(flex: 1, child: Center(child: Text('', style: _headerStyle))),
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

  const _RankingRow({
    required this.lift,
    required this.score,
    required this.standards,
    required this.onTap,
    required this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    final lowerLift = lift.toLowerCase();
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) => ((b.value['lifts'][lowerLift] ?? 0) as num)
          .compareTo((a.value['lifts'][lowerLift] ?? 0) as num));

    String? matchedRank;
    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      if (score >= threshold.toDouble()) {
        matchedRank = entry.key;
        break;
      }
    }
    final currentRank = matchedRank ?? 'Unranked';

    double currentThreshold = 0.0, nextThreshold = 0.0;
    if (matchedRank != null) {
      final currentIndex = sortedRanks.indexWhere((e) => e.key == matchedRank);
      currentThreshold =
          (sortedRanks[currentIndex].value['lifts'][lowerLift] ?? 0).toDouble();
      nextThreshold = currentIndex > 0
          ? (sortedRanks[currentIndex - 1].value['lifts'][lowerLift] ?? 0)
              .toDouble()
          : currentThreshold;
    } else {
      nextThreshold =
          (sortedRanks.last.value['lifts'][lowerLift] ?? 0).toDouble();
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
    );
    final iconPath = 'assets/images/ranks/${currentRank.toLowerCase()}.svg';

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
                      color: RankUtils.getRankColor(currentRank),
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
                child: SvgPicture.asset(iconPath, height: 24, width: 24),
              ),
            ),
            Expanded(
                flex: 1,
                child: Center(
                    child: Text('$energy',
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
}
