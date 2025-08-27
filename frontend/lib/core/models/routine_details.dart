// frontend/lib/core/models/routine_details.dart

class RoutineDetails {
  final String name;
  final List<Scenario> scenarios;

  RoutineDetails({required this.name, required this.scenarios});

  factory RoutineDetails.fromJson(Map<String, dynamic> json) {
    var scenariosFromJson = json['scenarios'] as List? ?? [];
    List<Scenario> scenarioList = scenariosFromJson.map((s) => Scenario.fromJson(s)).toList();
    
    return RoutineDetails(
      name: json['name'] as String? ?? 'Unnamed Routine',
      scenarios: scenarioList,
    );
  }
}

class Scenario {
  final String id;
  final String name;
  final int sets;
  final int reps;

  Scenario({required this.id, required this.name, required this.sets, required this.reps});

  factory Scenario.fromJson(Map<String, dynamic> json) {
    // Note: The key from the backend might be 'id' or 'scenario_id'. Adjust if needed.
    return Scenario(
      id: json['scenario_id'] as String? ?? json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Exercise',
      sets: json['sets'] as int? ?? 0,
      reps: json['reps'] as int? ?? 0,
    );
  }
}