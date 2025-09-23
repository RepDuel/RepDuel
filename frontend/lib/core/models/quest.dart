// frontend/lib/core/models/quest.dart

enum QuestCadence { daily, weekly, limited }

enum QuestMetric { workoutsCompleted, activeMinutes }

enum QuestStatus { active, completed, claimed, expired }

QuestCadence _parseCadence(String? value) {
  switch (value) {
    case 'weekly':
      return QuestCadence.weekly;
    case 'limited':
      return QuestCadence.limited;
    case 'daily':
    default:
      return QuestCadence.daily;
  }
}

QuestMetric _parseMetric(String? value) {
  switch (value) {
    case 'active_minutes':
      return QuestMetric.activeMinutes;
    case 'workouts_completed':
    default:
      return QuestMetric.workoutsCompleted;
  }
}

QuestStatus _parseStatus(String? value) {
  switch (value) {
    case 'completed':
      return QuestStatus.completed;
    case 'claimed':
      return QuestStatus.claimed;
    case 'expired':
      return QuestStatus.expired;
    case 'active':
    default:
      return QuestStatus.active;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}

class QuestTemplateSummary {
  final String id;
  final String code;
  final String title;
  final String? description;
  final QuestCadence cadence;
  final QuestMetric metric;
  final int targetValue;
  final int rewardXp;
  final bool autoClaim;
  final DateTime? availableFrom;
  final DateTime? expiresAt;

  const QuestTemplateSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.cadence,
    required this.metric,
    required this.targetValue,
    required this.rewardXp,
    required this.autoClaim,
    required this.availableFrom,
    required this.expiresAt,
  });

  factory QuestTemplateSummary.fromJson(Map<String, dynamic> json) {
    return QuestTemplateSummary(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      cadence: _parseCadence(json['cadence']?.toString()),
      metric: _parseMetric(json['metric']?.toString()),
      targetValue: (json['target_value'] as num?)?.toInt() ?? 0,
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      autoClaim: json['auto_claim'] == true,
      availableFrom: _parseDate(json['available_from']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }
}

class QuestInstance {
  final String id;
  final QuestStatus status;
  final int progress;
  final int required;
  final double progressPct;
  final DateTime? availableFrom;
  final DateTime? expiresAt;
  final DateTime? cycleStart;
  final DateTime? cycleEnd;
  final DateTime? completedAt;
  final DateTime? rewardClaimedAt;
  final DateTime? lastProgressAt;
  final int rewardXp;
  final QuestTemplateSummary template;

  const QuestInstance({
    required this.id,
    required this.status,
    required this.progress,
    required this.required,
    required this.progressPct,
    required this.availableFrom,
    required this.expiresAt,
    required this.cycleStart,
    required this.cycleEnd,
    required this.completedAt,
    required this.rewardClaimedAt,
    required this.lastProgressAt,
    required this.rewardXp,
    required this.template,
  });

  bool get isCompleted =>
      status == QuestStatus.completed || status == QuestStatus.claimed;

  bool get isClaimed => status == QuestStatus.claimed;

  factory QuestInstance.fromJson(Map<String, dynamic> json) {
    final templateRaw = json['template'];
    if (templateRaw is! Map) {
      throw ArgumentError('Quest template is missing from quest payload');
    }
    return QuestInstance(
      id: json['id']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      required: (json['required'] as num?)?.toInt() ?? 0,
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0.0,
      availableFrom: _parseDate(json['available_from']),
      expiresAt: _parseDate(json['expires_at']),
      cycleStart: _parseDate(json['cycle_start']),
      cycleEnd: _parseDate(json['cycle_end']),
      completedAt: _parseDate(json['completed_at']),
      rewardClaimedAt: _parseDate(json['reward_claimed_at']),
      lastProgressAt: _parseDate(json['last_progress_at']),
      rewardXp: (json['reward_xp'] as num?)?.toInt() ?? 0,
      template: QuestTemplateSummary.fromJson(
        Map<String, dynamic>.from(templateRaw),
      ),
    );
  }
}
