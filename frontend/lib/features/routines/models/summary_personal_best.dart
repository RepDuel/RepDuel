// frontend/lib/features/routines/models/summary_personal_best.dart

class SummaryPersonalBest {
  final String scenarioId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final double scoreValue;
  final bool isBodyweight;
  final bool isPersonalBest;
  final String rankName;

  const SummaryPersonalBest({
    required this.scenarioId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.scoreValue,
    required this.isBodyweight,
    required this.isPersonalBest,
    required this.rankName,
  });
}
