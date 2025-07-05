import 'package:flutter/material.dart';
import 'result_screen.dart';

class ScenarioScreen extends StatefulWidget {
  final String liftName;

  const ScenarioScreen({super.key, required this.liftName});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  // Epley Formula: 1RM = weight × (1 + reps/30)
  double _calculateOneRepMax(double weight, int reps) {
    return weight * (1 + reps / 30);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.liftName),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Weight × Reps Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Weight Input
                Column(
                  children: [
                    const Text(
                      'Weight',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '·',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ), // Dot symbol
                ),
                // Reps Input
                Column(
                  children: [
                    const Text(
                      'Reps',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () {
            final weight = double.tryParse(_weightController.text) ?? 0;
            final reps = int.tryParse(_repsController.text) ?? 0;
            final oneRepMax = _calculateOneRepMax(weight, reps);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  finalScore: oneRepMax.round(), // Pass calculated 1RM
                  previousBest: 100, // Replace with actual user data
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
