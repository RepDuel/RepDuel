// frontend/lib/features/ranked/screens/result_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../core/services/share_service.dart';
import '../utils/rank_utils.dart';
import '../../../widgets/paywall_lock.dart';

// --- Data Model for the Score History Graph ---
class ScoreHistoryEntry {
  final double score;
  final DateTime date;
  ScoreHistoryEntry({required this.score, required this.date});
  factory ScoreHistoryEntry.fromJson(Map<String, dynamic> json) => ScoreHistoryEntry(
    score: (json['weight_lifted'] as num).toDouble(),
    date: DateTime.parse(json['created_at'] as String),
  );
}

// --- Provider for the premium score history feature ---
final scoreHistoryProvider = FutureProvider.autoDispose.family<List<ScoreHistoryEntry>, String>((ref, scenarioId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) throw Exception("User not authenticated");
  
  final url = '${Env.baseUrl}/api/v1/scores/user/${user.id}/scenario/$scenarioId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    final entries = data.map((item) => ScoreHistoryEntry.fromJson(item)).toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  } else if (response.statusCode == 403) {
    throw Exception("Upgrade to Gold to see your history.");
  } else {
    throw Exception("Failed to load score history.");
  }
});

// --- UI Widget for the Score History Chart ---
class ScoreHistoryChart extends ConsumerWidget {
  final String scenarioId;
  const ScoreHistoryChart({super.key, required this.scenarioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scoreHistoryProvider(scenarioId));
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(e.toString().replaceFirst("Exception: ", ""), style: const TextStyle(color: Colors.red, fontSize: 14))),
      data: (history) {
        if (history.length < 2) return const Center(child: Text("Log at least two workouts to see a graph.", style: TextStyle(color: Colors.white70)));
        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
              lineBarsData: [
                LineChartBarData(
                  spots: history.map((entry) => FlSpot(entry.date.millisecondsSinceEpoch.toDouble(), entry.score)).toList(),
                  isCurved: true,
                  color: Colors.amber,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.amber.withOpacity(0.3)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- UI Widget for the Shareable Image ---
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
  final int finalScore;
  final int previousBest;
  final String scenarioId;

  const ResultScreen({super.key, required this.finalScore, required this.previousBest, required this.scenarioId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  // This screen-specific method is correct to keep here
  Future<Map<String, dynamic>> getScenarioAndRankProgress({
    required String scenarioId,
    required int scoreToUse,
    required double userWeight,
    required String userGender,
  }) async {
    final scenarioRes = await http.get(Uri.parse('${Env.baseUrl}/api/v1/scenarios/$scenarioId/details'));
    if (scenarioRes.statusCode != 200) throw Exception("Failed to load scenario details.");
    final scenario = json.decode(scenarioRes.body);

    final rankRes = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/ranks/get_rank_progress').replace(queryParameters: {
        'scenario_id': scenarioId,
        'final_score': scoreToUse.toString(),
        'user_weight': userWeight.toString(),
        'user_gender': userGender.toLowerCase(),
      }),
    );
    if (rankRes.statusCode != 200) throw Exception("Failed to load rank progress.");
    final rank = json.decode(rankRes.body);

    return {'scenario': scenario, 'rank': rank};
  }

  // This handler now correctly delegates to the ShareService
  Future<void> _handleShare(Map<String, dynamic> scenarioData, Map<String, dynamic> rankData) async {
    setState(() => _isSharing = true);
    try {
      await ref.read(shareServiceProvider).shareResult(
            context: context,
            screenshotController: _screenshotController,
            scenarioData: scenarioData,
            rankData: rankData,
            finalScore: widget.finalScore,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")))
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userWeight = user?.weight ?? 70.0;
    final userGender = user?.gender ?? 'male';
    final weightMultiplier = user?.weightMultiplier ?? 1.0;
    final scoreToUse = widget.finalScore > widget.previousBest ? widget.finalScore : widget.previousBest;
    
    return FutureBuilder<Map<String, dynamic>>(
      future: getScenarioAndRankProgress(
        scenarioId: widget.scenarioId,
        scoreToUse: scoreToUse,
        userWeight: userWeight,
        userGender: userGender,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildScaffold(const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _buildScaffold(Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white))));
        }

        final scenarioData = snapshot.data!['scenario'];
        final rankData = snapshot.data!['rank'];
        final scenarioName = scenarioData['name'] ?? 'Scenario';
        final currentRank = rankData['current_rank'] ?? 'Unranked';
        final nextThreshold = rankData['next_rank_threshold'];
        final isMax = currentRank == 'Celestial';

        // Use the global rankOrder constant from rank_utils.dart
        final currentIndex = rankOrder.indexOf(currentRank);
        final leftRank = currentIndex > 0 ? rankOrder[currentIndex - 1] : null;
        final rightRank = !isMax && currentIndex < rankOrder.length - 1 ? rankOrder[currentIndex + 1] : null;
        
        final scaledScore = (scoreToUse * weightMultiplier).round();
        final progressValue = isMax ? 1.0 : (nextThreshold != null && nextThreshold > 0) ? (scoreToUse / nextThreshold).clamp(0.0, 1.0) : 0.0;

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
                  Text('${(widget.finalScore * weightMultiplier).round()}', style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Previous Best: ${(widget.previousBest * weightMultiplier).round()}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 24),
                  Text(scenarioName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
                  const SizedBox(height: 32),
                  const Text('CURRENT RANK', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (leftRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${leftRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                    const SizedBox(width: 12),
                    SvgPicture.asset('assets/images/ranks/${currentRank.toLowerCase()}.svg', height: 72),
                    const SizedBox(width: 12),
                    if (rightRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${rightRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                  ]),
                  const SizedBox(height: 12),
                  Text(currentRank, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  // Use the global getRankColor function from rank_utils.dart
                  Container(width: 200, height: 20, color: Colors.grey[800], child: LinearProgressIndicator(value: progressValue, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(getRankColor(currentRank)), minHeight: 24)),
                  const SizedBox(height: 12),
                  Text(isMax ? 'MAX RANK' : nextThreshold != null ? '$scaledScore / ${(nextThreshold * weightMultiplier).round()}' : '$scaledScore', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text("SCORE PROGRESSION", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final subscriptionState = ref.watch(subscriptionProvider);
                      return subscriptionState.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (e, s) => Text("Error checking subscription", style: const TextStyle(color: Colors.red)),
                        data: (tier) {
                          if (tier == SubscriptionTier.gold || tier == SubscriptionTier.platinum) {
                            return ScoreHistoryChart(scenarioId: widget.scenarioId);
                          } else {
                            return PaywallLock(
                              message: "Upgrade to Gold to track your progress over time.",
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upgrade to see your progress!")));
                              },
                            );
                          }
                        },
                      );
                    }
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                    child: const Text('Back to Menu'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: _isSharing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.share),
              onPressed: _isSharing ? null : () => _handleShare(scenarioData, rankData),
            ),
          ]
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
        foregroundColor: Colors.white,
        elevation: 0,
        actions: actions,
      ),
      body: child,
    );
  }
}