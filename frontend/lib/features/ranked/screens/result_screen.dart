// frontend/lib/features/ranked/screens/result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';

// --- Step 1: Create Data Models for Type-Safety ---

class RankProgressData {
  final String scenarioName;
  final String currentRank;
  final num? nextRankThreshold;
  RankProgressData({required this.scenarioName, required this.currentRank, this.nextRankThreshold});
}

class ScoreHistoryEntry {
  final double score;
  final DateTime date;
  ScoreHistoryEntry({required this.score, required this.date});
  factory ScoreHistoryEntry.fromJson(Map<String, dynamic> json) => ScoreHistoryEntry(
    score: (json['weight_lifted'] as num).toDouble(),
    date: DateTime.parse(json['created_at'] as String),
  );
}

// --- Step 2: Create Providers to Encapsulate Logic ---

final rankProgressProvider = FutureProvider.autoDispose.family<RankProgressData, String>((ref, scenarioId) async {
  final user = ref.watch(authProvider).user;
  if (user == null || user.weight == null || user.gender == null) {
    throw Exception("User profile is incomplete.");
  }
  
  final scoreToUse = ref.watch(currentScoreProvider);

  final scenarioRes = await http.get(Uri.parse('${Env.baseUrl}/api/v1/scenarios/$scenarioId/details'));
  if (scenarioRes.statusCode != 200) throw Exception("Failed to load scenario details.");
  final scenario = json.decode(scenarioRes.body);

  final rankRes = await http.get(
    Uri.parse('${Env.baseUrl}/api/v1/ranks/get_rank_progress').replace(queryParameters: {
      'scenario_id': scenarioId,
      'final_score': scoreToUse.toString(),
      'user_weight': user.weight!.toString(),
      'user_gender': user.gender!.toLowerCase(),
    }),
  );
  if (rankRes.statusCode != 200) throw Exception("Failed to load rank progress.");
  final rank = json.decode(rankRes.body);

  return RankProgressData(
    scenarioName: scenario['name'] ?? 'Scenario',
    currentRank: rank['current_rank'] ?? 'Unranked',
    nextRankThreshold: rank['next_rank_threshold'],
  );
}, dependencies: [currentScoreProvider]); // THE FIX IS HERE

final scoreHistoryProvider = FutureProvider.autoDispose.family<List<ScoreHistoryEntry>, String>((ref, scenarioId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) throw Exception("User not authenticated");

  final url = '${Env.baseUrl}/api/v1/scores/user/${user.id}/scenario/$scenarioId/history';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    return data.map((item) => ScoreHistoryEntry.fromJson(item)).toList();
  } else if (response.statusCode == 403) {
    throw Exception("Upgrade to Gold to see your history.");
  } else {
    throw Exception("Failed to load score history.");
  }
});

final currentScoreProvider = Provider<int>((ref) => throw UnimplementedError());

// --- Step 3: Create Reusable UI Components ---

