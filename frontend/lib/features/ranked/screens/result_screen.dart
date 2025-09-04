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
import '../models/result_screen_data.dart';
import '../utils/rank_utils.dart';
import '../widgets/score_history_chart.dart';

class ShareableResultCard extends StatelessWidget {
  final String username;
  final String scenarioName;
  final String finalScore;
  final String rankName;
  final Color rankColor;
  const ShareableResultCard(
      {super.key,
      required this.username,
      required this.scenarioName,
      required this.finalScore,
      required this.rankName,
      required this.rankColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(username,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('achieved a new score in',
              style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 4),
          Text(scenarioName.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1)),
          const SizedBox(height: 20),
          SvgPicture.asset('assets/images/ranks/${rankName.toLowerCase()}.svg',
              height: 80),
          const SizedBox(height: 12),
          Text(rankName,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('Score: $finalScore',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text('RepDuel',
              style: TextStyle(
                  color: Colors.blue.shade300,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

final resultScreenDataProvider = FutureProvider.autoDispose
    .family<ResultScreenData, ({String scenarioId, double finalScore})>(
        (ref, params) async {
  final user = ref.watch(authProvider).valueOrNull?.user;
  if (user == null) throw Exception("User not authenticated.");
  final client = ref.watch(privateHttpClientProvider);
  final rankProgressUri =
      Uri.parse('${client.dio.options.baseUrl}/ranks/get_rank_progress')
          .replace(queryParameters: {
    'scenario_id': params.scenarioId,
    'final_score': params.finalScore.toString(),
    'user_weight': (user.weight ?? 70.0).toString(),
    'user_gender': (user.gender ?? 'male').toLowerCase(),
  });
  final responses = await Future.wait([
    client.get('/scenarios/${params.scenarioId}/details'),
    client.get(rankProgressUri.toString()),
  ]);
  return ResultScreenData(scenario: responses[0].data, rank: responses[1].data);
});

class ResultScreen extends ConsumerStatefulWidget {
  final double finalScore;
  final int previousBest;
  final String scenarioId;
  const ResultScreen(
      {super.key,
      required this.finalScore,
      required this.previousBest,
      required this.scenarioId});
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<void> _handleShare(
      ResultScreenData data, String username, double weightMultiplier) async {
    setState(() => _isSharing = true);
    try {
      await ref.read(shareServiceProvider).shareResult(
            context: context,
            screenshotController: _screenshotController,
            username: username,
            scenarioName: data.scenario['name'] as String? ?? 'Unnamed',
            finalScore:
                (widget.finalScore * weightMultiplier).toStringAsFixed(1),
            rankName: data.rank['current_rank'] as String? ?? 'Unranked',
            rankColor: getRankColor(
                data.rank['current_rank'] as String? ?? 'Unranked'),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", ""))));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).valueOrNull;
    if (authState?.user == null) {
      return _buildScaffold(
          const Center(child: Text("User not authenticated.")));
    }
    final user = authState!.user!;
    final weightMultiplier = user.weightMultiplier;

    // This is the user's true personal best after this session.
    final scoreForRankCalc = widget.finalScore > widget.previousBest
        ? widget.finalScore
        : widget.previousBest.toDouble();

    final resultProvider = resultScreenDataProvider(
        (scenarioId: widget.scenarioId, finalScore: scoreForRankCalc));
    final screenDataAsync = ref.watch(resultProvider);

    return screenDataAsync.when(
      loading: () => _buildScaffold(const Center(child: LoadingSpinner())),
      error: (err, _) => _buildScaffold(Center(
          child: ErrorDisplay(
              message: err.toString(),
              onRetry: () => ref.refresh(resultProvider)))),
      data: (data) {
        final scenarioName = data.scenario['name'] ?? 'Scenario';
        final currentRank = data.rank['current_rank'] ?? 'Unranked';
        final nextThreshold = data.rank['next_rank_threshold'];
        final isMax = currentRank == 'Celestial';

        // --- THIS IS THE FIX ---
        // Use the correct personal best for progress calculation.
        final progressValue = isMax
            ? 1.0
            : (nextThreshold != null && nextThreshold > 0)
                ? (scoreForRankCalc / nextThreshold).clamp(0.0, 1.0)
                : 0.0;
        // --- END OF FIX ---

        return _buildScaffold(
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text('FINAL SCORE',
                      style: TextStyle(color: Colors.white70, fontSize: 20)),
                  Text(
                      (widget.finalScore * weightMultiplier).toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.bold)),
                  Text(
                      'Previous Best: ${(widget.previousBest * weightMultiplier).toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  Text('CURRENT RANK',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 18)),
                  const SizedBox(height: 16),
                  SvgPicture.asset(
                      'assets/images/ranks/${currentRank.toLowerCase()}.svg',
                      height: 72),
                  const SizedBox(height: 12),
                  Text(currentRank,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: getRankColor(currentRank))),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                          value: progressValue,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              getRankColor(currentRank)),
                          minHeight: 20)),
                  const SizedBox(height: 8),
                  Text(
                      // --- THIS IS THE FIX ---
                      // Also use the personal best for the text label.
                      isMax
                          ? 'MAX RANK'
                          : nextThreshold != null && nextThreshold > 0
                              ? '${(scoreForRankCalc * weightMultiplier).toStringAsFixed(1)} / ${(nextThreshold * weightMultiplier).toStringAsFixed(1)}'
                              : (scoreForRankCalc * weightMultiplier)
                                  .toStringAsFixed(1),
                      // --- END OF FIX ---
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  Consumer(builder: (context, ref, _) {
                    final subTier = ref.watch(subscriptionProvider).valueOrNull;
                    return (subTier == SubscriptionTier.gold ||
                            subTier == SubscriptionTier.platinum)
                        ? ScoreHistoryChart(
                            scenarioId: widget.scenarioId,
                            weightMultiplier: weightMultiplier)
                        : PaywallLock(
                            message: "Upgrade to Gold to track your progress.",
                            onTap: () => context.push('/subscribe'));
                  }),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () =>
                        context.pop(true), // Return true to signal a refresh
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14)),
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
                              finalScore: (widget.finalScore * weightMultiplier)
                                  .toStringAsFixed(1),
                              rankName: currentRank,
                              rankColor: getRankColor(currentRank))))),
              IconButton(
                  icon: _isSharing
                      ? const LoadingSpinner(size: 24)
                      : const Icon(Icons.share),
                  onPressed: _isSharing
                      ? null
                      : () =>
                          _handleShare(data, user.username, weightMultiplier))
            ]);
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
          actions: actions),
      body: child,
    );
  }
}
