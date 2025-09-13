// frontend/lib/core/models/lift_meta.dart

class LiftMeta {
  final String scenarioId; // backend id, e.g. "back_squat"
  final String displayName; // truncated UI label
  final String fullName; // original scenario name

  const LiftMeta({
    required this.scenarioId,
    required this.displayName,
    required this.fullName,
  });

  factory LiftMeta.fromScenario(Map<String, dynamic> scenarioJson) {
    final id = scenarioJson['id'] as String;
    final fullName = (scenarioJson['name'] as String?) ?? id;
    final displayName = _truncateName(fullName);
    return LiftMeta(
        scenarioId: id, displayName: displayName, fullName: fullName);
  }

  static String _truncateName(String name) {
    final titleized = _toTitleCase(name);
    if (titleized.length <= 10) return titleized;

    final parts = titleized.split(' ');
    if (parts.isNotEmpty) {
      final firstWord = parts.first;
      if (firstWord.length <= 10) {
        return firstWord;
      }
    }
    return titleized.substring(0, 10);
  }

  static String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+|_+'))
        .where((p) => p.isNotEmpty)
        .map((p) =>
            p[0].toUpperCase() +
            (p.length > 1 ? p.substring(1).toLowerCase() : ''))
        .join(' ');
  }
}
