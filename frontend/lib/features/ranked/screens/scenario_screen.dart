import 'package:flutter/material.dart';
import 'result_screen.dart';

class ScenarioScreen extends StatelessWidget {
  final String liftName;

  const ScenarioScreen({super.key, required this.liftName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(liftName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'This is the scenario screen.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () {
            // Navigate to the result screen with dummy score for now
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResultScreen(
                  finalScore: 100,
                  previousBest: 100,
                ),
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('Confirm'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
