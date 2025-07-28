class RoutineScenarioSubmission {
  final String scenarioId;
  final int sets;
  final int reps;
  final double weight;
  final double totalVolume;

  RoutineScenarioSubmission({
    required this.scenarioId,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.totalVolume,
  });

  factory RoutineScenarioSubmission.fromJson(Map<String, dynamic> json) {
    return RoutineScenarioSubmission(
      scenarioId: json['scenario_id'],
      sets: json['sets'],
      reps: json['reps'],
      weight: (json['weight'] as num).toDouble(),
      totalVolume: (json['total_volume'] as num).toDouble(),
    );
  }
}

class RoutineSubmissionRead {
  final String routineId;
  final String userId;
  final double duration;
  final String completionTimestamp;
  final String status;
  final String title;
  final List<RoutineScenarioSubmission> scenarios;

  RoutineSubmissionRead({
    required this.routineId,
    required this.userId,
    required this.duration,
    required this.completionTimestamp,
    required this.status,
    required this.title,
    required this.scenarios,
  });

  factory RoutineSubmissionRead.fromJson(Map<String, dynamic> json) {
    return RoutineSubmissionRead(
      routineId: json['routine_id'],
      userId: json['user_id'],
      duration: (json['duration'] as num).toDouble(),
      completionTimestamp: json['completion_timestamp'],
      status: json['status'],
      title: json['title'],
      scenarios: (json['scenario_submissions'] as List)
          .map((e) => RoutineScenarioSubmission.fromJson(e))
          .toList(),
    );
  }
}
