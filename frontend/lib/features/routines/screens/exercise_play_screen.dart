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
              Text(
                'Enter the weights and reps for each set',
                style: const TextStyle(color: Colors.white, fontSize: 18),
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
                          decoration: InputDecoration(
                            labelText: 'Set ${index + 1} Weight (kg)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: const OutlineInputBorder(),
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
                          decoration: InputDecoration(
                            labelText: 'Reps',
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: const OutlineInputBorder(),
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
                  // Logic for saving results
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Start Exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
