// frontend/lib/features/ranked/screens/result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user multiplier from the auth provider
    final userMultiplier =
        ref.read(authStateProvider).user?.weightMultiplier ?? 1.0;

    // Multiply scores by the user multiplier
    final adjustedFinalScore = (finalScore * userMultiplier).round();
    final adjustedPreviousBest = (previousBest * userMultiplier).round();

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
              'Final Score: $adjustedFinalScore',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Previous Best Score: $adjustedPreviousBest',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Passing `true` to indicate that a new score was entered
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Back to Menu'),
            ),
          ],
        ),
      ),
    );
  }
}
