// frontend/lib/features/scenario/screens/scenario_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../../ranked/screens/result_screen.dart';

final scenarioDetailsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, scenarioId) async {
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/scenarios/$scenarioId/details');
  return response.data as Map<String, dynamic>;
});

class ScenarioScreen extends ConsumerStatefulWidget {
  final String liftName;
  final String scenarioId;
  const ScenarioScreen({super.key, required this.liftName, required this.scenarioId});
  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  double _calculateOneRepMax(double weightInKg, int reps) {
    if (reps <= 0) return 0.0;
    if (reps == 1) return weightInKg;
    return weightInKg * (1 + reps / 30.0);
  }

  Future<void> _handleSubmit(bool isBodyweight) async {
    FocusScope.of(context).unfocus();
    final authState = ref.read(authProvider).valueOrNull;
    if (authState?.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication required.")));
      return;
    }
    final user = authState!.user!;
    
    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter valid reps.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      double scoreForRankCalc;
      double weightInKg;

      if (isBodyweight) {
        scoreForRankCalc = reps.toDouble();
        weightInKg = 0.0;
      } else {
        final weightInput = double.tryParse(_weightController.text);
        if (weightInput == null || weightInput <= 0) {
          throw Exception("Please enter a valid weight.");
        }
        weightInKg = weightInput / user.weightMultiplier;
        scoreForRankCalc = _calculateOneRepMax(weightInKg, reps);
      }

      final client = ref.read(privateHttpClientProvider);
      final highscoreResponse = await client.get('/scores/user/${user.id}/scenario/${widget.scenarioId}/highscore');
      final previousBest = (highscoreResponse.data['score_value'] as num?)?.round() ?? 0;

      await client.post('/scores/scenario/${widget.scenarioId}/', data: {
        'user_id': user.id,
        'weight_lifted': weightInKg,
        'reps': reps,
        'sets': 1,
      });
      
      if (!mounted) return;
      
      final shouldRefresh = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ResultScreen(finalScore: scoreForRankCalc, previousBest: previousBest, scenarioId: widget.scenarioId),
        ),
      );

      if (shouldRefresh == true && mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenarioDetailsAsync = ref.watch(scenarioDetailsProvider(widget.scenarioId));
    final unitLabel = (ref.watch(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0) > 1.5 ? 'lbs' : 'kg';
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.liftName), backgroundColor: Colors.black, elevation: 0),
      backgroundColor: Colors.black,
      body: scenarioDetailsAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.refresh(scenarioDetailsProvider(widget.scenarioId)))),
        data: (details) {
          final isBodyweight = details['is_bodyweight'] as bool? ?? false;
          final description = details['description'] as String?;
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (description != null) Text(description, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    isBodyweight ? _buildRepsOnlyInput() : _buildWeightAndRepsInput(unitLabel),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : () => _handleSubmit(scenarioDetailsAsync.value?['is_bodyweight'] ?? false),
          icon: _isSubmitting ? const LoadingSpinner(size: 20) : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
    );
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
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(filled: true, fillColor: Colors.grey[900], border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWeightAndRepsInput(String unitLabel) {
    return SizedBox(
      width: 300, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildInputFieldWithLabel(controller: _weightController, label: 'Weight ($unitLabel)')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12).copyWith(bottom: 11.0),
            child: const Text('x', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          Expanded(child: _buildInputFieldWithLabel(controller: _repsController, label: 'Reps')),
        ],
      ),
    );
  }

  Widget _buildInputFieldWithLabel({required TextEditingController controller, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}