class ScoreHistoryChart extends ConsumerWidget {
  final String scenarioId;
  const ScoreHistoryChart({super.key, required this.scenarioId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scoreHistoryProvider(scenarioId));
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("$e", style: const TextStyle(color: Colors.red, fontSize: 14))),
      data: (history) {
        if (history.length < 2) {
          return const Center(child: Text("Log at least two workouts to see a graph.", style: TextStyle(color: Colors.white70)));
        }
        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.white24)),
              lineBarsData: [
                LineChartBarData(
                  spots: history.reversed.map((entry) => FlSpot(
                    entry.date.millisecondsSinceEpoch.toDouble(),
                    entry.score,
                  )).toList(),
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

// --- Step 4: The Complete, Refactored Main Screen ---

class ResultScreen extends ConsumerWidget {
  final int finalScore;
  final int previousBest;
  final String scenarioId;

  const ResultScreen({
    super.key,
    required this.finalScore,
    required this.previousBest,
    required this.scenarioId,
  });

  static const List<String> rankOrder = ["Unranked", "Iron", "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Jade", "Master", "Grandmaster", "Nova", "Astra", "Celestial"];

  static Color getRankColor(String rank) {
    switch (rank) {
      case 'Iron': return Colors.grey;
      case 'Bronze': return const Color(0xFFcd7f32);
      case 'Silver': return const Color(0xFFc0c0c0);
      case 'Gold': return const Color(0xFFefbf04);
      case 'Platinum': return const Color(0xFF00ced1);
      case 'Diamond': return const Color(0xFFb9f2ff);
      case 'Jade': return const Color(0xFF62f40c);
      case 'Master': return const Color(0xFFff00ff);
      case 'Grandmaster': return const Color(0xFFffde21);
      case 'Nova': return const Color(0xFFa45ee5);
      case 'Astra': return const Color(0xFFff4040);
      case 'Celestial': return const Color(0xFF00ffff);
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreToUse = finalScore > previousBest ? finalScore : previousBest;
    final user = ref.watch(authProvider).user;
    final weightMultiplier = user?.weightMultiplier ?? 1.0;
    
    final rankProgressAsync = ref.watch(rankProgressProvider(scenarioId));
    final subscriptionState = ref.watch(subscriptionProvider);

    return ProviderScope(
      overrides: [currentScoreProvider.overrideWithValue(scoreToUse)],
      child: _buildScaffold(
        rankProgressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
          data: (rankData) {
            final isMax = rankData.currentRank == 'Celestial';
            final progressValue = isMax ? 1.0 : (rankData.nextRankThreshold != null && rankData.nextRankThreshold! > 0) ? (scoreToUse / rankData.nextRankThreshold!).clamp(0.0, 1.0) : 0.0;
            final currentIndex = rankOrder.indexOf(rankData.currentRank);
            final leftRank = currentIndex > 0 ? rankOrder[currentIndex - 1] : null;
            final rightRank = !isMax && currentIndex < rankOrder.length - 1 ? rankOrder[currentIndex + 1] : null;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const Text('FINAL SCORE', style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('${(finalScore * weightMultiplier).round()}', style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Previous Best: ${(previousBest * weightMultiplier).round()}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 24),
                    Text(rankData.scenarioName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
                    const SizedBox(height: 32),
                    const Text('CURRENT RANK', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (leftRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${leftRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                      const SizedBox(width: 12),
                      SvgPicture.asset('assets/images/ranks/${rankData.currentRank.toLowerCase()}.svg', height: 72),
                      const SizedBox(width: 12),
                      if (rightRank != null) Opacity(opacity: 0.3, child: SvgPicture.asset('assets/images/ranks/${rightRank.toLowerCase()}.svg', height: 56)) else const SizedBox(width: 56),
                    ]),
                    const SizedBox(height: 12),
                    Text(rankData.currentRank, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Container(width: 200, height: 20, color: Colors.grey[800], child: LinearProgressIndicator(value: progressValue, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation<Color>(getRankColor(rankData.currentRank)), minHeight: 24)),
                    const SizedBox(height: 12),
                    Text(isMax ? 'MAX RANK' : rankData.nextRankThreshold != null ? '${(scoreToUse * weightMultiplier).round()} / ${(rankData.nextRankThreshold! * weightMultiplier).round()}' : '${(scoreToUse * weightMultiplier).round()}', style: const TextStyle(color: Colors.white, fontSize: 16)),

                    const SizedBox(height: 32),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text("SCORE PROGRESSION", style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    subscriptionState.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text("Error checking subscription", style: const TextStyle(color: Colors.red)),
                      data: (tier) {
                        if (tier == SubscriptionTier.gold || tier == SubscriptionTier.platinum) {
                          return ScoreHistoryChart(scenarioId: scenarioId);
                        } else {
                          return GestureDetector(
                            onTap: () {
                              // TODO: Navigate to your paywall screen using go_router.
                              // Example: context.go('/go-premium');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Upgrade to see your progress!")),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                              child: const Column(children: [
                                Icon(Icons.lock_outline, color: Colors.amber, size: 40),
                                SizedBox(height: 12),
                                Text("Upgrade to Gold to track your progress over time.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                              ]),
                            ),
                          );
                        }
                      },
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
            );
          },
        ),
      ),
    );
  }

  Scaffold _buildScaffold(Widget child) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: child,
    );
  }
}