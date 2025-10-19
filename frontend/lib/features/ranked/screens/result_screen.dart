// frontend/lib/features/ranked/screens/result_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:screenshot/screenshot.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../core/services/share_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../utils/bodyweight_benchmarks.dart';
import '../utils/lift_progress.dart';
import '../utils/rank_utils.dart';
import '../widgets/score_history_chart.dart';

class ShareableResultCard extends StatelessWidget {
  final String username;
  final String scenarioName;
  final String finalScore;
  final String rankName;
  final Color rankColor;
  const ShareableResultCard({
    super.key,
    required this.username,
    required this.scenarioName,
    required this.finalScore,
    required this.rankName,
    required this.rankColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'achieved a new score in',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            scenarioName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 20),
          SvgPicture.asset(
            'assets/images/ranks/${rankName.toLowerCase()}.svg',
            height: 80,
          ),
          const SizedBox(height: 12),
          Text(
            rankName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: rankColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Score: $finalScore',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'RepDuel',
            style: TextStyle(
              color: Colors.blue.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

final scenarioDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, scenarioId) async {
  final client = ref.watch(privateHttpClientProvider);
  final res = await client.get('/scenarios/$scenarioId/details');
  return (res.data as Map).cast<String, dynamic>();
});

final standardsPackProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authProvider.select((s) => s.valueOrNull?.user));
  if (user == null) throw Exception("User not authenticated.");
  final bodyweightKg = user.weight ?? 90.7;
  final gender = user.genderForApi();
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/standards/$bodyweightKg?gender=$gender');
  return (response.data as Map).cast<String, dynamic>();
});

class ResultScreen extends ConsumerStatefulWidget {
  final double finalScore;
  final double previousBest;
  final String scenarioId;
  const ResultScreen({
    super.key,
    required this.finalScore,
    required this.previousBest,
    required this.scenarioId,
  });
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  static const double _adjacentBadgeSize = 56.0;
  static const double _adjacentBadgeSpacing = 16.0;

  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String _unitFromMultiplier(double m) =>
      (m - 2.20462).abs() < 0.01 ? 'lbs' : 'kg';

  double _round5(double v) => (v / 5).round() * 5.0;
  double _round1(double v) => v.roundToDouble();

