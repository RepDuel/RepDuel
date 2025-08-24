// frontend/lib/features/ranked/models/score_history_entry.dart

class ScoreHistoryEntry {
  final double score;
  final DateTime date;
  ScoreHistoryEntry({required this.score, required this.date});
  
  factory ScoreHistoryEntry.fromJson(Map<String, dynamic> json) => ScoreHistoryEntry(
    score: (json['weight_lifted'] as num).toDouble(),
    date: DateTime.parse(json['created_at'] as String),
  );
}