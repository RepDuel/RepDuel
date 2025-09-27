// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/score_events_provider.dart'; // 👈 add this
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../utils/rank_utils.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

class RankedScreenData {
  final Map<String, dynamic> liftStandards;
  final Map<String, double> userHighScores;
  RankedScreenData({required this.liftStandards, required this.userHighScores});
}

class BenchmarkConfig {
  final String id;
  final String name;
  final List<LiftSpec> lifts;
  final Map<String, String> aliases;
  final bool showLiftsInBenchmarks;

  const BenchmarkConfig({
    required this.id,
    required this.name,
    required this.lifts,
    this.aliases = const {},
    this.showLiftsInBenchmarks = true,
  });
}

const BenchmarkConfig defaultBenchmarkConfig = BenchmarkConfig(
  id: 'powerlifting',
  name: 'Powerlifting',
  lifts: <LiftSpec>[
    LiftSpec(key: 'bench', scenarioId: 'barbell_bench_press', name: 'Bench'),
    LiftSpec(key: 'squat', scenarioId: 'back_squat', name: 'Squat'),
    LiftSpec(key: 'deadlift', scenarioId: 'deadlift', name: 'Deadlift'),
  ],
);

const List<BenchmarkConfig> benchmarkConfigs = <BenchmarkConfig>[
  defaultBenchmarkConfig,
];

final Map<String, BenchmarkConfig> _benchmarkConfigMap = {
  for (final config in benchmarkConfigs) config.id: config,
};

double _lbPerKg(double kg) => kg * 2.2046226218;

// NOTE: make standards provider react to scoreEvents/version & auth changes.
final liftStandardsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // 🔄 whenever scores/units/gender/weight change, providers that watch this rebuild
  ref.watch(scoreEventsProvider);

  final user = ref.watch(authProvider.select((s) => s.valueOrNull?.user));
  if (user == null) throw Exception("User not authenticated.");

  final unit = user.preferredUnit;
  final bodyweightKg = user.weight ?? 90.7; // stored in kg
  final gender = (user.gender ?? 'male').toLowerCase();
  final bodyweightForRequest =
      unit == 'lbs' ? _lbPerKg(bodyweightKg) : bodyweightKg;

  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get(
    '/standards/$bodyweightForRequest?gender=$gender&unit=$unit',
  );
  return (response.data as Map).cast<String, dynamic>();
});

final selectedBenchmarkConfigIdProvider =
    StateProvider.autoDispose<String>((ref) => defaultBenchmarkConfig.id);

// NOTE: also make highscores reactive to scoreEvents & the current user id.
final highScoresProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  // 🔄 refetch highscores whenever we bump this
  ref.watch(scoreEventsProvider);
  final configId = ref.watch(selectedBenchmarkConfigIdProvider);
  final config = _benchmarkConfigMap[configId] ?? defaultBenchmarkConfig;

  final user = ref.watch(authProvider.select((s) => s.valueOrNull?.user));
  if (user == null) return {};
  final client = ref.watch(privateHttpClientProvider);
  final scoreFutures = config.lifts
      .map((spec) => client
          .get('/scores/user/${user.id}/scenario/${spec.scenarioId}/highscore')
          .then((res) => (res.data['score_value'] as num?)?.toDouble() ?? 0.0)
          .catchError((_) => 0.0))
      .toList();
  final scores = await Future.wait(scoreFutures);
  final keys = config.lifts.map((spec) => spec.key);
  return Map.fromIterables(keys, scores);
});

final rankedScreenDataProvider =
    FutureProvider.autoDispose<RankedScreenData>((ref) async {
  final standards = await ref.watch(liftStandardsProvider.future);
  final highScores = await ref.watch(highScoresProvider.future);
  return RankedScreenData(liftStandards: standards, userHighScores: highScores);
});

