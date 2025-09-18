// frontend/lib/features/ranked/utils/bodyweight_benchmarks.dart

import 'dart:math' as math;

const List<String> kRankOrder = [
  'Iron',
  'Bronze',
  'Silver',
  'Gold',
  'Platinum',
  'Diamond',
  'Jade',
  'Master',
  'Grandmaster',
  'Nova',
  'Astra',
  'Celestial',
];

double _asDouble(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is num) return value.toDouble();
  throw ArgumentError('Calibration missing "$key"');
}

Map<String, double> generateBodyweightBenchmarks(
  Map<String, dynamic> calibration,
  double bodyweightKg,
  {bool isFemale = false}) {
  if (bodyweightKg <= 0) {
    throw ArgumentError('bodyweightKg must be positive');
  }

  final t = math.max(0.0, math.min(1.0, (bodyweightKg - 50.0) / 90.0));

  final b50 = _asDouble(calibration, 'beginner_50');
  final e50 = _asDouble(calibration, 'elite_50');
  final b140 = _asDouble(calibration, 'beginner_140');
  final e140 = _asDouble(calibration, 'elite_140');
  final inter95 = _asDouble(calibration, 'intermediate_95');

  final beginnerBw = b50 + (b140 - b50) * t;
  final eliteBw = e50 + (e140 - e50) * t;
  final gap = eliteBw - beginnerBw;

  final t95 = (95.0 - 50.0) / 90.0;
  final beginner95 = b50 + (b140 - b50) * t95;
  final elite95 = e50 + (e140 - e50) * t95;
  final denom = elite95 - beginner95;

  double alpha;
  if (denom.abs() < 1e-9) {
    alpha = 0.6;
  } else {
    alpha = (inter95 - beginner95) / denom;
    alpha = math.max(0.0, math.min(1.0, alpha));
  }

  const lowRanks = [
    'Iron',
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Jade',
  ];
  const highRanks = ['Master', 'Grandmaster', 'Nova', 'Astra'];

  final fractions = <String, double>{};

  final stepsLow = lowRanks.length - 1;
  if (stepsLow <= 0) {
    for (final rank in lowRanks) {
      fractions[rank] = alpha;
    }
    fractions['Iron'] = 0.0;
  } else {
    for (var i = 0; i < lowRanks.length; i++) {
      fractions[lowRanks[i]] = alpha * (i / stepsLow);
    }
  }

  final stepsHigh = highRanks.length - 1;
  if (stepsHigh <= 0) {
    for (final rank in highRanks) {
      fractions[rank] = 1.0;
    }
  } else {
    final denom = highRanks.length.toDouble();
    for (var i = 0; i < highRanks.length; i++) {
      final fraction = alpha + (1.0 - alpha) * ((i + 1) / denom);
      fractions[highRanks[i]] = fraction;
    }
  }

  final thresholds = <String, double>{};
  final scale = isFemale ? 0.6 : 1.0;

  for (final rank in kRankOrder) {
    if (rank == 'Celestial') continue;
    final fraction = fractions[rank] ?? 0.0;
    thresholds[rank] = (beginnerBw + fraction * gap) * scale;
  }

  final astra = thresholds['Astra'] ?? (eliteBw * scale);
  final nova = thresholds['Nova'] ?? (astra - (gap * scale) / 5);
  thresholds['Celestial'] = astra + (astra - nova);

  return thresholds;
}
