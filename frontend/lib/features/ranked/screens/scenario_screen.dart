import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/providers/auth_provider.dart';
import 'result_screen.dart';

class ScenarioScreen extends ConsumerStatefulWidget {
  final String liftName;

  const ScenarioScreen({super.key, required this.liftName});

  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  static const scenarioIds = {
    'Squat': 'a9b52e3a-248d-4a89-82ab-555be989de5b',
    'Bench': 'bf610e59-fb34-4e21-bc36-bdf0f6f7be4f',
    'Deadlift': '9b6cf826-e243-4d3e-81bd-dfe4a8a0c05e',
  };

  double _calculateOneRepMax(double weight, int reps) {
    return weight * (1 + reps / 30);
  }

  Future<void> _submitScore(double score) async {
    final user = ref.read(authStateProvider).user;
    final scenarioId = scenarioIds[widget.liftName];

    if (user == null || scenarioId == null) return;

    final url = Uri.parse('http://localhost:8000/api/v1/scores/');
    final body = {
      'user_id': user.id,
      'scenario_id': scenarioId,
      'weight_lifted': score,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode >= 400) {
      // You could show a snackbar or dialog here
      debugPrint('Failed to submit score: ${response.body}');
    }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const Text('Weight',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  child: Text('·',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                Column(
                  children: [
                    const Text('Reps',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
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
          onPressed: () async {
            final weight = double.tryParse(_weightController.text) ?? 0;
            final reps = int.tryParse(_repsController.text) ?? 0;
            final oneRepMax = _calculateOneRepMax(weight, reps);

            await _submitScore(oneRepMax);

            final shouldRefresh = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  finalScore: oneRepMax.round(),
                  previousBest: 100, // Placeholder
                ),
              ),
            );

            if (shouldRefresh == true) {
              Navigator.pop(context, true); // Trigger RankedScreen refresh
            }
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
