// frontend/lib/features/scenario/screens/scenario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/config/env.dart';
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

  String? _description;
  bool _isLoadingDescription = true;

  @override
  void initState() {
    super.initState();
    _loadScenarioDetails();
  }

  Future<void> _loadScenarioDetails() async {
    final url = Uri.parse(
        '${Env.baseUrl}/api/v1/scenarios/${widget.scenarioId}/details');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _description = data['description'];
        _isLoadingDescription = false;
      });
    } else {
      setState(() {
        _description = 'Failed to load description.';
        _isLoadingDescription = false;
      });
    }
  }

  double _calculateOneRepMax(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId) async {
    final url = Uri.parse(
        '${Env.baseUrl}/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['weight_lifted'] as num?)?.round() ?? 0;
    }
    return 0;
  }

  Future<void> _submitScore(double score, int reps) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/');
    final body = {
      'user_id': user.id,
      'scenario_id': widget.scenarioId,
      'weight_lifted': score,
      'reps': reps,
      'sets': 1, // default 1 set
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
    final userMultiplier = user.weightMultiplier;
    final adjustedScore = oneRepMax / userMultiplier;

    await _submitScore(adjustedScore, reps);

    if (!mounted) return;

    final shouldRefresh = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          finalScore: adjustedScore.round(),
          previousBest: previousBest,
          scenarioId: widget.scenarioId,
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

  List<Widget> _buildBulletDescription(String? description) {
    if (description == null || description.isEmpty) return [];

    final sentences = description.split(RegExp(r'(?<=[.!?])\s+'));
    return sentences
        .where((s) => s.trim().isNotEmpty)
        .map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                Expanded(
                  child: Text(
                    s.trim(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoadingDescription)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else
                ..._buildBulletDescription(_description),
              const SizedBox(height: 32),
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
                    child: Text('x',
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
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
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
