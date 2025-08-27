// frontend/lib/features/ranked/screens/result_screen.dart

import 'dart:async'; // Needed for TimeoutException
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Make sure flutter_svg is imported
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Not used, can be removed if not needed elsewhere
import 'package:screenshot/screenshot.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../../core/providers/iap_provider.dart';  // Import IAP provider
import '../../../core/services/share_service.dart';
import '../../../widgets/paywall_lock.dart';
import '../utils/rank_utils.dart';
import '../widgets/score_history_chart.dart';
import '../providers/score_history_provider.dart';
import '../models/score_history_entry.dart';

// --- ShareableResultCard ---
// This widget is fine as it takes its data as parameters.
class ShareableResultCard extends StatelessWidget {
  final String username;
  final String scenarioName;
  final int finalScore;
  final String rankName;
  final Color rankColor;

  const ShareableResultCard({super.key, required this.username, required this.scenarioName, required this.finalScore, required this.rankName, required this.rankColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(username, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('achieved a new score in', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 4),
          Text(scenarioName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
          const SizedBox(height: 20),
          SvgPicture.asset('assets/images/ranks/${rankName.toLowerCase()}.svg', height: 80),
          const SizedBox(height: 12),
          Text(rankName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: rankColor, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text('Score: $finalScore', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text('RepDuel', style: TextStyle(color: Colors.blue.shade300, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- Main Screen ---
class ResultScreen extends ConsumerStatefulWidget {
  final double finalScore;
  final int previousBest;
  final String scenarioId;

  const ResultScreen({super.key, required this.finalScore, required this.previousBest, required this.scenarioId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  // This function fetches scenario details and rank progress.
  // It needs the token from authProvider.
  Future<Map<String, dynamic>> getScenarioAndRankProgress({
    required String scenarioId,
    required double scoreToUse,
    required double userWeight,
    required String userGender,
    required String token, // Pass token directly
  }) async {
    // Headers are now passed directly, no need to read authProvider here.
    final headers = {'Authorization': 'Bearer $token'};

    final scenarioUrl = Uri.parse('${Env.baseUrl}/api/v1/scenarios/$scenarioId/details');
    final scenarioRes = await http.get(scenarioUrl, headers: headers);
    
    if (scenarioRes.statusCode != 200) {
      throw Exception("Failed to load scenario details. Status: ${scenarioRes.statusCode}, Body: ${scenarioRes.body}");
    }
    final scenario = json.decode(scenarioRes.body);

    final rankUrl = Uri.parse('${Env.baseUrl}/api/v1/ranks/get_rank_progress').replace(queryParameters: {
      'scenario_id': scenarioId,
      'final_score': scoreToUse.toString(),
      'user_weight': userWeight.toString(),
      'user_gender': userGender.toLowerCase(),
    });

    final rankRes = await http.get(rankUrl, headers: headers);
    
    if (rankRes.statusCode != 200) {
      throw Exception("Failed to load rank progress. Status: ${rankRes.statusCode}, Body: ${rankRes.body}");
    }
    final rank = json.decode(rankRes.body);

    return {'scenario': scenario, 'rank': rank};
  }

  Future<void> _handleShare({
    required Map<String, dynamic> scenarioData, 
    required Map<String, dynamic> rankData,
    required double finalScore,
    required double weightMultiplier,
    required BuildContext context, // Pass context for SnackBar
    required WidgetRef ref,
  }) async {
    setState(() => _isSharing = true);
    try {
      await ref.read(shareServiceProvider).shareResult(
            context: context, // Use context from build method
            screenshotController: _screenshotController,
            scenarioData: scenarioData,
            rankData: rankData,
            finalScore: (finalScore * weightMultiplier).round(), // Apply multiplier
          );
    } catch (e) {
      // Check mounted status before showing SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")))
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the authProvider to get AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => _buildScaffold(const Center(child: CircularProgressIndicator())), // Loading auth state
      error: (err, stack) => _buildScaffold(Center(child: Text('Auth Error: $err', style: const TextStyle(color: Colors.red)))), // Error in auth state
      data: (authState) { // authState is the actual AuthState object
        final user = authState.user;
        final token = authState.token;

        // If user or token is null, it means the user is not authenticated.
        // The router should handle redirecting to login. We'll show a message here.
        if (user == null || token == null) {
          return _buildScaffold(
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to view results.', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.push('/login'), // Use GoRouter for navigation
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // --- User is logged in and token is available ---
        final bodyweightKg = user.weight ?? 70.0;
        final userGender = user.gender ?? 'male';
        final weightMultiplier = user.weightMultiplier ?? 1.0;
        // Use widget.finalScore for calculation, unless previousBest is higher
        final scoreToUseForDisplay = widget.finalScore > widget.previousBest ? widget.finalScore : widget.previousBest.toDouble();
        final displayFinalScore = (widget.finalScore * weightMultiplier).toStringAsFixed(1);
        final displayPreviousBest = (widget.previousBest * weightMultiplier).toStringAsFixed(1);

        // Fetch scenario and rank data using the user's token.
        final scenarioAndRankFuture = getScenarioAndRankProgress(
          scenarioId: widget.scenarioId,
          scoreToUse: scoreToUseForDisplay, // Use the score that determines rank
          userWeight: bodyweightKg,
          userGender: userGender,
          token: token, // Pass the token directly
        );

        return FutureBuilder<Map<String, dynamic>>(
          future: scenarioAndRankFuture,
          builder: (context, snapshot) {
            // Handle loading state for scenario/rank data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildScaffold(const Center(child: CircularProgressIndicator()));
            }
            // Handle errors for scenario/rank data
            if (snapshot.hasError) {
              return _buildScaffold(
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading data: ${snapshot.error}', 
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Retry mechanism
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // --- Data loaded successfully ---
            // If snapshot.data is null or doesn't contain expected keys, handle gracefully.
            final Map<String, dynamic>? data = snapshot.data;
            if (data == null || data['scenario'] == null || data['rank'] == null) {
               return _buildScaffold(
                const Center(child: Text('Failed to fetch complete data.', style: TextStyle(color: Colors.red)))
              );
            }

            final scenarioData = data['scenario'] as Map<String, dynamic>;
            final rankData = data['rank'] as Map<String, dynamic>;

            final scenarioName = scenarioData['name'] ?? 'Scenario';
            final currentRank = rankData['current_rank'] ?? 'Unranked';
            final nextThreshold = rankData['next_rank_threshold'];
            final isMax = currentRank == 'Celestial';

            // Rank progression logic
            final currentIndex = rankOrder.indexOf(currentRank);
            final leftRank = currentIndex > 0 ? rankOrder[currentIndex - 1] : null;
            final rightRank = !isMax && currentIndex < rankOrder.length - 1 ? rankOrder[currentIndex + 1] : null;
            
            // Calculate progress value for the rank bar
            final progressValue = isMax ? 1.0 : (nextThreshold != null && nextThreshold > 0) 
                                  ? (scoreToUse / nextThreshold).clamp(0.0, 1.0) 
                                  : 0.0;

            return _buildScaffold(
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      const Text('FINAL SCORE', style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      // Display the score using the correct multiplier
                      Text(displayFinalScore, style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Display previous best using the correct multiplier
                      Text('Previous Best: $displayPreviousBest', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 24),
                      Text(scenarioName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
                      const SizedBox(height: 32),
                      const Text('CURRENT RANK', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        // Render rank images with opacity for context
                        if (leftRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${leftRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                        const SizedBox(width: 12),
                        SvgPicture.asset('assets/images/ranks/${currentRank.toLowerCase()}.svg', height: 72),
                        const SizedBox(width: 12),
                        if (rightRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${rightRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                      ]),
                      const SizedBox(height: 12),
                      Text(currentRank, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getRankColor(currentRank), letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      // Rank progress bar
                      Container(width: 200, height: 20, color: Colors.grey[800], child: LinearProgressIndicator(value: progressValue, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(getRankColor(currentRank)), minHeight: 24)),
                      const SizedBox(height: 12),
                      // Display score needed for next rank or current score
                      Text(isMax ? 'MAX RANK' : nextThreshold != null && nextThreshold > 0 ? '${(scoreToUse * weightMultiplier).toStringAsFixed(1)} / ${(nextThreshold * weightMultiplier).toStringAsFixed(1)}' : (scoreToUse * weightMultiplier).toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 16)),
                      
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text("SCORE PROGRESSION", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      
                      // --- Score History Chart (Subscription Check) ---
                      Consumer(
                        builder: (context, ref, child) {
                          final subscriptionState = ref.watch(subscriptionProvider);
                          return subscriptionState.when(
                            loading: () => const CircularProgressIndicator(), // Show loading while checking subscription
                            error: (e, s) => Text("Error checking subscription: $e", style: const TextStyle(color: Colors.red)), // Display error if subscription check fails
                            data: (tier) {
                              // Check if the user has a Gold or Platinum subscription tier
                              if (tier == SubscriptionTier.gold || tier == SubscriptionTier.platinum) {
                                return ScoreHistoryChart(
                                  scenarioId: widget.scenarioId,
                                  weightMultiplier: weightMultiplier, // Pass multiplier for chart data
                                );
                              } else {
                                // If not subscribed, show the PaywallLock widget
                                return PaywallLock(
                                  message: "Upgrade to Gold to track your progress over time.",
                                  onTap: () {
                                    GoRouter.of(context).push('/subscribe'); // Navigate to subscription screen
                                  },
                                );
                              }
                            },
                          );
                        }
                      ),

                      const SizedBox(height: 32),
                      // Back to Menu button
                      ElevatedButton(
                        onPressed: () {
                          // Use GoRouter for navigation
                          GoRouter.of(context).pop(); 
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                        child: const Text('Back to Menu'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Share button in the AppBar
              actions: [
                IconButton(
                  icon: _isSharing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share),
                  onPressed: _isSharing ? null : () => _handleShare(
                    scenarioData: scenarioData, 
                    rankData: rankData, 
                    finalScore: widget.finalScore, 
                    weightMultiplier: weightMultiplier,
                    context: context, // Pass context for snackbar
                    ref: ref, // Pass ref for shareServiceProvider
                  ),
                ),
              ]
            );
          },
        );
      },
    );
  }

  // Helper to build the Scaffold with consistent AppBar and background
  Scaffold _buildScaffold(Widget child, {List<Widget> actions = const []}) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: actions, // Pass share button actions here
      ),
      body: child,
    );
  }
}