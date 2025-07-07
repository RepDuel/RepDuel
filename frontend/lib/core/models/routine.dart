// lib/core/models/routine.dart

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
}

class Routine {
  final String id;
  final String name;
  final String? imageUrl;
  final List<ScenarioSet> scenarios;

  Routine({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.scenarios,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'],
      name: json['name'],
      imageUrl: null, // Customize if backend returns images
      scenarios: (json['scenarios'] as List)
          .map((e) => ScenarioSet.fromJson(e))
          .toList(),
    );
  }
}
