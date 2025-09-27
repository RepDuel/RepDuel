// frontend/lib/features/ranked/screens/ranked_screen.dart

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
                      final shouldRefresh = await context.push<bool>(
                          '/scenario/$scenarioId',
                          extra: liftKey);
                      if (shouldRefresh == true && mounted) {
                        // option A: nuke the joined provider
                        ref.invalidate(rankedScreenDataProvider);
                        // also bump the global version in case other screens rely on it
                        ref.read(scoreEventsProvider.notifier).state++;
                        // pull user again (energy, etc.)
                        await ref
                            .read(authProvider.notifier)
                            .refreshUserData();
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
