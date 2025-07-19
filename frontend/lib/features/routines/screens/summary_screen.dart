// frontend/lib/features/routines/screens/summary_screen.dart

import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  final num totalVolume;

  const SummaryScreen({super.key, required this.totalVolume});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Summary'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Routine Complete!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Total Volume Lifted: $totalVolume kg',
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Go back to ExerciseListScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
