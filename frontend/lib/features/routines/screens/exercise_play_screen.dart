import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/set_data_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previousSets = ref
        .watch(routineSetProvider)
        .where((set) => set.scenarioId == exerciseId)
        .toList();

    List<TextEditingController> weightControllers = List.generate(
      sets,
      (index) => TextEditingController(
        text: index < previousSets.length
            ? previousSets[index].weight.toString()
            : '',
      ),
    );

    List<TextEditingController> repControllers = List.generate(
      sets,
      (index) => TextEditingController(
        text: index < previousSets.length
            ? previousSets[index].reps.toString()
            : reps.toString(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Exercise: $exerciseName'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Enter the weights and reps for each set',
                style: TextStyle(color: Colors.white, fontSize: 18),
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
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: repControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Reps',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  List<Map<String, dynamic>> setData = [];
                  for (int i = 0; i < sets; i++) {
                    double weight =
                        double.tryParse(weightControllers[i].text) ?? 0;
                    int reps = int.tryParse(repControllers[i].text) ?? 0;
                    setData.add({'weight': weight, 'reps': reps});
                  }

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
