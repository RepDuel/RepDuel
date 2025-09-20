// frontend/lib/core/providers/personal_best_events_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PersonalBestEvent {
  final String userId;
  final String scenarioId;
  final bool isBodyweight;
  final double weightKg;
  final int reps;
  final DateTime createdAt;
  final String? exerciseName; // optional friendly name

  const PersonalBestEvent({
    required this.userId,
    required this.scenarioId,
    required this.isBodyweight,
    required this.weightKg,
    required this.reps,
    required this.createdAt,
    this.exerciseName,
  });
}

class PersonalBestEventsNotifier extends StateNotifier<List<PersonalBestEvent>> {
  PersonalBestEventsNotifier() : super(const []);

  void add(PersonalBestEvent e) {
    final items = [e, ...state];
    // keep last 50 to avoid unbounded growth
    state = items.take(50).toList();
  }

  void clear() => state = const [];
}

final personalBestEventsProvider =
    StateNotifierProvider<PersonalBestEventsNotifier, List<PersonalBestEvent>>(
        (ref) => PersonalBestEventsNotifier());

