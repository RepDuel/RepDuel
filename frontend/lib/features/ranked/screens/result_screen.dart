import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/config/env.dart';
import 'dart:convert';

import '../../../core/providers/auth_provider.dart';
import 'package:logger/logger.dart';

final logger = Logger();

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

  static const List<String> rankOrder = [
    "Unranked",
    "Iron",
    "Bronze",
    "Silver",
    "Gold",
    "Platinum",
    "Diamond",
    "Jade",
    "Master",
    "Grandmaster",
    "Nova",
    "Astra",
    "Celestial"
  ];

  static Color getRankColor(String rank) {
    switch (rank) {
      case 'Iron':
        return Colors.grey;
      case 'Bronze':
        return const Color(0xFFcd7f32);
      case 'Silver':
        return const Color(0xFFc0c0c0);
      case 'Gold':
        return const Color(0xFFefbf04);
      case 'Platinum':
        return const Color(0xFF00ced1);
      case 'Diamond':
        return const Color(0xFFb9f2ff);
      case 'Jade':
        return const Color(0xFF62f40c);
      case 'Master':
        return const Color(0xFFff00ff);
      case 'Grandmaster':
        return const Color(0xFFffde21);
      case 'Nova':
        return const Color(0xFFa45ee5);
      case 'Astra':
        return const Color(0xFFff4040);
      case 'Celestial':
        return const Color(0xFF00ffff);
      default:
        return Colors.white;
    }
  }

  Future<Map<String, dynamic>> getScenarioAndRankProgress({
    required String scenarioId,
    required int scoreToUse,
    required double userWeight,
    required String userGender,
  }) async {
    final scenarioRes = await http.get(Uri.parse(
        '${Env.baseUrl}/api/v1/scenarios/$scenarioId/details'));

    if (scenarioRes.statusCode != 200) {
      throw Exception("Failed to load scenario");
    }

    final scenario = json.decode(scenarioRes.body);

    final rankRes = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/ranks/get_rank_progress')
          .replace(queryParameters: {
        'scenario_id': scenarioId,
        'final_score': scoreToUse.toString(),
        'user_weight': userWeight.toString(),
        'user_gender': userGender.toLowerCase(),
      }),
    );

    if (rankRes.statusCode != 200) {
      throw Exception("Failed to load rank progress");
    }

    final rank = json.decode(rankRes.body);

    return {
      'scenario': scenario,
      'rank': rank,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).user;
    final userWeight = user?.weight ?? 70.0;
    final userGender = user?.gender ?? 'male';
    final weightMultiplier = user?.weightMultiplier ?? 1.0;

    final scoreToUse = finalScore > previousBest ? finalScore : previousBest;

    return FutureBuilder<Map<String, dynamic>>(
      future: getScenarioAndRankProgress(
        scenarioId: scenarioId,
        scoreToUse: scoreToUse,
        userWeight: userWeight,
        userGender: userGender,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildScaffold(
              const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _buildScaffold(Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white)),
          ));
        }

        final scenario = snapshot.data!['scenario'];
        final rank = snapshot.data!['rank'];
        final scenarioName = scenario['name'] ?? 'Scenario';

        final currentRank = rank['current_rank'] ?? 'Unranked';
        final nextThreshold = rank['next_rank_threshold'];
        final isMax = currentRank == 'Celestial';

        final currentIndex = rankOrder.indexOf(currentRank);
        final leftRank = currentIndex > 0 ? rankOrder[currentIndex - 1] : null;
        final rightRank = !isMax && currentIndex < rankOrder.length - 1
            ? rankOrder[currentIndex + 1]
            : null;

        final scaledScore = (scoreToUse * weightMultiplier).round();

        final progressValue = isMax
            ? 1.0
            : (nextThreshold != null && nextThreshold > 0)
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
                  const Text(
                    'FINAL SCORE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(finalScore * weightMultiplier).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Previous Best: ${(previousBest * weightMultiplier).round()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    scenarioName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'CURRENT RANK',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leftRank != null)
                        Opacity(
                          opacity: 0.3,
                          child: SvgPicture.asset(
                            'assets/images/ranks/${leftRank.toLowerCase()}.svg',
                            height: 56,
                          ),
                        )
                      else
                        const SizedBox(width: 56),
                      const SizedBox(width: 12),
                      SvgPicture.asset(
                        'assets/images/ranks/${currentRank.toLowerCase()}.svg',
                        height: 72,
                      ),
                      const SizedBox(width: 12),
                      if (rightRank != null)
                        Opacity(
                          opacity: 0.3,
                          child: SvgPicture.asset(
                            'assets/images/ranks/${rightRank.toLowerCase()}.svg',
                            height: 56,
                          ),
                        )
                      else
                        const SizedBox(width: 56),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentRank,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 200,
                    height: 20,
                    color: Colors.grey[800],
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getRankColor(currentRank),
                      ),
                      minHeight: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isMax
                        ? 'MAX RANK'
                        : nextThreshold != null
                            ? '$scaledScore / ${(nextThreshold * weightMultiplier).round()}'
                            : '$scaledScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: const Text('Back to Menu'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
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