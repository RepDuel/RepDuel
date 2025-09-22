// frontend/lib/core/providers/personal_best_events_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_providers.dart';

class PersonalBestEvent {
  final int id;
  final String userId;
  final String scenarioId;
  final bool isBodyweight;
  final double weightKg;
  final int? reps;
  final DateTime createdAt;
  final double scoreValue;
  final String? exerciseName; // optional friendly name if provided by API

  const PersonalBestEvent({
    required this.id,
    required this.userId,
    required this.scenarioId,
    required this.isBodyweight,
    required this.weightKg,
    required this.reps,
    required this.createdAt,
    required this.scoreValue,
    this.exerciseName,
  });

  factory PersonalBestEvent.fromJson(Map<String, dynamic> json) {
    return PersonalBestEvent(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      scenarioId: json['scenario_id'] as String,
      isBodyweight: json['is_bodyweight'] as bool? ?? false,
      weightKg: (json['weight_lifted'] as num).toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      scoreValue: (json['score_value'] as num).toDouble(),
      exerciseName: json['exercise_name'] as String?,
    );
  }
}

final personalBestEventsProvider = FutureProvider.autoDispose
    .family<List<PersonalBestEvent>, String>((ref, userId) async {
  final client = ref.read(privateHttpClientProvider);
  final response = await client.get('/personal_best_events/user/$userId');
  final data = response.data;

  if (data is List) {
    return data
        .map((e) => PersonalBestEvent.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList();
  }

  throw Exception('Unexpected response when loading personal best events.');
});
