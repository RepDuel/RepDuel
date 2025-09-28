// frontend/lib/features/routines/screens/summary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart'; // ← needed for context.go

import '../../../core/providers/auth_provider.dart';
import '../models/summary_personal_best.dart';

class SummaryScreen extends ConsumerWidget {
  final double totalVolumeKg;
  final List<SummaryPersonalBest> personalBests;
  final double? durationMinutes;

  const SummaryScreen({
    super.key,
    required this.totalVolumeKg,
    this.personalBests = const [],
    this.durationMinutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    final isLbs = (user?.weightMultiplier ?? 1.0) > 1.5;
    final displayVolume = isLbs ? totalVolumeKg * 2.20462 : totalVolumeKg;

    return PopScope(
      canPop: false, // block back navigation from returning to ExerciseList
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // user tried to go back → send them to the Routines tab instead
          GoRouter.of(context).go('/routines');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Routine Summary'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Routine Complete!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Total Volume Lifted:',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${displayVolume.round()} ${isLbs ? 'lbs' : 'kg'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (durationMinutes != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Duration:',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[400],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(durationMinutes!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        _PersonalBestsSection(
                          personalBests: personalBests,
                          isLbs: isLbs,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Done → take them to the Routines tab (not back to exercise list)
                      context.go('/routines');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 32,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(double minutes) {
    final totalSeconds = (minutes * 60).round();
    final hours = totalSeconds ~/ 3600;
    final minutesPart = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      final twoDigitMinutes = minutesPart.toString().padLeft(2, '0');
      final twoDigitSeconds = seconds.toString().padLeft(2, '0');
      return '$hours:$twoDigitMinutes:$twoDigitSeconds';
    }

    if (minutesPart > 0) {
      final twoDigitSeconds = seconds.toString().padLeft(2, '0');
      return '$minutesPart:$twoDigitSeconds';
    }

    return '${seconds}s';
  }
}

class _PersonalBestsSection extends StatelessWidget {
  final List<SummaryPersonalBest> personalBests;
  final bool isLbs;

  const _PersonalBestsSection({
    required this.personalBests,
    required this.isLbs,
  });

  @override
  Widget build(BuildContext context) {
    if (personalBests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Icon(Icons.insights, color: Colors.white24, size: 42),
          SizedBox(height: 12),
          Text(
            'No highlights logged this session — keep pushing!',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.emoji_events, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text(
              'Session Highlights',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...personalBests.map(
          (best) => _PersonalBestTile(best: best, isLbs: isLbs),
        ),
      ],
    );
  }
}

class _PersonalBestTile extends StatelessWidget {
  final SummaryPersonalBest best;
  final bool isLbs;

  const _PersonalBestTile({required this.best, required this.isLbs});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;
    const minWidth = 300.0;
    const maxWidth = 600.0;

    final displayUnit = isLbs ? 'lbs' : 'kg';
    final weightDisplay = _formatNumber(
      isLbs ? best.weightKg * 2.20462 : best.weightKg,
      decimalForLarge: false,
    );
    final oneRmDisplay = _formatNumber(
      isLbs ? best.scoreValue * 2.20462 : best.scoreValue,
      decimalForLarge: true,
    );

    final subtitle = best.isBodyweight
        ? '${best.reps} reps'
        : '$weightDisplay $displayUnit × ${best.reps} reps';
    final scoreLabel = best.isBodyweight
        ? '${_formatNumber(best.scoreValue, decimalForLarge: true)} reps'
        : '$oneRmDisplay $displayUnit';

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: isWide ? minWidth : double.infinity,
          maxWidth: isWide ? maxWidth : double.infinity,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                best.exerciseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (best.isPersonalBest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green[700]?.withValues(alpha: 0.4) ??
                        Colors.green.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent, width: 1),
                  ),
                  child: const Text(
                    'New Personal Record',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (best.isPersonalBest) const SizedBox(height: 12),
              Text(
                'Best Set',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                best.isBodyweight ? 'Score' : '1RM',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                scoreLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _RankDisplay(rankName: best.rankName),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value, {bool decimalForLarge = true}) {
    final absValue = value.abs();
    final decimals = (absValue >= 100 && decimalForLarge) ? 0 : 1;
    final str = value.toStringAsFixed(decimals);
    if (decimals == 0) {
      return str;
    }
    return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
  }
}

class _RankDisplay extends StatelessWidget {
  final String rankName;

  const _RankDisplay({required this.rankName});

  @override
  Widget build(BuildContext context) {
    final badgePath = _rankAssetForName(rankName);
    final displayName = rankName.trim().isEmpty ? 'Unranked' : rankName;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          badgePath,
          height: 36,
          width: 36,
        ),
        const SizedBox(width: 12),
        Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _rankAssetForName(String name) {
    const knownBadges = {
      'iron',
      'bronze',
      'silver',
      'gold',
      'platinum',
      'diamond',
      'jade',
      'master',
      'grandmaster',
      'nova',
      'astra',
      'celestial',
      'unranked',
    };

    final normalized = name.toLowerCase().replaceAll(' ', '');
    if (knownBadges.contains(normalized)) {
      return 'assets/images/ranks/$normalized.svg';
    }
    return 'assets/images/ranks/unranked.svg';
  }
}
