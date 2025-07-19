// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'package:flutter/material.dart';

class ExercisePlayScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    List<TextEditingController> weightControllers =
        List.generate(sets, (_) => TextEditingController());
    List<TextEditingController> repControllers = List.generate(
        sets, (_) => TextEditingController(text: reps.toString()));

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
                      // Weight input
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
                      // Reps input
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
                  // Gather the data from the controllers
                  List<Map<String, dynamic>> setData = [];
                  for (int i = 0; i < sets; i++) {
                    double weight =
                        double.tryParse(weightControllers[i].text) ?? 0;
                    int reps = int.tryParse(repControllers[i].text) ?? 0;
                    setData.add({
                      'weight': weight,
                      'reps': reps,
                    });
                  }

                  // Send the data back to the ExerciseListScreen
                  Navigator.pop(context, setData); // Pop with set data
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
