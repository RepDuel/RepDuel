// frontend/lib/features/scenario/screens/scenario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../ranked/screens/result_screen.dart'; // We need the provider from here

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
    final url = Uri.parse('${Env.baseUrl}/api/v1/scenarios/${widget.scenarioId}/details');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) setState(() => _description = data['description']);
      } else {
        if (mounted) setState(() => _description = 'Failed to load description.');
      }
    } catch (e) {
      if (mounted) setState(() => _description = 'Failed to load description.');
    } finally {
      if (mounted) setState(() => _isLoadingDescription = false);
    }
  }

  double _calculateOneRepMax(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId) async {
    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['weight_lifted'] as num?)?.round() ?? 0;
      }
    } catch (e) {
      // Ignore errors here, just return 0 if fetching previous best fails
    }
    return 0;
  }

  Future<void> _submitScore(double score, int reps) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/scenario/${widget.scenarioId}/');
    final token = ref.read(authProvider).token;
    final body = {
      'user_id': user.id,
      'weight_lifted': score,
      'reps': reps,
      'sets': 1,
    };
    
    await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': 'Bearer $token', // Example if you need auth
      },
      body: json.encode(body),
    );
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final weight = double.tryParse(_weightController.text) ?? 0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    if (weight <= 0 || reps <= 0) return; // Basic validation

    final oneRepMax = _calculateOneRepMax(weight, reps);

    setState(() => _isSubmitting = true);

    final previousBest = await _fetchPreviousBest(user.id, widget.scenarioId);
    final userMultiplier = user.weightMultiplier;
    final adjustedScore = oneRepMax / userMultiplier;

    await _submitScore(adjustedScore, reps);

    if (!mounted) return;

    // --- THIS IS THE CRITICAL FIX ---
    // We navigate to a ProviderScope that overrides the provider's value.
    final shouldRefresh = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [
            // Provide the real score to the provider.
            currentScoreProvider.overrideWithValue(adjustedScore.round()),
          ],
          child: ResultScreen(
            // Pass the props to the widget as before.
            finalScore: adjustedScore.round(),
            previousBest: previousBest,
            scenarioId: widget.scenarioId,
          ),
        ),
      ),
    );
    // --- END OF FIX ---

    if (shouldRefresh == true && mounted) {
      Navigator.of(context).pop(true);
    }

    setState(() => _isSubmitting = false);
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
                const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
                Expanded(child: Text(s.trim(), style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
              ],
            ),
          ),
        ).toList();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI logic remains the same...
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
                      const Text('Weight', style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('x', style: TextStyle(color: Colors.white, fontSize: 24)),
                  ),
                  Column(
                    children: [
                      const Text('Reps', style: TextStyle(color: Colors.white, fontSize: 16)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          icon: _isSubmitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
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