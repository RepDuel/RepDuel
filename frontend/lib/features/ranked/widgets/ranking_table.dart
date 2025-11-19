// frontend/lib/features/ranked/widgets/ranking_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../utils/rank_utils.dart';

class LiftSpec {
  final String key;
  final String scenarioId;
  final String? name;
  final String? shortLabel;
  const LiftSpec({
    required this.key,
    required this.scenarioId,
    this.name,
    this.shortLabel,
  });
}

class RankingTable extends ConsumerWidget {
  final Map<String, dynamic> liftStandards;
  final List<LiftSpec> lifts;
  final Map<String, double> userHighScores;
  final Map<String, String>? aliases;
  final Function() onViewBenchmarks;
  final Function(String liftKey) onLiftTapped;
  final Function(String scenarioId) onLeaderboardTapped;
  final VoidCallback onEnergyLeaderboardTapped;

  const RankingTable({
    super.key,
    required this.liftStandards,
    required this.lifts,
    required this.userHighScores,
    required this.onViewBenchmarks,
    required this.onLiftTapped,
    required this.onLeaderboardTapped,
    required this.onEnergyLeaderboardTapped,
    this.aliases,
  });

  String _titleize(String s) {
    if (s.isEmpty) return s;
    final parts = s
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final t = parts
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
    return t;
  }

  String _shorten(String input) {
    if (input.length <= 10) return input;
    final abbrev = <String, String>{
      'Barbell Bench Press': 'Bench',
      'Bench Press': 'Bench',
      'Back Squat': 'BackSq',
      'Front Squat': 'FrontSq',
      'Deadlift': 'Deadlift',
      'Conventional Deadlift': 'Deadlift',
      'Overhead Press': 'OH Press',
      'Shoulder Press': 'Sh Press',
    };
    if (abbrev.containsKey(input)) {
      final v = abbrev[input]!;
      return v.length <= 10 ? v : v.substring(0, 10);
    }
    final words =
        input.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      String joinInitialsThenCore() {
        final initials =
            words.take(words.length - 1).map((w) => w[0].toUpperCase()).join();
        final last = words.last.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        final candidate = initials + last;
        if (candidate.length <= 10) return candidate;
        return candidate.substring(0, 10);
      }

      final candidate = joinInitialsThenCore();
      if (candidate.isNotEmpty) return candidate;
    }
    return input.substring(0, 10);
  }

  double _scoreForKey(String key) {
    if (userHighScores.containsKey(key)) return userHighScores[key] ?? 0.0;
    final builtIn = {
      'Squat': 'back_squat',
      'Bench': 'barbell_bench_press',
      'Deadlift': 'deadlift'
    };
    final aliasMap = {...builtIn, ...(aliases ?? {})};
    final found = aliasMap.entries.firstWhere(
      (e) => userHighScores.containsKey(e.key) && e.value == key,
      orElse: () => const MapEntry('', ''),
    );
    if (found.key.isNotEmpty) return userHighScores[found.key] ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    if (user == null) return const Center(child: Text('User not found.'));
    final officialEnergy = user.energy.round();
    final officialRank = user.rank ?? 'Unranked';
    final overallColor = getRankColor(officialRank);

    // Multiplier converts stored kg scores to display/pack unit
    final weightMultiplier = user.weightMultiplier;

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'Energy: ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$officialEnergy $officialRank',
              style: TextStyle(
                color: overallColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              'assets/images/ranks/${officialRank.toLowerCase()}.svg',
              height: 24,
              width: 24,
            ),
            IconButton(
              icon: Icon(Icons.leaderboard, color: primaryColor),
              onPressed: onEnergyLeaderboardTapped,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _RankingTableHeader(),
        const SizedBox(height: 12),
        ...lifts.map((spec) {
          final key = spec.key;
          final scoreKg = _scoreForKey(key);
          // Convert score to pack/display unit using multiplier
          // Round to 1 decimal place to match display precision (formatKg)
          // This ensures comparisons use the same value the user sees
          final score = ((scoreKg * weightMultiplier) * 10).round() / 10;

          // Backend already provides thresholds rounded in the chosen unit.
          final entries = liftStandards.entries.toList()
            ..sort((a, b) {
              final av = (a.value['lifts'][key] ?? 0) as num;
              final bv = (b.value['lifts'][key] ?? 0) as num;
              return (av.compareTo(bv)) * -1;
            });

          String? matchedRank;
          double currentThreshold = 0.0;
          double nextThreshold = 0.0;

          for (final e in entries) {
            final threshold = (e.value['lifts'][key] ?? 0) as num;
            final th = threshold.toDouble(); // already in unit & rounded
            if (score >= th) {
              matchedRank = e.key;
              currentThreshold = th;
              break;
            }
          }

          final isMax = matchedRank != null &&
              entries.isNotEmpty &&
              matchedRank == entries.first.key;

          if (isMax) {
            nextThreshold = currentThreshold;
          } else if (matchedRank != null) {
            final idx = entries.indexWhere((e) => e.key == matchedRank);
            if (idx > 0) {
              nextThreshold =
                  ((entries[idx - 1].value['lifts'][key] ?? 0) as num)
                      .toDouble();
            }
          } else {
            nextThreshold = entries.isNotEmpty
                ? ((entries.last.value['lifts'][key] ?? 0) as num).toDouble()
                : 0.0;
          }

          double progress = 0.0;
          if (isMax) {
            progress = 1.0;
          } else if (nextThreshold > currentThreshold) {
            progress = ((score - currentThreshold) /
                    (nextThreshold - currentThreshold))
                .clamp(0.0, 1.0);
          } else if (nextThreshold > 0) {
            progress = (score / nextThreshold).clamp(0.0, 1.0);
          }

          final energy = getInterpolatedEnergy(
            score: score,
            thresholds: liftStandards,
            liftKey: key,
            userMultiplier: 1.0,
          );
          final rankColor = getRankColor(matchedRank ?? 'Unranked');
          final iconPath =
              'assets/images/ranks/${matchedRank?.toLowerCase() ?? 'unranked'}.svg';

          final baseName = spec.name ?? _titleize(key);
          final display = spec.shortLabel ?? _shorten(baseName);

          Text oneLine(String s, {TextStyle? style}) => Text(s,
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible);

          return GestureDetector(
            onTap: () => onLiftTapped(key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      flex: 2,
                      child: oneLine(display,
                          style: const TextStyle(color: Colors.white))),
                  Expanded(
                    flex: 2,
                    child: Center(
                        child: oneLine(formatKg(score),
                            style: const TextStyle(color: Colors.white))),
                  ),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(rankColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        oneLine(
                            '${formatKg(score)} / ${formatKg(nextThreshold)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                      flex: 2,
                      child: Center(
                          child: SvgPicture.asset(iconPath,
                              height: 24, width: 24))),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: oneLine(
                        NumberFormat("###0").format(energy),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(Icons.leaderboard,
                            color: primaryColor, size: 20),
                        onPressed: () => onLeaderboardTapped(spec.scenarioId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onViewBenchmarks,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: onPrimary,
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
    const headerStyle =
        TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: const [
          Expanded(
            flex: 2,
            child: Text('Lift',
                style: headerStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible),
          ),
          SizedBox(width: 0),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('1RM',
                  style: headerStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('Progress',
                  style: headerStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text('Rank',
                  style: headerStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text('Energy',
                  style: headerStyle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible),
            ),
          ),
          Expanded(flex: 1, child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
