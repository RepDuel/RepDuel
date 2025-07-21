import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A set entry for a specific scenario
class RoutineSet {
  final String scenarioId;
  final int sets;
  final int reps;
  final double weight;

  RoutineSet({
    required this.scenarioId,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  double get totalVolume => weight * reps * sets;

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'total_volume': totalVolume,
      };
}

class RoutineSetNotifier extends StateNotifier<List<RoutineSet>> {
  RoutineSetNotifier() : super([]);

  void addSets(String scenarioId, List<Map<String, dynamic>> setData) {
    for (var set in setData) {
      state = [
        ...state,
        RoutineSet(
          scenarioId: scenarioId,
          sets: 1,
          reps: set['reps'],
          weight: set['weight'],
        ),
      ];
    }
  }

  void clear() => state = [];
}

final routineSetProvider =
    StateNotifierProvider<RoutineSetNotifier, List<RoutineSet>>(
        (ref) => RoutineSetNotifier());