class RankedScreen extends ConsumerStatefulWidget {
  const RankedScreen({super.key});
  @override
  ConsumerState<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends ConsumerState<RankedScreen> {
  bool _showBenchmarks = false;

  @override
  Widget build(BuildContext context) {
    final selectedConfigId = ref.watch(selectedBenchmarkConfigIdProvider);
    final selectedConfig =
        _benchmarkConfigMap[selectedConfigId] ?? defaultBenchmarkConfig;
    final selectedLifts = selectedConfig.lifts;
    // keep energy up-to-date (same as before)
    ref.listen<AsyncValue<RankedScreenData>>(rankedScreenDataProvider,
        (previous, next) {
      if (next is! AsyncData) return;
      final data = next.value;
      final user = ref.read(authProvider).valueOrNull?.user;
      if (data == null || user == null) return;

      final unit = user.preferredUnit;
      final weightMultiplier = unit == 'lbs' ? 2.2046226218 : 1.0;

      final energies = data.userHighScores.entries.map((entry) {
        final scoreWithMultiplier = entry.value * weightMultiplier;
        return getInterpolatedEnergy(
          score: scoreWithMultiplier,
          thresholds: data.liftStandards,
          liftKey: entry.key,
          userMultiplier: 1.0,
        );
      }).toList();

      if (energies.isNotEmpty) {
        final averageEnergy =
            energies.reduce((a, b) => a + b) / energies.length;
        final roundedEnergy = averageEnergy.round();

        final entries = rankEnergy.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        String overallRank = 'Unranked';
        for (final entry in entries) {
          if (averageEnergy >= entry.value) {
            overallRank = entry.key;
            break;
          }
        }

        if (roundedEnergy != user.energy.round()) {
          final client = ref.read(privateHttpClientProvider);
          client.post('/energy/submit', data: {
            'user_id': user.id,
            'energy': roundedEnergy.toDouble(),
            'rank': overallRank,
          }).then((_) {
            ref.read(authProvider.notifier).updateLocalUserEnergy(
                  newEnergy: roundedEnergy.toDouble(),
                  newRank: overallRank,
                );
          }).catchError((_) {});
        }
      }
    });

    final rankedDataAsync = ref.watch(rankedScreenDataProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(rankedScreenDataProvider.future),
        child: rankedDataAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(
              child: ErrorDisplay(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(rankedScreenDataProvider))),
          data: (data) {
            final liftKeyToScenario = {
              for (final l in selectedLifts) l.key: l.scenarioId
            };
            final user = ref.watch(authProvider).valueOrNull?.user;
            final unit = user?.preferredUnit ?? 'lbs';
            final weightMultiplier = unit == 'lbs' ? 2.2046226218 : 1.0;
            final energyDataPoints = selectedLifts
                .map((lift) {
                  final score =
                      (data.userHighScores[lift.key] ?? 0.0) * weightMultiplier;
                  final energy = getInterpolatedEnergy(
                    score: score,
                    thresholds: data.liftStandards,
                    liftKey: lift.key,
                    userMultiplier: 1.0,
                  );
                  final rank = _getRankForEnergy(energy);
                  final color = getRankColor(rank);
                  final label = lift.name ?? lift.shortLabel ?? lift.key;
                  return _EnergyDataPoint(
                    label: label,
                    energy: energy,
                    color: color,
                    rank: rank,
                  );
                })
                .where((point) => point.energy >= 0)
                .toList();
            if (_showBenchmarks) {
              return BenchmarksTable(
                standards: data.liftStandards,
                onViewRankings: () => setState(() => _showBenchmarks = false),
                lifts: selectedLifts,
                showLifts: selectedConfig.showLiftsInBenchmarks,
                header: benchmarkConfigs.length > 1
                    ? _buildConfigSelector(context, selectedConfigId)
                    : null,
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (benchmarkConfigs.length > 1)
                    _buildConfigSelector(context, selectedConfigId),
                  RankingTable(
                    liftStandards: data.liftStandards,
                    lifts: selectedLifts,
                    userHighScores: data.userHighScores,
                    aliases: selectedConfig.aliases.isEmpty
                        ? null
                        : selectedConfig.aliases,
                    onViewBenchmarks: () =>
                        setState(() => _showBenchmarks = true),
                    onLiftTapped: (liftKey) async {
                      final scenarioId = liftKeyToScenario[liftKey];
                      if (scenarioId == null) return;
                      final shouldRefresh = await context
                          .push<bool>('/scenario/$scenarioId', extra: liftKey);
                      if (shouldRefresh == true && mounted) {
                        // option A: nuke the joined provider
                        ref.invalidate(rankedScreenDataProvider);
                        // also bump the global version in case other screens rely on it
                        ref.read(scoreEventsProvider.notifier).state++;
                        // pull user again (energy, etc.)
                        await ref.read(authProvider.notifier).refreshUserData();
                      }
                    },
                    onLeaderboardTapped: (scenarioId) {
                      final lift = selectedLifts.firstWhere(
                        (l) => l.scenarioId == scenarioId,
                        orElse: () => const LiftSpec(
                          key: 'lift',
                          scenarioId: '',
                        ),
                      );
                      final liftDisplayName =
                          lift.name ?? lift.shortLabel ?? lift.key;
                      context.pushNamed(
                        'liftLeaderboard',
                        pathParameters: {'scenarioId': scenarioId},
                        queryParameters: {'liftName': liftDisplayName},
                      );
                    },
                    onEnergyLeaderboardTapped: () =>
                        context.pushNamed('energyLeaderboard'),
                  ),
                  if (energyDataPoints.length >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      child: _EnergySpiderChart(
                        dataPoints: energyDataPoints,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConfigSelector(BuildContext context, String selectedId) {
    if (benchmarkConfigs.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Text(
            'Benchmark set',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: selectedId,
              dropdownColor: Colors.grey[900],
              iconEnabledColor: Colors.white,
              style: const TextStyle(color: Colors.white),
              underline: Container(
                height: 1,
                color: Colors.white24,
              ),
              items: [
                for (final config in benchmarkConfigs)
                  DropdownMenuItem<String>(
                    value: config.id,
                    child: Text(config.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == selectedId) return;
                ref.read(selectedBenchmarkConfigIdProvider.notifier).state =
                    value;
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _getRankForEnergy(double energy) {
  if (energy <= 0) return 'Unranked';
  final sortedRanks = rankEnergy.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (var i = sortedRanks.length - 1; i >= 0; i--) {
    if (energy >= sortedRanks[i].value) {
      return sortedRanks[i].key;
    }
  }
  return 'Unranked';
}

class _EnergyDataPoint {
  final String label;
  final double energy;
  final Color color;
  final String rank;

  const _EnergyDataPoint({
    required this.label,
    required this.energy,
    required this.color,
    required this.rank,
  });
}

class _RankRing {
  final double energy;
  final Color color;

  const _RankRing({required this.energy, required this.color});
}

class _EnergySpiderChart extends StatelessWidget {
  const _EnergySpiderChart({required this.dataPoints});

  final List<_EnergyDataPoint> dataPoints;

  static const double _maxEnergy = 1200.0;

  List<_RankRing> _buildRings() {
    final sortedRanks = rankEnergy.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final rings = <_RankRing>[
      for (final entry in sortedRanks)
        _RankRing(
          energy: entry.value.toDouble().clamp(0.0, _maxEnergy),
          color: getRankColor(entry.key),
        ),
    ];
    if (rings.isEmpty || rings.last.energy < _maxEnergy) {
      rings.add(
        _RankRing(
          energy: _maxEnergy,
          color: rings.isEmpty ? Colors.white54 : rings.last.color,
        ),
      );
    }
    return rings;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final size = math.min(maxWidth, 320.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: size,
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _SpiderChartPainter(
                      dataPoints: dataPoints,
                      rings: _buildRings(),
                      maxEnergy: _maxEnergy,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final point in dataPoints)
                  _LegendItem(
                    color: point.color,
                    label:
                        '${point.label}: ${point.energy.toStringAsFixed(0)} (${point.rank})',
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _SpiderChartPainter extends CustomPainter {
  _SpiderChartPainter({
    required this.dataPoints,
    required this.rings,
    required this.maxEnergy,
  });

  final List<_EnergyDataPoint> dataPoints;
  final List<_RankRing> rings;
  final double maxEnergy;

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.85;
    final angleStep = 2 * math.pi / dataPoints.length;

    _drawRings(canvas, center, radius);
    _drawAxes(canvas, center, radius, angleStep);
    _drawData(canvas, center, radius, angleStep);
    _drawLabels(canvas, center, radius, angleStep);
  }

  void _drawRings(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    for (final ring in rings) {
      final normalized = (ring.energy / maxEnergy).clamp(0.0, 1.0);
      if (normalized <= 0) continue;
      final ringRadius = radius * normalized;
      final fillPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = ring.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, ringRadius, fillPaint);
      canvas.drawCircle(center, ringRadius, strokePaint);
    }
  }

  void _drawAxes(
    Canvas canvas,
    Offset center,
    double radius,
    double angleStep,
  ) {
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (int i = 0; i < dataPoints.length; i++) {
      final angle = -math.pi / 2 + angleStep * i;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, axisPaint);
    }
  }

  void _drawData(
    Canvas canvas,
    Offset center,
    double radius,
    double angleStep,
  ) {
    final offsets = <Offset>[];
    final normalizedValues = <double>[];
    final angles = <double>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      final normalized = (point.energy / maxEnergy).clamp(0.0, 1.0);
      final angle = -math.pi / 2 + angleStep * i;
      final offset = center +
          Offset(
                math.cos(angle),
                math.sin(angle),
              ) *
              radius *
              normalized;
      offsets.add(offset);
      normalizedValues.add(normalized);
      angles.add(angle);
    }

    if (offsets.length >= 3) {
      final fillColor = _averageColor(
        dataPoints.map((point) => point.color).toList(),
      ).withValues(alpha: 0.18);

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final path = _buildCurvedPath(
        center: center,
        offsets: offsets,
        normalizedValues: normalizedValues,
        radius: radius,
        angles: angles,
        angleStep: angleStep,
      );

      if (path != null) {
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }

    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      final offset = offsets[i];
      final paint = Paint()
        ..color = point.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(offset, 5, paint);
    }
  }

  Path? _buildCurvedPath({
    required Offset center,
    required List<Offset> offsets,
    required List<double> normalizedValues,
    required double radius,
    required List<double> angles,
    required double angleStep,
  }) {
    if (offsets.length < 3) return null;
    final first = normalizedValues.first;
    final allEqual =
        normalizedValues.every((value) => (value - first).abs() < 1e-4);

    if (allEqual) {
      if (first <= 0) {
        return null;
      }
      final circleRadius = radius * first;
      return Path()
        ..addOval(Rect.fromCircle(center: center, radius: circleRadius));
    }

    return _buildPolarSplinePath(
      center: center,
      normalizedValues: normalizedValues,
      angles: angles,
      baseRadius: radius,
      angleStep: angleStep,
    );
  }

  Path _buildPolarSplinePath({
    required Offset center,
    required List<double> normalizedValues,
    required List<double> angles,
    required double baseRadius,
    required double angleStep,
  }) {
    final count = normalizedValues.length;
    final radii = List<double>.generate(
      count,
      (index) => normalizedValues[index] * baseRadius,
    );

    final derivatives = List<double>.generate(count, (index) {
      final prev = (index - 1 + count) % count;
      final next = (index + 1) % count;
      return (radii[next] - radii[prev]) / (2 * angleStep);
    });

    final path = Path();
    final start = _polarToOffset(center, angles[0], radii[0]);
    path.moveTo(start.dx, start.dy);

    for (int i = 0; i < count; i++) {
      final currentAngle = angles[i];
      final nextIndex = (i + 1) % count;
      final nextAngleBase = angles[nextIndex];
      final adjustedNextAngle =
          nextIndex == 0 ? nextAngleBase + 2 * math.pi : nextAngleBase;

      final currentRadius = radii[i];
      final nextRadius = radii[nextIndex];
      final currentDerivative = derivatives[i];
      final nextDerivative = derivatives[nextIndex];

      final p0 = _polarToOffset(center, currentAngle, currentRadius);
      final p1 = _polarToOffset(center, nextAngleBase, nextRadius);
      final dp0 =
          _polarDerivative(currentAngle, currentRadius, currentDerivative);
      final dp1 = _polarDerivative(nextAngleBase, nextRadius, nextDerivative);
      final deltaTheta = adjustedNextAngle - currentAngle;

      final control1 = p0 + dp0 * (deltaTheta / 3.0);
      final control2 = p1 - dp1 * (deltaTheta / 3.0);

      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p1.dx,
        p1.dy,
      );
    }

    path.close();
    return path;
  }

  Offset _polarToOffset(Offset center, double angle, double radius) {
    return center +
        Offset(
          math.cos(angle) * radius,
          math.sin(angle) * radius,
        );
  }

  Offset _polarDerivative(double angle, double radius, double radialSlope) {
    final dx = radialSlope * math.cos(angle) - radius * math.sin(angle);
    final dy = radialSlope * math.sin(angle) + radius * math.cos(angle);
    return Offset(dx, dy);
  }

  Color _averageColor(List<Color> colors) {
    if (colors.isEmpty) {
      return Colors.white;
    }
    double r = 0;
    double g = 0;
    double b = 0;
    for (final color in colors) {
      r += color.r;
      g += color.g;
      b += color.b;
    }
    final count = colors.length.toDouble();
    final red = ((r / count) * 255).round().clamp(0, 255).toInt();
    final green = ((g / count) * 255).round().clamp(0, 255).toInt();
    final blue = ((b / count) * 255).round().clamp(0, 255).toInt();
    return Color.fromARGB(
      255,
      red,
      green,
      blue,
    );
  }

  void _drawLabels(
    Canvas canvas,
    Offset center,
    double radius,
    double angleStep,
  ) {
    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      final angle = -math.pi / 2 + angleStep * i;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final labelPosition = center + direction * (radius + 12);
      final textPainter = TextPainter(
        text: TextSpan(
          text: point.label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);
      final offset =
          labelPosition - Offset(textPainter.width / 2, textPainter.height / 2);
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _SpiderChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.rings != rings ||
        oldDelegate.maxEnergy != maxEnergy;
  }
}
