import 'package:flutter/material.dart';
import 'package:frontend/features/ranked/utils/rank_utils.dart';

class RankingTable extends StatelessWidget {
  final Map<String, dynamic>? liftStandards;
  final Map<String, double> userHighScores;
  final Function() onViewBenchmarks;
  final Function(String liftName) onLiftTapped;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.userHighScores,
    required this.onViewBenchmarks,
    required this.onLiftTapped,
  });

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

    final energies = allLifts.entries.map((entry) {
      final rank = _getLiftRank(entry.key, entry.value, liftStandards!);
      return RankUtils.rankEnergy[rank] ?? 0;
    }).toList();

    final averageEnergy = energies.isNotEmpty
        ? energies.reduce((a, b) => a + b) / energies.length
        : 0.0;

    final overallRank = _getRankFromEnergy(averageEnergy);
    final color = RankUtils.getRankColor(overallRank);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Rank: ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${averageEnergy.round()} $overallRank',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

  double _normalizeAndGetScore(String lift, Map<String, double> scores) {
    for (var entry in scores.entries) {
      final name = entry.key.toLowerCase();
      if (lift.toLowerCase() == name ||
          (lift == 'Bench' && name.contains('bench'))) {
        return entry.value;
      }
    }
    return 0.0;
  }

  String _getLiftRank(
      String lift, double score, Map<String, dynamic> standards) {
    final lowerLift = lift.toLowerCase();
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) => ((b.value['lifts'][lowerLift] ?? 0) as num)
          .compareTo((a.value['lifts'][lowerLift] ?? 0) as num));

    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      if (score >= threshold.toDouble()) {
        return entry.key;
      }
    }

    return 'Iron';
  }

  String _getRankFromEnergy(double energy) {
    final entries = RankUtils.rankEnergy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in entries) {
      if (energy >= entry.value) return entry.key;
    }

    return 'Iron';
  }
}

class _RankingTableHeader extends StatelessWidget {
  const _RankingTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'Lift',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Score',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: Text(
              'Progress',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Rank',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Energy',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  final String lift;
  final double score;
  final Map<String, dynamic> standards;
  final VoidCallback onTap;

  const _RankingRow({
    required this.lift,
    required this.score,
    required this.standards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lowerLift = lift.toLowerCase();

    final sortedRanks = standards.entries.toList()
      ..sort((a, b) => ((b.value['lifts'][lowerLift] ?? 0) as num)
          .compareTo((a.value['lifts'][lowerLift] ?? 0) as num));

    String currentRank = 'Iron';
    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      if (score >= threshold.toDouble()) {
        currentRank = entry.key;
        break;
      }
    }

    final currentIndex = sortedRanks.indexWhere((e) => e.key == currentRank);
    final hasNext = currentIndex > 0;
    final nextRank = hasNext ? sortedRanks[currentIndex - 1].key : null;
    final nextBenchmark = hasNext
        ? (standards[nextRank]!['lifts'][lowerLift] ?? score) as num
        : score;

    final progress = RankUtils.calculateProgressPercentage(
      score,
      currentRank,
      Map.fromEntries(
        standards.entries.map((e) => MapEntry(
              e.key,
              {'total': (e.value['lifts'][lowerLift] ?? 0)},
            )),
      ),
    );

    final energy = RankUtils.rankEnergy[currentRank] ?? 0;
    final color = RankUtils.getRankColor(currentRank);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                lift,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  RankUtils.formatKg(score),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    color: color,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasNext && nextBenchmark.toDouble() > score
                        ? '${RankUtils.formatKg(score)} / ${RankUtils.formatKg(nextBenchmark.toDouble())}'
                        : 'MAX RANK',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  currentRank,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  energy.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
