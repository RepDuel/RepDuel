// frontend/lib/features/routines/screens/add_exercise_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AddExerciseScreen extends StatelessWidget {
  final Logger _logger = Logger();

  AddExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercise'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            _logger.i("Exercise added");

            Navigator.pop(context, {
              'exerciseName': 'New Exercise',
              'sets': [
                {'weight': 0.0, 'reps': 0}
              ],
            });
          },
          child: const Text('Add New Exercise'),
        ),
      ),
    );
  }
}
