// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/set_data_provider.dart';
import '../../../core/providers/auth_provider.dart';

class ExercisePlayScreen extends ConsumerWidget {
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

  static const double _kgToLbs = 2.20462;

  bool _isLbs(WidgetRef ref) {
    // Heuristic: weightMultiplier ~1.0 => kg, ~2.2 => lbs
    final wm = ref.watch(authStateProvider).user?.weightMultiplier ?? 1.0;
    return wm > 1.5;
  }

  String _unit(WidgetRef ref) => _isLbs(ref) ? 'lb' : 'kg';

  double _toDisplayUnit(WidgetRef ref, double kg) =>
      _isLbs(ref) ? kg * _kgToLbs : kg;

  double _toKg(WidgetRef ref, double valueInUserUnit) =>
      _isLbs(ref) ? valueInUserUnit / _kgToLbs : valueInUserUnit;

  String _fmt(num n) =>
      (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = _unit(ref);

    // Previously entered sets for this exercise (stored in KG in the provider)
    final previousSets = ref
        .watch(routineSetProvider)
        .where((set) => set.scenarioId == exerciseId)
        .toList();

    // Build controllers with values converted to the user's preferred unit
    final weightControllers = List<TextEditingController>.generate(
      sets,
      (index) {
        String text = '';
        if (index < previousSets.length) {
          final kg = previousSets[index].weight;
          if (kg > 0) text = _fmt(_toDisplayUnit(ref, kg));
        }
        return TextEditingController(text: text);
      },
    );

    final repControllers = List<TextEditingController>.generate(
      sets,
      (index) {
        String text = reps.toString();
        if (index < previousSets.length) {
          final r = previousSets[index].reps;
          if (r > 0) text = r.toString();
        }
        return TextEditingController(text: text);
      },
    );

    InputDecoration _dec(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white54),
          ),
          fillColor: Colors.white10,
          filled: true,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('Exercise: $exerciseName'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Enter the weights ($unit) and reps for each set',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              ...List.generate(sets, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: weightControllers[index],
                          decoration: _dec('Weight ($unit)'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: repControllers[index],
                          decoration: _dec('Reps'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                            signed: false,
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final setData = <Map<String, dynamic>>[];

                  for (int i = 0; i < sets; i++) {
                    final weightText = weightControllers[i].text.trim();
                    final repsText = repControllers[i].text.trim();

                    final weightUser = double.tryParse(weightText) ?? 0.0;
                    final weightKg = _toKg(
                        ref, weightUser); // convert to KG for storage/backend

                    final repsVal = int.tryParse(repsText) ?? 0;

                    setData.add({'weight': weightKg, 'reps': repsVal});
                  }

                  // Persist to provider in KG so the rest of the app/back-end stays consistent
                  ref
                      .read(routineSetProvider.notifier)
                      .addSets(exerciseId, setData);

                  Navigator.pop(context, setData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
