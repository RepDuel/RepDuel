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
  // 1. REMOVE the onEnergyComputed callback to break the infinite loop.
  // final Function(int energy, String rank) onEnergyComputed;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.userHighScores,
    required this.onViewBenchmarks,
    required this.onLiftTapped,
    required this.onLeaderboardTapped,
    required this.onEnergyLeaderboardTapped,
    // required this.onEnergyComputed, // Removed
  });

  static const scenarioIds = {
    'Squat': 'back_squat',
    'Bench': 'barbell_bench_press',
    'Deadlift': 'deadlift',
  };

  String _getRankFromEnergy(double energy) {
    final entries = RankUtils.rankEnergy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in entries) {
      if (energy >= entry.value) return entry.key;
    }
    return 'Unranked';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider).valueOrNull;

    if (authState?.user == null) {
      return const Center(child: Text('User not found.'));
    }
    final user = authState!.user!;
    final weightMultiplier = user.weightMultiplier;

    final defaultLifts = ['Squat', 'Bench', 'Deadlift'];
    final allLifts = <String, double>{};

    for (var lift in defaultLifts) {
      final scoreInKg = userHighScores[lift] ?? 0.0;
      allLifts[lift] = scoreInKg * weightMultiplier;
    }
    
    final energies = allLifts.entries.map((entry) {
      final liftKey = entry.key.toLowerCase();
      final scoreWithMultiplier = entry.value;
      return RankUtils.getInterpolatedEnergy(
          score: scoreWithMultiplier,
          thresholds: liftStandards,
          liftKey: liftKey,
          userMultiplier: weightMultiplier);
    }).toList();

    final averageEnergy = energies.isNotEmpty ? energies.reduce((a, b) => a + b) / energies.length : 0.0;
    final overallRank = _getRankFromEnergy(averageEnergy);
    final overallColor = getRankColor(overallRank);

    // 2. REMOVE the post-frame callback. The widget no longer triggers side effects.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   onEnergyComputed(averageEnergy.round(), overallRank);
    // });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Overall Energy: ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${averageEnergy.round()}', style: TextStyle(color: overallColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SvgPicture.asset('assets/images/ranks/${overallRank.toLowerCase()}.svg', height: 24, width: 24, colorFilter: ColorFilter.mode(overallColor, BlendMode.srcIn)),
            IconButton(
              icon: const Icon(Icons.leaderboard, color: Colors.blueAccent),
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
            standards: liftStandards,
            onTap: () => onLiftTapped(entry.key),
            onLeaderboardTap: () => onLeaderboardTapped(scenarioIds[entry.key]!),
            userMultiplier: weightMultiplier,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onViewBenchmarks,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
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
    const headerStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Lift', style: headerStyle)),
          Expanded(flex: 2, child: Center(child: Text('Score', style: headerStyle))),
          Expanded(flex: 2, child: Center(child: Text('Progress', style: headerStyle))),
          Expanded(flex: 2, child: Center(child: Text('Rank', style: headerStyle))),
          Expanded(flex: 1, child: Center(child: Text('Energy', style: headerStyle))),
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
      ..sort((a, b) {
        final scoreA = (a.value['lifts'][lowerLift] ?? 0) as num;
        final scoreB = (b.value['lifts'][lowerLift] ?? 0) as num;
        return scoreB.compareTo(scoreA); // Descending
      });

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
    
    final bool isMax;
    final highestRankName = sortedRanks.isNotEmpty ? sortedRanks.first.key : null;
    isMax = (matchedRank != null && matchedRank == highestRankName);

    if (isMax) {
      nextThreshold = currentThreshold;
    } else if (matchedRank != null) {
      final currentIndex = sortedRanks.indexWhere((e) => e.key == matchedRank);
      if (currentIndex > 0) {
        nextThreshold = _roundToNearest5((sortedRanks[currentIndex - 1].value['lifts'][lowerLift] ?? 0) * userMultiplier);
      }
    } else {
      nextThreshold = sortedRanks.isNotEmpty ? _roundToNearest5((sortedRanks.last.value['lifts'][lowerLift] ?? 0) * userMultiplier) : 0;
    }

    double progress = 0.0;
    if (isMax) {
      progress = 1.0;
    } else if (nextThreshold > currentThreshold) {
      progress = ((score - currentThreshold) / (nextThreshold - currentThreshold)).clamp(0.0, 1.0);
    } else if (nextThreshold > 0) {
      progress = (score / nextThreshold).clamp(0.0, 1.0);
    }

    final energy = RankUtils.getInterpolatedEnergy(score: score, thresholds: standards, liftKey: lowerLift, userMultiplier: userMultiplier);
    final rankColor = getRankColor(matchedRank ?? 'Unranked');
    final iconPath = 'assets/images/ranks/${matchedRank?.toLowerCase() ?? 'unranked'}.svg';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(lift, style: const TextStyle(color: Colors.white))),
            Expanded(flex: 2, child: Center(child: Text(RankUtils.formatKg(score), style: const TextStyle(color: Colors.white)))),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  SizedBox(height: 6, child: LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[800], valueColor: AlwaysStoppedAnimation<Color>(rankColor))),
                  const SizedBox(height: 4),
                  Text(isMax ? 'MAX RANK' : '${RankUtils.formatKg(score)} / ${RankUtils.formatKg(nextThreshold)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            Expanded(flex: 2, child: Center(child: SvgPicture.asset(iconPath, height: 24, width: 24, colorFilter: ColorFilter.mode(rankColor, BlendMode.srcIn)))),
            Expanded(flex: 1, child: Center(child: Text(NumberFormat("###0").format(energy), style: const TextStyle(color: Colors.white)))),
            Expanded(flex: 1, child: IconButton(icon: const Icon(Icons.leaderboard, color: Colors.blueAccent), onPressed: onLeaderboardTap)),
          ],
        ),
      ),
    );
  }
}