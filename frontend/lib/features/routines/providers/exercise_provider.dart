// frontend/lib/features/routines/providers/exercise_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

final exerciseListProvider =
    StateNotifierProvider<ExerciseListNotifier, List<Map<String, dynamic>>>(
        (ref) {
  return ExerciseListNotifier();
});

final totalVolumeProvider = StateProvider<num>((ref) => 0);

class ExerciseListNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  ExerciseListNotifier() : super([]);

  void setExercises(List<Map<String, dynamic>> exercises) {
    state = exercises;
  }

  void addExercise(Map<String, dynamic> exercise) {
    state = [...state, exercise];
  }
}
