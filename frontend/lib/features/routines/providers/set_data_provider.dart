// frontend/lib/features/routines/providers/set_data_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Renamed to be clearer: this represents a single, performed set.
class PerformedSet {
  final String scenarioId;
  final int reps;
  final double weight; // Always stored in KG

  PerformedSet({
    required this.scenarioId,
    required this.reps,
    required this.weight,
  });

  // copyWith is a standard best practice for immutable models.
  PerformedSet copyWith({
    String? scenarioId,
    int? reps,
    double? weight,
  }) {
    return PerformedSet(
      scenarioId: scenarioId ?? this.scenarioId,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
    );
  }

  // Simplified to only include what the backend needs for submission.
  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'reps': reps,
        'weight': weight,
        // The 'sets' field is implicitly 1 and can be handled by the backend if needed.
      };
}

class PerformedSetNotifier extends StateNotifier<List<PerformedSet>> {
  PerformedSetNotifier() : super([]);

  /// Replaces all sets for a given exercise with the new data.
  /// This correctly handles editing/updating sets.
  void addSets(String scenarioId, List<Map<String, dynamic>> setData) {
    // Remove all previous sets for this specific exercise first.
    final updatedState = state.where((set) => set.scenarioId != scenarioId).toList();

    // Then, add the new sets from the submitted data.
    for (var set in setData) {
      updatedState.add(
        PerformedSet(
          scenarioId: scenarioId,
          reps: set['reps'] as int,
          weight: set['weight'] as double,
        ),
      );
    }
    
    state = updatedState;
  }

  /// Clears all sets from the current session.
  void clear() => state = [];
}

// The provider now correctly provides the PerformedSetNotifier and its state.
final routineSetProvider =
    StateNotifierProvider<PerformedSetNotifier, List<PerformedSet>>(
        (ref) => PerformedSetNotifier());