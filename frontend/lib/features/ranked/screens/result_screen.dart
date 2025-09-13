// frontend/lib/features/ranked/screens/result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:screenshot/screenshot.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../core/services/share_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../widgets/paywall_lock.dart';
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

/// Map scenarioId -> lift key used by standards pack
String _liftKeyForScenario(String scenarioId) {
  switch (scenarioId) {
    case 'back_squat':
      return 'squat';
    case 'barbell_bench_press':
      return 'bench';
    case 'deadlift':
      return 'deadlift';
    default:
      return 'squat';
  }
}

/// Fetch scenario details (name, etc.)
final scenarioDetailsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, scenarioId) async {
  final client = ref.watch(privateHttpClientProvider);
  final res = await client.get('/scenarios/$scenarioId/details');
  return (res.data as Map).cast<String, dynamic>();
});

/// Fetch the same standards pack used by the Rankings screen (kg-based, then we
/// multiply by the user's weightMultiplier to display in their unit).
final standardsPackProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authProvider.select((s) => s.valueOrNull?.user));
  if (user == null) throw Exception("User not authenticated.");
  final bodyweightKg = user.weight ?? 90.7; // stored in kg
  final gender = (user.gender ?? 'male').toLowerCase();
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
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String _unitFromMultiplier(double m) {
    return (m - 2.20462).abs() < 0.01 ? 'lbs' : 'kg';
  }

  double _round5(double v) => (v / 5).round() * 5.0;

  Future<void> _handleShare(
    String scenarioName,
    String currentRank,
    double finalScoreDisplay,
    String unit,
  ) async {
    setState(() => _isSharing = true);
    try {
      await ref.read(shareServiceProvider).shareResult(
            context: context,
            screenshotController: _screenshotController,
            username: ref.read(authProvider).valueOrNull!.user!.username,
            scenarioName: scenarioName,
            finalScore: '${finalScoreDisplay.toStringAsFixed(1)} $unit',
            rankName: currentRank,
            rankColor: getRankColor(currentRank),
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).valueOrNull;
    final user = auth?.user;
    if (user == null) {
      return _buildScaffold(
        const Center(child: Text("User not authenticated.")),
      );
    }

    final weightMultiplier = user.weightMultiplier;
    final unit = _unitFromMultiplier(weightMultiplier);

    // Use the larger of (finalScore, previousBest) for progress, like before.
    final scoreForRankCalc = widget.finalScore > widget.previousBest
        ? widget.finalScore
        : widget.previousBest.toDouble();

    final scenarioAsync = ref.watch(scenarioDetailsProvider(widget.scenarioId));
    final standardsAsync = ref.watch(standardsPackProvider);

    return standardsAsync.when(
      loading: () => _buildScaffold(const Center(child: LoadingSpinner())),
      error: (err, _) => _buildScaffold(
        Center(
            child: ErrorDisplay(
                message: err.toString(),
                onRetry: () => ref.refresh(standardsPackProvider))),
      ),
      data: (standards) {
        return scenarioAsync.when(
          loading: () => _buildScaffold(const Center(child: LoadingSpinner())),
          error: (err, _) => _buildScaffold(
            Center(
              child: ErrorDisplay(
                message: err.toString(),
                onRetry: () =>
                    ref.refresh(scenarioDetailsProvider(widget.scenarioId)),
              ),
            ),
          ),
          data: (scenario) {
            final scenarioName = (scenario['name'] as String?) ?? 'Scenario';
            final liftKey = _liftKeyForScenario(widget.scenarioId);
            final entries = standards.entries.toList()
              ..sort((a, b) {
                final av = (a.value['lifts'][liftKey] ?? 0) as num;
                final bv = (b.value['lifts'][liftKey] ?? 0) as num;
                return (av.compareTo(bv)) * -1; // descending
              });

            // Compute score and thresholds in the user's unit pack (by multiplying).
            final scoreDisplay = widget.finalScore * weightMultiplier;
            final comparisonScore = scoreForRankCalc * weightMultiplier;

            String matchedRank = 'Unranked';
            double currentThreshold = 0.0;
            double nextThreshold = 0.0;

            for (final e in entries) {
              final raw = (e.value['lifts'][liftKey] ?? 0) as num;
              final adjusted = _round5(raw.toDouble() * weightMultiplier);
              if (comparisonScore >= adjusted) {
                matchedRank = e.key;
                currentThreshold = adjusted;
                break;
              }
            }

            final isMax =
                entries.isNotEmpty && matchedRank == entries.first.key;

            if (isMax) {
              // At max rank: next threshold is the same as current (parity with RankingTable)
              nextThreshold = currentThreshold;
            } else if (matchedRank != 'Unranked') {
              final idx = entries.indexWhere((e) => e.key == matchedRank);
              if (idx > 0) {
                final rawNext =
                    (entries[idx - 1].value['lifts'][liftKey] ?? 0) as num;
                nextThreshold = _round5(rawNext.toDouble() * weightMultiplier);
              }
            } else {
              // Unranked -> show Iron as the first target
              if (entries.isNotEmpty) {
                final rawIron =
                    (entries.last.value['lifts'][liftKey] ?? 0) as num;
                nextThreshold = _round5(rawIron.toDouble() * weightMultiplier);
              }
            }

            // Progress calculation identical to RankingTable
            double progressValue = 0.0;
            if (isMax) {
              progressValue = 1.0;
            } else if (nextThreshold > currentThreshold) {
              progressValue = ((comparisonScore - currentThreshold) /
                      (nextThreshold - currentThreshold))
                  .clamp(0.0, 1.0);
            } else if (nextThreshold > 0) {
              progressValue = (comparisonScore / nextThreshold).clamp(0.0, 1.0);
            }

            final rankColor = getRankColor(matchedRank);

            return _buildScaffold(
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
                      scoreDisplay.toStringAsFixed(1),
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
                      'Previous Best: ${(widget.previousBest * weightMultiplier).toStringAsFixed(1)} $unit',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'CURRENT RANK',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    SvgPicture.asset(
                      'assets/images/ranks/${matchedRank.toLowerCase()}.svg',
                      height: 72,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      matchedRank,
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
                        value: progressValue,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(rankColor),
                        minHeight: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Display "<user>/<threshold>" using the same pack logic as RankingTable
                    Text(
                      '${comparisonScore.toStringAsFixed(1)} / ${nextThreshold.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, _) {
                        final subTier =
                            ref.watch(subscriptionProvider).valueOrNull;
                        if (subTier == SubscriptionTier.gold ||
                            subTier == SubscriptionTier.platinum) {
                          return ScoreHistoryChart(
                            scenarioId: widget.scenarioId,
                            weightMultiplier: weightMultiplier,
                          );
                        } else {
                          return PaywallLock(
                            message: "Upgrade to Gold to track your progress.",
                            onTap: () async {
                              final purchaseSuccess =
                                  await context.push<bool>('/subscribe');
                              if (purchaseSuccess == true && mounted) {
                                await ref
                                    .read(authProvider.notifier)
                                    .refreshUserData();
                                ref.invalidate(subscriptionProvider);
                              }
                            },
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Back to Menu'),
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
                        finalScore: '${scoreDisplay.toStringAsFixed(1)} $unit',
                        rankName: matchedRank,
                        rankColor: rankColor,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSharing
                      ? const LoadingSpinner(size: 24)
                      : const Icon(Icons.share),
                  onPressed: _isSharing
                      ? null
                      : () => _handleShare(
                            scenarioName,
                            matchedRank,
                            scoreDisplay,
                            unit,
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Scaffold _buildScaffold(Widget child, {List<Widget> actions = const []}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: actions,
      ),
      body: child,
    );
  }
}
