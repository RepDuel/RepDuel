// frontend/lib/features/scenario/screens/scenario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/env.dart';
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
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();
  bool _isSubmitting = false;

  String? _description;
  bool _isBodyweight = false;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _loadScenarioDetails();
    _setupKeyboardDismissal();
  }

  void _setupKeyboardDismissal() {
    _weightFocusNode.addListener(() {
      if (!_weightFocusNode.hasFocus) {
        _dismissKeyboard();
      }
    });
    
    _repsFocusNode.addListener(() {
      if (!_repsFocusNode.hasFocus) {
        _dismissKeyboard();
      }
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _loadScenarioDetails() async {
    final url =
        Uri.parse('${Env.baseUrl}/api/v1/scenarios/${widget.scenarioId}/details');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _description = data['description'];
            _isBodyweight = data['is_bodyweight'] ?? false;
          });
        }
      } else {
        if (mounted) setState(() => _description = 'Failed to load description.');
      }
    } catch (e) {
      if (mounted) setState(() => _description = 'Failed to load description.');
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  double _calculateOneRepMax(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId) async {
    final url = Uri.parse(
        '${Env.baseUrl}/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['score_value'] as num?)?.round() ?? 0;
      }
    } catch (e) {
      // Ignore errors here, just return 0
    }
    return 0;
  }

  Future<void> _submitScore(double weightLifted, int reps) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final token = ref.read(authProvider).token;
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/scenario/${widget.scenarioId}/');
    final body = {
      'user_id': user.id,
      'weight_lifted': weightLifted,
      'reps': reps,
      'sets': 1,
    };

    await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    );
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final reps = int.tryParse(_repsController.text) ?? 0;
    if (reps <= 0) {
      return;
    }

    setState(() => _isSubmitting = true);

    double scoreToSubmit;
    double weightForBackend;

    if (_isBodyweight) {
      scoreToSubmit = reps.toDouble();
      weightForBackend = 0.0;
    } else {
      final weight = double.tryParse(_weightController.text) ?? 0;
      if (weight <= 0) {
        setState(() => _isSubmitting = false);
        return;
      }
      final oneRepMax = _calculateOneRepMax(weight, reps);
      final userMultiplier = user.weightMultiplier;
      
      scoreToSubmit = oneRepMax / userMultiplier;
      weightForBackend = scoreToSubmit;
    }

    final previousBest = await _fetchPreviousBest(user.id, widget.scenarioId);

    await _submitScore(weightForBackend, reps);

    if (!mounted) return;

    final shouldRefresh = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          finalScore: scoreToSubmit,
          previousBest: previousBest,
          scenarioId: widget.scenarioId,
        ),
      ),
    );

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
                const Text('• ',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                Expanded(
                    child: Text(s.trim(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.5))),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildRepsOnlyInput() {
    return Column(
      children: [
        const Text('Reps', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _repsController,
            focusNode: _repsFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dismissKeyboard(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightAndRepsInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            const Text('Weight',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _weightController,
                focusNode: _weightFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _repsFocusNode.requestFocus(),
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
            const Text('Reps',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _dismissKeyboard(),
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
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
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
                if (_isLoadingDetails)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  ..._buildBulletDescription(_description),
                  const SizedBox(height: 32),
                  if (_isBodyweight)
                    _buildRepsOnlyInput()
                  else
                    _buildWeightAndRepsInput(),
                ],
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
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}