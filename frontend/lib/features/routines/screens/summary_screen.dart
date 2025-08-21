// frontend/lib/features/routines/screens/summary_screen.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SummaryScreen extends StatelessWidget {
  final num totalVolume;

  const SummaryScreen({super.key, required this.totalVolume});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Summary'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Routine Complete!',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 20),
            Text(
              'Total Volume Lifted: $totalVolume kg',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to ExerciseListScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Back to Exercises'),
            ),
          ],
        ),
      ),
    );
  }
}
