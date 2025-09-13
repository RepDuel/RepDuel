// frontend/lib/features/ranked/utils/lift_progress.dart
import 'package:flutter/foundation.dart';

@immutable
class LiftProgress {
  final String matchedRank; // e.g. "Nova"
  final double currentThreshold; // in display unit (kg*mult or lbs)
  final double nextThreshold; // in display unit (kg*mult or lbs)
  final double progress; // 0..1 inclusive

  const LiftProgress({
    required this.matchedRank,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.progress,
  });
}

/// Computes matched rank, current/next thresholds, and progress using the SAME
/// logic as ranking_table.dart. Assumes:
/// - `liftStandards` thresholds are already in the **display unit** (kg*mult or lbs),
///   just like what the table receives/uses.
/// - `score` is also in the same display unit.
/// - `liftKey` is one of 'squat' | 'bench' | 'deadlift' (or whatever your pack uses).
LiftProgress computeLiftProgress({
  required Map<String, dynamic> liftStandards,
  required String liftKey,
  required double score,
}) {
  // Sort ranks from highest → lowest by their thresholds for this lift
  final entries = liftStandards.entries.toList()
    ..sort((a, b) {
      final av = (a.value['lifts'][liftKey] ?? 0) as num;
      final bv = (b.value['lifts'][liftKey] ?? 0) as num;
      return (av.compareTo(bv)) * -1;
    });

  String matchedRank = 'Unranked';
  double currentThreshold = 0.0;
  double nextThreshold = 0.0;

  for (final e in entries) {
    final th = ((e.value['lifts'][liftKey] ?? 0) as num).toDouble();
    if (score >= th) {
      matchedRank = e.key;
      currentThreshold = th;
      break;
    }
  }

  final bool isMax = entries.isNotEmpty && matchedRank == entries.first.key;

  if (isMax) {
    // Already top tier → denominator equals current (same as table)
    nextThreshold = currentThreshold;
  } else if (matchedRank != 'Unranked') {
    final idx = entries.indexWhere((e) => e.key == matchedRank);
    if (idx > 0) {
      nextThreshold =
          ((entries[idx - 1].value['lifts'][liftKey] ?? 0) as num).toDouble();
    }
  } else {
    // Below the lowest tier → aim for the lowest tier’s threshold
    nextThreshold = entries.isNotEmpty
        ? ((entries.last.value['lifts'][liftKey] ?? 0) as num).toDouble()
        : 0.0;
  }

  double progress = 0.0;
  if (isMax) {
    progress = 1.0;
  } else if (nextThreshold > currentThreshold) {
    progress = ((score - currentThreshold) / (nextThreshold - currentThreshold))
        .clamp(0.0, 1.0);
  } else if (nextThreshold > 0) {
    progress = (score / nextThreshold).clamp(0.0, 1.0);
  }

  return LiftProgress(
    matchedRank: matchedRank,
    currentThreshold: currentThreshold,
    nextThreshold: nextThreshold,
    progress: progress,
  );
}
