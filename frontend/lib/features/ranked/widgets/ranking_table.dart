import 'package:flutter/material.dart';
import 'package:frontend/features/ranked/screens/scenario_screen.dart';
import 'package:frontend/features/ranked/utils/rank_utils.dart';

class RankingTable extends StatelessWidget {
  final Map<String, dynamic>? liftStandards;
  final Map<String, double> userHighScores;
  final Function() onViewBenchmarks;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.userHighScores,
    required this.onViewBenchmarks,
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

    // Calculate ranks and energy
    int totalRawEnergy = 0;
    final liftRanks = <String, String>{};
    final liftEnergies = <String, int>{};

    userHighScores.forEach((lift, score) {
      final rank = RankUtils.calculateRank(score, liftStandards);
      liftRanks[lift] = rank;
      liftEnergies[lift] = RankUtils.rankEnergy[rank]!;
      totalRawEnergy += RankUtils.rankEnergy[rank]!;
    });

    final adjustedElo = totalRawEnergy / userHighScores.length;
    final overallRank = RankUtils.calculateRank(adjustedElo, liftStandards);

    return Column(
      children: [
        Text(
          'Energy: ${adjustedElo.toStringAsFixed(1)} ($overallRank)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const _RankingTableHeader(),
        const SizedBox(height: 12),
        ...userHighScores.entries
            .map((entry) => _RankingRow(
                  lift: entry.key,
                  score: entry.value,
                  standards: liftStandards!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScenarioScreen(liftName: entry.key),
                    ),
                  ),
                ))
            .toList(),
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Score',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: Text(
              'Progress',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Rank',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Energy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
    final rank = RankUtils.calculateRank(score, standards);
    final progress =
        RankUtils.calculateProgressPercentage(score, rank, standards);
    final energy = RankUtils.rankEnergy[rank]!;
    final sortedRanks = RankUtils.rankEnergy.keys.toList()
      ..sort((a, b) =>
          RankUtils.rankEnergy[b]!.compareTo(RankUtils.rankEnergy[a]!));

    final currentIndex = sortedRanks.indexOf(rank);
    final hasNextRank = currentIndex < sortedRanks.length - 1;
    final nextRank = hasNextRank ? sortedRanks[currentIndex + 1] : null;
    final nextBenchmark = hasNextRank && standards.containsKey(nextRank!)
        ? standards[nextRank]['total']
        : score;

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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
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
                    color: RankUtils.getRankColor(rank),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasNextRank
                        ? '${score.toStringAsFixed(1)} → ${nextBenchmark.toStringAsFixed(1)}'
                        : 'MAX RANK',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  rank,
                  style: TextStyle(
                    fontSize: 16,
                    color: RankUtils.getRankColor(rank),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
