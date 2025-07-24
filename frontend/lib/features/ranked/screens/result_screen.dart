import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  Future<Map<String, dynamic>> getRankProgress(
    String scenarioId,
    int scoreToUse,
    double userWeight,
    String userGender,
  ) async {
    final response = await http.get(
      Uri.parse(
          'http://localhost:8000/api/v1/scenarios/$scenarioId/multiplier'),
    );

    if (response.statusCode == 200) {
      final rankProgressResponse = await http.get(
        Uri.parse('http://localhost:8000/api/v1/ranks/get_rank_progress')
            .replace(queryParameters: {
          'scenario_id': scenarioId,
          'final_score': scoreToUse.toString(),
          'user_weight': userWeight.toString(),
          'user_gender': userGender.toLowerCase(),
        }),
      );

      if (rankProgressResponse.statusCode == 200) {
        return json.decode(rankProgressResponse.body);
      } else {
        logger.e(
            'Failed to load rank progress. Status code: ${rankProgressResponse.statusCode}');
        logger.e('Response body: ${rankProgressResponse.body}');
        throw Exception('Failed to load rank progress');
      }
    } else {
      logger
          .e('Failed to load multiplier. Status code: ${response.statusCode}');
      logger.e('Response body: ${response.body}');
      throw Exception('Failed to load multiplier');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).user;
    final userWeight = user?.weight ?? 70.0;
    final userGender = user?.gender ?? 'male';
    final scoreToUse = finalScore > previousBest ? finalScore : previousBest;

    return FutureBuilder<Map<String, dynamic>>(
      future: getRankProgress(scenarioId, scoreToUse, userWeight, userGender),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('Results'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: const Text('Results'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)),
            ),
          );
        }

        final rankProgress = snapshot.data!;
        final currentRank = rankProgress['current_rank'] ?? 'Unranked';
        final nextRankThreshold = rankProgress['next_rank_threshold'] ?? -1;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Results'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                Text(
                  'Final Score: $finalScore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Previous Best Score: $previousBest',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Current Rank: $currentRank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (nextRankThreshold > 0)
                  LinearProgressIndicator(
                    value: scoreToUse / nextRankThreshold,
                    backgroundColor: Colors.grey,
                    color: Colors.green,
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  child: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
