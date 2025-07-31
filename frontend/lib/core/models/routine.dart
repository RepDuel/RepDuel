// frontend/lib/core/models/routine.dart

class ScenarioSet {
  final String scenarioId;
  final int sets;
  final int reps;

  ScenarioSet({
    required this.scenarioId,
    required this.sets,
    required this.reps,
  });

  factory ScenarioSet.fromJson(Map<String, dynamic> json) {
    return ScenarioSet(
      scenarioId: json['scenario_id'],
      sets: json['sets'],
      reps: json['reps'],
    );
  }

  Map<String, dynamic> toJson() => {
        'scenario_id': scenarioId,
        'sets': sets,
        'reps': reps,
      };
}

class Routine {
  final String id;
  final String name;
  final String? imageUrl;
  final String? userId; // <-- ownership (null => global template)
  final List<ScenarioSet> scenarios;

  Routine({
    required this.id,
    required this.name,
    this.imageUrl,
    this.userId,
    required this.scenarios,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'],
      name: json['name'],
      imageUrl: json['image_url'],
      userId: json['user_id'], // <-- present on backend RoutineRead
      scenarios: (json['scenarios'] as List)
          .map((e) => ScenarioSet.fromJson(e))
          .toList(),
    );
  }

  /// Total number of sets across all scenarios
  int get totalSets => scenarios.fold<int>(0, (sum, s) => sum + s.sets);

  /// Estimated duration in minutes (3 min per set)
  int get totalDurationMinutes => totalSets * 3;
}
