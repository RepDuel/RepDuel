import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AddExerciseScreen extends StatelessWidget {
  final Logger _logger = Logger(); // Non-constant field

  AddExerciseScreen({super.key}); // Removed 'const' here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercise'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // When the back button is pressed, simply pop this screen
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Use logger instead of print
            _logger.i("Exercise added");

            // Optionally, you could return some data here (e.g., the new exercise)
            Navigator.pop(context, {
              'exerciseName': 'New Exercise',
              'sets': [
                {'weight': 0.0, 'reps': 0}
              ], // Example data structure
            });
          },
          child: const Text('Add New Exercise'),
        ),
      ),
    );
  }
}
