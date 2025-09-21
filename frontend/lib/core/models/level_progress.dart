// frontend/lib/core/models/level_progress.dart

class LevelProgress {
  final int level;
  final int xp;
  final int xpToNext;
  final double progressPct;
  final int xpGainedThisWeek;

  const LevelProgress({
    required this.level,
    required this.xp,
    required this.xpToNext,
    required this.progressPct,
    required this.xpGainedThisWeek,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    final level = (json['level'] as num?)?.toInt() ?? 1;
    final xp = (json['xp'] as num?)?.toInt() ?? 0;
    final xpToNext = (json['xp_to_next'] as num?)?.toInt() ?? 0;
    final rawProgressPct = (json['progress_pct'] as num?)?.toDouble() ?? 0.0;
    final xpGainedThisWeek = (json['xp_gained_this_week'] as num?)?.toInt() ?? 0;
    final progressPct = rawProgressPct.clamp(0.0, 1.0).toDouble();

    return LevelProgress(
      level: level,
      xp: xp,
      xpToNext: xpToNext,
      progressPct: progressPct,
      xpGainedThisWeek: xpGainedThisWeek,
    );
  }
}
