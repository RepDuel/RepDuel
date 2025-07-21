import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/providers/auth_provider.dart';
import '../../ranked/screens/result_screen.dart';

class ScenarioScreen extends ConsumerStatefulWidget {
  final String liftName;
  final String scenarioId;

  const ScenarioScreen({
    super.key,
    required this.liftName,
    required this.scenarioId,
  });

  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  bool _isSubmitting = false;

  double _calculateOneRepMax(double weight, int reps) {
    if (reps == 1) {
      return weight;
    }
    return weight * (1 + reps / 30);
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId) async {
    final url = Uri.parse(
        'http://localhost:8000/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['weight_lifted'] as num?)?.round() ?? 0;
    }
    return 0;
  }

  Future<void> _submitScore(double score) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final url = Uri.parse('http://localhost:8000/api/v1/scores/');
    final body = {
      'user_id': user.id,
      'scenario_id': widget.scenarioId,
      'weight_lifted': score,
    };

    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    final oneRepMax = _calculateOneRepMax(weight, reps);

    setState(() {
      _isSubmitting = true;
    });

    final previousBest = await _fetchPreviousBest(user.id, widget.scenarioId);
    await _submitScore(oneRepMax);

    if (!mounted) return;

    final shouldRefresh = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          finalScore: oneRepMax.round(),
          previousBest: previousBest,
        ),
      ),
    );

    if (shouldRefresh == true && mounted) {
      Navigator.of(context).pop(true);
    }

    setState(() {
      _isSubmitting = false;
    });
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
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
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
