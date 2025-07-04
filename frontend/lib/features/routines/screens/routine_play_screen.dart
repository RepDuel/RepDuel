import 'package:flutter/material.dart';

class RoutinePlayScreen extends StatelessWidget {
  final String routineName;

  const RoutinePlayScreen({super.key, required this.routineName});

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      {'name': 'Bench', 'sets': '4'},
      {'name': 'Squat', 'sets': '4'},
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Play Routine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Table headers
            const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Sets',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scenario rows
            ...scenarios.map(
              (scenario) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        scenario['name']!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        scenario['sets']!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // START button at bottom
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // TODO: Start the routine logic
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }
}