  Widget _buildAdjacentBadge(String assetName, Alignment alignment) {
    return SizedBox(
      width: _adjacentBadgeSize,
      height: _adjacentBadgeSize,
      child: Align(
        alignment: alignment,
        child: Opacity(
          opacity: 0.5,
          child: SvgPicture.asset(
            'assets/images/ranks/$assetName.svg',
            height: _adjacentBadgeSize,
            width: _adjacentBadgeSize,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _packToDisplay(
    Map<String, dynamic> standardsKg,
    double mult,
  ) {
    final out = <String, dynamic>{};
    standardsKg.forEach((rank, node) {
      final lifts = (node is Map<String, dynamic>)
          ? (node['lifts'] as Map<String, dynamic>?)
          : null;
      final total = (node is Map<String, dynamic>) ? node['total'] : null;

      final mappedLifts = <String, double>{};
      if (lifts != null) {
        lifts.forEach((k, v) {
          if (v is num) {
            mappedLifts[k] = _round5(v.toDouble() * mult);
          }
        });
      }

      out[rank] = {
        'total': total,
        'lifts': mappedLifts,
        'metadata': (node is Map<String, dynamic>) ? node['metadata'] : null,
      };
    });
    return out;
  }

  Future<void> _handleShare({
    required String scenarioName,
    required String matchedRank,
    required double finalScoreDisplay,
    required String unit,
    required String username,
    required Color rankColor,
  }) async {
    setState(() => _isSharing = true);
    try {
      await ref.read(shareServiceProvider).shareResult(
            context: context,
            screenshotController: _screenshotController,
            username: username,
            scenarioName: scenarioName,
            finalScore: '${finalScoreDisplay.toStringAsFixed(1)} $unit',
            rankName: matchedRank,
            rankColor: rankColor,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _popUpTwo(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav2 = Navigator.of(context);
        if (nav2.canPop()) {
          nav2.pop(true);
        } else {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          }
        }
      });
    } else {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final user = auth?.user;
    if (user == null) {
      return _wrapWithPopGuard(
        _buildScaffold(
          const Center(child: Text("User not authenticated.")),
        ),
      );
    }

    final weightMultiplier = user.weightMultiplier;
    final isFemale = (user.gender?.toLowerCase() == 'female');
    final unit = _unitFromMultiplier(weightMultiplier);

    final scoreForRankCalcKg = widget.finalScore > widget.previousBest
        ? widget.finalScore
        : widget.previousBest.toDouble();

    final scenarioAsync = ref.watch(scenarioDetailsProvider(widget.scenarioId));
    final standardsAsync = ref.watch(standardsPackProvider);

    return standardsAsync.when(
      loading: () => _wrapWithPopGuard(
        _buildScaffold(const Center(child: LoadingSpinner())),
      ),
      error: (err, _) => _wrapWithPopGuard(
        _buildScaffold(
          Center(
            child: ErrorDisplay(
              message: err.toString(),
              onRetry: () => ref.refresh(standardsPackProvider),
            ),
          ),
        ),
      ),
      data: (standardsKg) {
        return scenarioAsync.when(
          loading: () => _wrapWithPopGuard(
            _buildScaffold(const Center(child: LoadingSpinner())),
          ),
          error: (err, _) => _wrapWithPopGuard(
            _buildScaffold(
              Center(
                child: ErrorDisplay(
                  message: err.toString(),
                  onRetry: () =>
                      ref.refresh(scenarioDetailsProvider(widget.scenarioId)),
                ),
              ),
            ),
          ),
          data: (scenario) {
            final scenarioName = (scenario['name'] as String?) ?? 'Scenario';
            final liftKey = (scenario['id'] as String?) ?? widget.scenarioId;
            final scenarioMultiplier =
                (scenario['multiplier'] as num?)?.toDouble() ?? 1.0;
            final isBodyweight = (scenario['is_bodyweight'] as bool?) ?? false;
            Map<String, dynamic> scenarioStandards;
            String displayUnit;
            double multForScenario;
            double finalScoreDisplay;
            double comparisonScoreDisplay;

            if (isBodyweight) {
              final calibrationRaw =
                  scenario['calibration'] as Map<String, dynamic>?;
              final weightKg = (user.weight ?? 90.7).toDouble();
              if (calibrationRaw != null && calibrationRaw.isNotEmpty) {
                final calibration = {
                  for (final entry in calibrationRaw.entries)
                    entry.key: (entry.value as num).toDouble(),
                };
                final thresholds = generateBodyweightBenchmarks(
                  calibration,
                  weightKg > 0 ? weightKg : 90.7,
                  isFemale: isFemale,
                );
                scenarioStandards = {
                  for (final entry in thresholds.entries)
                    entry.key: {
                      'lifts': {
                        liftKey: _round1(entry.value),
                      },
                    },
                };
              } else {
                scenarioStandards = {};
              }
              displayUnit = 'reps';
              multForScenario = 1.0;
              finalScoreDisplay = widget.finalScore;
              comparisonScoreDisplay = scoreForRankCalcKg;
            } else {
              final standardsDisplay =
                  _packToDisplay(standardsKg, weightMultiplier);
              standardsDisplay.forEach((rank, node) {
                final totalKg =
                    (standardsKg[rank]?['total'] as num?)?.toDouble();
                if (totalKg == null) return;
                final base = totalKg * scenarioMultiplier;
                final thresholdDisplay = _round5(base * weightMultiplier);
                final liftsMap = node['lifts'] as Map<String, double>;
                liftsMap[liftKey] = thresholdDisplay;
              });
              scenarioStandards = standardsDisplay;
              displayUnit = unit;
              multForScenario = weightMultiplier;
              finalScoreDisplay = widget.finalScore * multForScenario;
              comparisonScoreDisplay = scoreForRankCalcKg * multForScenario;
            }

            if (scenarioStandards.isEmpty) {
              final fallback = _packToDisplay(standardsKg, weightMultiplier);
              fallback.forEach((rank, node) {
                final totalKg =
                    (standardsKg[rank]?['total'] as num?)?.toDouble();
                if (totalKg == null) return;
                final base = totalKg * scenarioMultiplier;
                final thresholdDisplay = _round5(base * weightMultiplier);
                final liftsMap = node['lifts'] as Map<String, double>;
                liftsMap[liftKey] = thresholdDisplay;
              });
              scenarioStandards = fallback;
              displayUnit = unit;
              multForScenario = weightMultiplier;
              finalScoreDisplay = widget.finalScore * multForScenario;
              comparisonScoreDisplay = scoreForRankCalcKg * multForScenario;
            }

            if (scenarioStandards.isEmpty) {
              return _wrapWithPopGuard(
                _buildScaffold(
                  Center(
                    child: ErrorDisplay(
                      message: 'No benchmarks available for this scenario yet.',
                      onRetry: () => ref
                          .refresh(scenarioDetailsProvider(widget.scenarioId)),
                    ),
                  ),
                ),
              );
            }

            final lp = computeLiftProgress(
              liftStandards: scenarioStandards,
              liftKey: liftKey,
              score: comparisonScoreDisplay,
            );

            final rankColor = getRankColor(lp.matchedRank);
            final currentRankIndex = kRankOrder.indexWhere(
                (rank) => rank.toLowerCase() == lp.matchedRank.toLowerCase());
            final String? previousRank;
            final String? nextRank;

            if (currentRankIndex == -1) {
              previousRank = null;
              nextRank = kRankOrder.isNotEmpty ? kRankOrder.first : null;
            } else {
              previousRank = currentRankIndex > 0
                  ? kRankOrder[currentRankIndex - 1]
                  : null;
              nextRank = currentRankIndex < kRankOrder.length - 1
                  ? kRankOrder[currentRankIndex + 1]
                  : null;
            }
            final previousRankAssetName = previousRank?.toLowerCase();
            final nextRankAssetName = nextRank?.toLowerCase();

            return _wrapWithPopGuard(
              _buildScaffold(
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'FINAL SCORE',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                      Text(
                        finalScoreDisplay.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scenarioName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Previous Best: ${(widget.previousBest * multForScenario).toStringAsFixed(1)} $displayUnit',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'CURRENT RANK',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (previousRankAssetName != null)
                              _buildAdjacentBadge(
                                previousRankAssetName,
                                Alignment.centerRight,
                              )
                            else if (nextRankAssetName != null)
                              SizedBox(
                                width:
                                    _adjacentBadgeSize + _adjacentBadgeSpacing,
                              ),
                            if (previousRankAssetName != null)
                              const SizedBox(width: _adjacentBadgeSpacing),
                            SvgPicture.asset(
                              'assets/images/ranks/${lp.matchedRank.toLowerCase()}.svg',
                              height: 72,
                            ),
                            if (nextRankAssetName != null)
                              const SizedBox(width: _adjacentBadgeSpacing)
                            else if (previousRankAssetName != null)
                              SizedBox(
                                width:
                                    _adjacentBadgeSize + _adjacentBadgeSpacing,
                              ),
                            if (nextRankAssetName != null)
                              _buildAdjacentBadge(
                                nextRankAssetName,
                                Alignment.centerLeft,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lp.matchedRank,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: rankColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: lp.progress,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                          minHeight: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${comparisonScoreDisplay.toStringAsFixed(1)} / ${lp.nextThreshold.toStringAsFixed(1)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      const Divider(color: Color(0x22FFFFFF)),
                      const SizedBox(height: 16),
                      Consumer(
                        builder: (context, ref, _) {
                          final subTier =
                              ref.watch(subscriptionProvider).valueOrNull;
                          if (subTier == SubscriptionTier.gold ||
                              subTier == SubscriptionTier.platinum) {
                            return ScoreHistoryChart(
                              scenarioId: widget.scenarioId,
                              weightMultiplier: multForScenario,
                            );
                          } else if (!Env.paymentsEnabled) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SizedBox(height: 16),
                                Text(
                                  'Premium performance insights',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Premium charts are temporarily unavailable.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 420),
                                child: SizedBox(
                                  height: 260,
                                  child: ClipRect(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ImageFiltered(
                                          imageFilter: ImageFilter.blur(
                                              sigmaX: 16, sigmaY: 16),
                                          child: Opacity(
                                            opacity: 0.45,
                                            child: ScoreHistoryChart(
                                              scenarioId: widget.scenarioId,
                                              weightMultiplier: multForScenario,
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0B0B0D)
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Premium performance insights',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Upgrade to Gold to unlock full analytics.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 12,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                              ),
                                              onPressed: () async {
                                                final purchaseSuccess =
                                                    await context.push<bool>(
                                                  '/subscribe',
                                                  extra:
                                                      GoRouterState.of(context)
                                                          .uri
                                                          .toString(),
                                                );
                                                if (purchaseSuccess == true &&
                                                    mounted) {
                                                  await ref
                                                      .read(
                                                          authProvider.notifier)
                                                      .refreshUserData();
                                                  ref.invalidate(
                                                      subscriptionProvider);
                                                }
                                              },
                                              child: const Text(
                                                'Upgrade to Gold',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  Builder(
                    builder: (context) => Offstage(
                      offstage: true,
                      child: Screenshot(
                        controller: _screenshotController,
                        child: ShareableResultCard(
                          username: user.username,
                          scenarioName: scenarioName,
                          finalScore:
                              '${finalScoreDisplay.toStringAsFixed(1)} $displayUnit',
                          rankName: lp.matchedRank,
                          rankColor: rankColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isSharing
                        ? const LoadingSpinner(size: 24)
                        : const Icon(Icons.ios_share_outlined),
                    onPressed: _isSharing
                        ? null
                        : () => _handleShare(
                              scenarioName: scenarioName,
                              matchedRank: lp.matchedRank,
                              finalScoreDisplay: finalScoreDisplay,
                              unit: displayUnit,
                              username: user.username,
                              rankColor: rankColor,
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _wrapWithPopGuard(Widget scaffold) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popUpTwo(context);
      },
      child: scaffold,
    );
  }

  Scaffold _buildScaffold(Widget child, {List<Widget> actions = const []}) {
    const backgroundColor = Color(0xFF0B0B0D);
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Results',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_outlined),
          onPressed: () => _popUpTwo(context),
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}
