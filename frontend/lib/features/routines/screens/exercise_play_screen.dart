// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/loading_spinner.dart';
import '../../ranked/screens/result_screen.dart';

class ExercisePlayScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;

  const ExercisePlayScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
  });

  @override
  ConsumerState<ExercisePlayScreen> createState() => _ExercisePlayScreenState();
}

class _ExercisePlayScreenState extends ConsumerState<ExercisePlayScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();

  bool _isLoadingDetails = true;
  bool _isSubmitting = false;
  String? _description;
  bool _isBodyweight = false;

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure 'ref' is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadScenarioDetails();
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _loadScenarioDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);

    try {
      final client = ref.read(privateHttpClientProvider);
      final response = await client.get('/scenarios/${widget.exerciseId}');
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _description = data['description'] as String?;
          _isBodyweight = data['is_bodyweight'] as bool? ?? false;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: ${e.toString()}')));
      }
    }
  }

  double _calculateOneRepMax(double weightKg, int reps) {
    if (reps <= 0) return 0.0;
    if (reps == 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }
  
  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    
    // --- THIS IS THE FIX ---
    // First, read the nullable AuthState value.
    final authState = ref.read(authProvider).valueOrNull;
    // THEN, perform a robust null check on authState AND its user property.
    if (authState == null || authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication error. Please log in again.")));
      return;
    }
    // Because of the check above, the compiler now knows `authState` and `authState.user` are not null.
    final user = authState.user!;
    // --- END OF FIX ---

    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter valid reps.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      double scoreToSubmitForRank;
      double weightLiftedKgForBackend;

      if (_isBodyweight) {
        scoreToSubmitForRank = reps.toDouble();
        weightLiftedKgForBackend = 0.0;
      } else {
        final weightText = _weightController.text.trim();
        final weightUserUnit = double.tryParse(weightText);
        if (weightUserUnit == null || weightUserUnit <= 0) {
          throw Exception("Please enter valid weight.");
        }
        
        final weightKg = (user.weightMultiplier == 1.0) 
            ? weightUserUnit 
            : weightUserUnit / 2.20462;

        scoreToSubmitForRank = _calculateOneRepMax(weightKg, reps);
        weightLiftedKgForBackend = weightKg;
      }
      
      final client = ref.read(privateHttpClientProvider);

      final highscoreResponse = await client.get('/scores/user/${user.id}/scenario/${widget.exerciseId}/highscore');
      final previousBest = (highscoreResponse.data['score_value'] as num?)?.round() ?? 0;
      
      await client.post(
        '/scores/scenario/${widget.exerciseId}/',
        data: {
          'user_id': user.id,
          'weight_lifted': weightLiftedKgForBackend,
          'reps': reps,
          'sets': 1,
        },
      );
      
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            finalScore: scoreToSubmitForRank,
            previousBest: previousBest,
            scenarioId: widget.exerciseId,
          ),
        ),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<Widget> _buildBulletDescription(String? description) {
    if (description == null || description.isEmpty) return [];
    return description.split('. ').where((s) => s.isNotEmpty).map((s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
          Expanded(child: Text(s.trim(), style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
        ],
      ),
    )).toList();
  }

  Widget _buildRepsOnlyInput() => _buildInputField(controller: _repsController, label: 'Reps');
  Widget _buildWeightAndRepsInput() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildInputField(controller: _weightController, label: 'Weight'),
      const Text('x', style: TextStyle(color: Colors.white, fontSize: 24)),
      _buildInputField(controller: _repsController, label: 'Reps'),
    ],
  );

  Widget _buildInputField({required TextEditingController controller, required String label}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    if (authState.valueOrNull?.user == null && !authState.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Please log in to record scores.', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Go to Login')),
          ]),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.exerciseName),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: _isLoadingDetails
            ? const Center(child: LoadingSpinner())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ..._buildBulletDescription(_description),
                      const SizedBox(height: 32),
                      if (_isBodyweight)
                        _buildRepsOnlyInput()
                      else
                        _buildWeightAndRepsInput(),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            icon: _isSubmitting ? const LoadingSpinner(size: 20) : const Icon(Icons.check),
            label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}