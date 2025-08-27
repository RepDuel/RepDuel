// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/features/ranked/screens/result_screen.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/loading_spinner.dart';

class ExercisePlayScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;
  const ExercisePlayScreen({super.key, required this.exerciseId, required this.exerciseName, required this.sets, required this.reps});
  @override
  ConsumerState<ExercisePlayScreen> createState() => _ExercisePlayScreenState();
}

class _ExercisePlayScreenState extends ConsumerState<ExercisePlayScreen> {
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _repControllers;
  bool _isLoadingDetails = true;
  bool _isSubmitting = false;
  String? _description;
  bool _isBodyweight = false;

  @override
  void initState() {
    super.initState();
    _weightControllers = List.generate(widget.sets, (_) => TextEditingController());
    _repControllers = List.generate(widget.sets, (_) => TextEditingController(text: widget.reps.toString()));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadScenarioDetails(); });
  }

  @override
  void dispose() {
    for (var controller in _weightControllers) { controller.dispose(); }
    for (var controller in _repControllers) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _loadScenarioDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    try {
      final client = ref.read(privateHttpClientProvider);
      final response = await client.get('/scenarios/${widget.exerciseId}');
      if (mounted) {
        setState(() {
          _description = response.data['description'] as String?;
          _isBodyweight = response.data['is_bodyweight'] as bool? ?? false;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
    final authState = ref.read(authProvider).valueOrNull;
    if (authState?.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication error.")));
      return;
    }
    final user = authState!.user!;
    setState(() => _isSubmitting = true);

    try {
      double bestOneRepMax = 0;
      double weightForBestSet = 0;
      int repsForBestSet = 0;

      for (int i = 0; i < widget.sets; i++) {
        final reps = int.tryParse(_repControllers[i].text);
        if (reps == null || reps <= 0) continue;
        double weightKg = 0;
        if (!_isBodyweight) {
          final weightUserUnit = double.tryParse(_weightControllers[i].text);
          if (weightUserUnit == null || weightUserUnit <= 0) continue;
          weightKg = (user.weightMultiplier == 1.0) ? weightUserUnit : weightUserUnit / 2.20462;
        }
        final oneRepMax = _calculateOneRepMax(weightKg, reps);
        if (oneRepMax > bestOneRepMax) {
          bestOneRepMax = oneRepMax;
          weightForBestSet = weightKg;
          repsForBestSet = reps;
        }
      }
      if (bestOneRepMax == 0) throw Exception("Please enter at least one valid set.");

      final client = ref.read(privateHttpClientProvider);
      final highscoreResponse = await client.get('/scores/user/${user.id}/scenario/${widget.exerciseId}/highscore');
      final previousBest = (highscoreResponse.data['score_value'] as num?)?.round() ?? 0;
      await client.post('/scores/scenario/${widget.exerciseId}/', data: { 'user_id': user.id, 'weight_lifted': weightForBestSet, 'reps': repsForBestSet, 'sets': 1, });
      
      if (!mounted) return;
      final shouldRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(finalScore: bestOneRepMax, previousBest: previousBest, scenarioId: widget.exerciseId)),
      );
      if (shouldRefresh == true && mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    } finally {
      if (mounted) { setState(() => _isSubmitting = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.exerciseName), backgroundColor: Colors.black, elevation: 0),
        body: _isLoadingDetails
            ? const Center(child: LoadingSpinner())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_isBodyweight) _buildHeaderRow(),
                  const SizedBox(height: 8),
                  ...List.generate(widget.sets, (index) => _buildSetRow(index + 1, _weightControllers[index], _repControllers[index])),
                ],
              ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _handleSubmit,
            icon: _isSubmitting ? const LoadingSpinner(size: 20) : const Icon(Icons.check_circle_outline),
            label: Text(_isSubmitting ? 'Submitting...' : 'Finish & Calculate Score'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(children: [SizedBox(width: 50, child: Text('Set', style: TextStyle(color: Colors.white70))), Expanded(child: Center(child: Text('Weight', style: TextStyle(color: Colors.white70)))), SizedBox(width: 24), Expanded(child: Center(child: Text('Reps', style: TextStyle(color: Colors.white70))))]),
    );
  }

  Widget _buildSetRow(int setNumber, TextEditingController weightController, TextEditingController repController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [SizedBox(width: 50, child: Text('$setNumber', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)), Expanded(child: _buildInputField(controller: weightController)), const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('x', style: TextStyle(color: Colors.white, fontSize: 18))), Expanded(child: _buildInputField(controller: repController))]),
    );
  }

  Widget _buildInputField({required TextEditingController controller}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(filled: true, fillColor: Colors.grey[900], contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
    );
  }
}