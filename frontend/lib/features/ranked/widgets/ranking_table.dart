// frontend/lib/features/ranked/widgets/ranking_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../utils/rank_utils.dart';

class RankingTable extends ConsumerWidget {
  final Map<String, dynamic> liftStandards;
  final Map<String, double> userHighScores;
  final Function() onViewBenchmarks;
  final Function(String liftName) onLiftTapped;
  final Function(String scenarioId) onLeaderboardTapped;
  final VoidCallback onEnergyLeaderboardTapped;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.userHighScores,
    required this.onViewBenchmarks,
    required this.onLiftTapped,
    required this.onLeaderboardTapped,
    required this.onEnergyLeaderboardTapped,
  });

  static const scenarioIds = {
    'Squat': 'back_squat',
    'Bench': 'barbell_bench_press',
    'Deadlift': 'deadlift',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    if (user == null) return const Center(child: Text('User not found.'));

    // Read the official energy and rank from the single source of truth.
    final officialEnergy = user.energy.round();
    final officialRank = user.rank ?? 'Unranked';
    final overallColor = getRankColor(officialRank);

    final weightMultiplier = user.weightMultiplier;
    final defaultLifts = ['Squat', 'Bench', 'Deadlift'];
    final allLifts = <String, double>{};
    for (var lift in defaultLifts) {
      final scoreInKg = userHighScores[lift] ?? 0.0;
      allLifts[lift] = scoreInKg * weightMultiplier;
    }

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
            Text('$officialEnergy',
                style: TextStyle(
                    color: overallColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            // The SVG is now rendered with its original colors.
            SvgPicture.asset(
              'assets/images/ranks/${officialRank.toLowerCase()}.svg',
              height: 24,
              width: 24,
            ),
            IconButton(
                icon: const Icon(Icons.leaderboard, color: Colors.blueAccent),
                onPressed: onEnergyLeaderboardTapped),
          ],
        ),
        const SizedBox(height: 16),
        const _RankingTableHeader(),
        const SizedBox(height: 12),
        ...allLifts.entries.map(
          (entry) => _RankingRow(
            lift: entry.key,
            score: entry.value,
            standards: liftStandards,
            onTap: () => onLiftTapped(entry.key),
            onLeaderboardTap: () =>
                onLeaderboardTapped(scenarioIds[entry.key]!),
            userMultiplier: weightMultiplier,
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
  }
}

class _RankingTableHeader extends StatelessWidget {
  const _RankingTableHeader();

  @override
  Widget build(BuildContext context) {
    const headerStyle =
        TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Lift', style: headerStyle)),
          Expanded(
              flex: 2, child: Center(child: Text('Score', style: headerStyle))),
          Expanded(
              flex: 2,
              child: Center(child: Text('Progress', style: headerStyle))),
          Expanded(
              flex: 2, child: Center(child: Text('Rank', style: headerStyle))),
          Expanded(
              flex: 1,
              child: Center(child: Text('Energy', style: headerStyle))),
          Expanded(flex: 1, child: SizedBox.shrink()),
        ],
      ),
    );
  }
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

  double _roundToNearest5(double value) {
    return (value / 5).round() * 5.0;
  }

  @override
  Widget build(BuildContext context) {
    final lowerLift = lift.toLowerCase();
    final sortedRanks = standards.entries.toList()
      ..sort((a, b) =>
          (a.value['lifts'][lowerLift] ?? 0)
              .compareTo(b.value['lifts'][lowerLift] ?? 0) *
          -1);

    String? matchedRank;
    double currentThreshold = 0.0;
    double nextThreshold = 0.0;

    for (final entry in sortedRanks) {
      final threshold = (entry.value['lifts'][lowerLift] ?? 0) as num;
      final adjustedThreshold = _roundToNearest5(threshold * userMultiplier);
      if (score >= adjustedThreshold) {
        matchedRank = entry.key;
        currentThreshold = adjustedThreshold;
        break;
      }
    }

    final bool isMax = (matchedRank != null &&
        matchedRank == (sortedRanks.isNotEmpty ? sortedRanks.first.key : null));

    if (isMax) {
      nextThreshold = currentThreshold;
    } else if (matchedRank != null) {
      final currentIndex = sortedRanks.indexWhere((e) => e.key == matchedRank);
      if (currentIndex > 0) {
        nextThreshold = _roundToNearest5(
            (sortedRanks[currentIndex - 1].value['lifts'][lowerLift] ?? 0) *
                userMultiplier);
      }
    } else {
      nextThreshold = sortedRanks.isNotEmpty
          ? _roundToNearest5((sortedRanks.last.value['lifts'][lowerLift] ?? 0) *
              userMultiplier)
          : 0;
    }

    double progress = 0.0;
    if (isMax) {
      progress = 1.0;
    } else if (nextThreshold > currentThreshold) {
      progress =
          ((score - currentThreshold) / (nextThreshold - currentThreshold))
              .clamp(0.0, 1.0);
    } else if (nextThreshold > 0) {
      progress = (score / nextThreshold).clamp(0.0, 1.0);
    }

    final energy = getInterpolatedEnergy(
        score: score,
        thresholds: standards,
        liftKey: lowerLift,
        userMultiplier: userMultiplier);
    final rankColor = getRankColor(matchedRank ?? 'Unranked');
    final iconPath =
        'assets/images/ranks/${matchedRank?.toLowerCase() ?? 'unranked'}.svg';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(
                flex: 2,
                child: Text(lift, style: const TextStyle(color: Colors.white))),
            Expanded(
                flex: 2,
                child: Center(
                    child: Text(formatKg(score),
                        style: const TextStyle(color: Colors.white)))),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ✅ Always show "<score> / <nextThreshold>", no more "MAX RANK"
                  Text(
                    '${formatKg(score)} / ${formatKg(nextThreshold)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
                flex: 2,
                child: Center(
                    child: SvgPicture.asset(iconPath, height: 24, width: 24))),
            Expanded(
                flex: 1,
                child: Center(
                    child: Text(NumberFormat("###0").format(energy),
                        style: const TextStyle(color: Colors.white)))),
            Expanded(
                flex: 1,
                child: IconButton(
                    icon:
                        const Icon(Icons.leaderboard, color: Colors.blueAccent),
                    onPressed: onLeaderboardTap)),
          ],
        ),
      ),
    );
  }
}
