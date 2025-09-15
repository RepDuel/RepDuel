// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/api_providers.dart';

import '../../../core/providers/auth_provider.dart';
import '../providers/set_data_provider.dart';

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
  // Cache for scenario details to avoid repeated requests within this screen
  final Map<String, Map<String, dynamic>> _scenarioDetailsCache = {};
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _repControllers;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers based on the routine's plan and any previously entered data
    _initializeControllers();
  }

  void _initializeControllers() {
    final previousSets = ref
        .read(routineSetProvider)
        .where((set) => set.scenarioId == widget.exerciseId)
        .toList();

    _weightControllers = List.generate(widget.sets, (index) {
      String text = '';
      if (index < previousSets.length) {
        final kg = previousSets[index].weight;
        if (kg > 0) {
          final displayWeight = _toDisplayUnit(ref, kg);
          text = (displayWeight % 1 == 0)
              ? displayWeight.toInt().toString()
              : displayWeight.toStringAsFixed(1);
        }
      }
      return TextEditingController(text: text);
    });

    _repControllers = List.generate(widget.sets, (index) {
      String text = widget.reps.toString();
      if (index < previousSets.length) {
        final repsVal = previousSets[index].reps;
        if (repsVal > 0) text = repsVal.toString();
      }
      return TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    for (var controller in _weightControllers) {
      controller.dispose();
    }
    for (var controller in _repControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Unit Conversion Helpers ---
  bool _isLbs(WidgetRef ref) {
    final wm =
        ref.read(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0;
    return wm > 1.5;
  }

  double _toDisplayUnit(WidgetRef ref, double kg) {
    return _isLbs(ref) ? kg * 2.20462 : kg;
  }

  double _toKg(WidgetRef ref, double valueInUserUnit) {
    return _isLbs(ref) ? valueInUserUnit / 2.20462 : valueInUserUnit;
  }

  void _submitAndReturnData() {
    final setDataForProvider = <Map<String, dynamic>>[];
    final setDataToReturn = <Map<String, dynamic>>[];

    for (int i = 0; i < widget.sets; i++) {
      final weightText = _weightControllers[i].text.trim();
      final repsText = _repControllers[i].text.trim();

      if (weightText.isEmpty && repsText.isEmpty) continue;

      final weightUserUnit = double.tryParse(weightText) ?? 0.0;
      final weightInKg = _toKg(ref, weightUserUnit);
      final reps = int.tryParse(repsText) ?? 0;

      if (reps > 0) {
        setDataForProvider.add({
          'scenario_id': widget.exerciseId,
          'weight': weightInKg,
          'reps': reps
        });
        setDataToReturn.add({'weight': weightInKg, 'reps': reps});
      }
    }

    ref
        .read(routineSetProvider.notifier)
        .addSets(widget.exerciseId, setDataForProvider);
    context.pop(setDataToReturn);
  }

  Future<Map<String, dynamic>?> _getScenarioDetails(String id) async {
    if (_scenarioDetailsCache.containsKey(id)) return _scenarioDetailsCache[id];
    try {
      final client = ref.read(publicHttpClientProvider);
      final res = await client.get('/scenarios/$id/details');
      final data = (res.data as Map).cast<String, dynamic>();
      _scenarioDetailsCache[id] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showScenarioInfo() async {
    final id = widget.exerciseId;
    final fallbackName = widget.exerciseName;
    final details = await _getScenarioDetails(id);
    final name = details?['name'] as String? ?? fallbackName;
    final desc = details?['description'] as String? ?? 'No description available.';
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Text(
                      desc,
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _isLbs(ref) ? 'lbs' : 'kg';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Exercise info',
            icon: const Icon(Icons.info_outline),
            onPressed: _showScenarioInfo,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: widget.sets,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                    width: 40,
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                const SizedBox(width: 8),
                Expanded(
                    flex: 3,
                    child: _buildInputField(
                        controller: _weightControllers[index],
                        label: 'Weight ($unitLabel)')),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('x',
                        style: TextStyle(color: Colors.white70, fontSize: 20))),
                Expanded(
                    flex: 2,
                    child: _buildInputField(
                        controller: _repControllers[index], label: 'Reps')),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: ElevatedButton.icon(
          onPressed: _submitAndReturnData,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm Sets'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50)),
        ),
      ),
    );
  }

  Widget _buildInputField(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
