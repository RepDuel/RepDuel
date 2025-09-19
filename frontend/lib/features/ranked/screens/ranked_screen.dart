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

// NOTE: also make highscores reactive to scoreEvents & the current user id.
final highScoresProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  // 🔄 refetch highscores whenever we bump this
  ref.watch(scoreEventsProvider);

  final user = ref.watch(authProvider.select((s) => s.valueOrNull?.user));
  if (user == null) return {};
  final client = ref.watch(privateHttpClientProvider);
  final liftIds = ['back_squat', 'barbell_bench_press', 'deadlift'];
  final liftKeys = ['squat', 'bench', 'deadlift'];
  final scoreFutures = liftIds
      .map((id) => client
          .get('/scores/user/${user.id}/scenario/$id/highscore')
          .then((res) => (res.data['score_value'] as num?)?.toDouble() ?? 0.0)
          .catchError((_) => 0.0))
      .toList();
  final scores = await Future.wait(scoreFutures);
  return Map.fromIterables(liftKeys, scores);
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

  static const defaultLifts = <LiftSpec>[
    LiftSpec(key: 'bench', scenarioId: 'barbell_bench_press', name: 'Bench'),
    LiftSpec(key: 'squat', scenarioId: 'back_squat', name: 'Squat'),
    LiftSpec(key: 'deadlift', scenarioId: 'deadlift', name: 'Deadlift'),
  ];

  @override
  Widget build(BuildContext context) {
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
              for (final l in defaultLifts) l.key: l.scenarioId
            };
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _showBenchmarks
                  ? BenchmarksTable(
                      standards: data.liftStandards,
                      onViewRankings: () =>
                          setState(() => _showBenchmarks = false),
                    )
                  : RankingTable(
                      liftStandards: data.liftStandards,
                      lifts: defaultLifts,
                      userHighScores: data.userHighScores,
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
                        final liftName = defaultLifts
                            .firstWhere((l) => l.scenarioId == scenarioId,
                                orElse: () =>
                                    const LiftSpec(key: 'lift', scenarioId: ''))
                            .name;
                        context.push(
                            '/leaderboard/$scenarioId?liftName=${liftName ?? ''}');
                      },
                      onEnergyLeaderboardTapped: () =>
                          context.pushNamed('energyLeaderboard'),
                    ),
            );
          },
        ),
      ),
    );
  }
}
