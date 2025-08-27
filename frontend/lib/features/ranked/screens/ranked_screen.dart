// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../utils/rank_utils.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

// --- Data Models & Providers (These are correct and remain the same) ---
class RankedScreenData {
  final Map<String, dynamic> liftStandards;
  final Map<String, double> userHighScores;
  RankedScreenData({required this.liftStandards, required this.userHighScores});
}

final liftStandardsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull?.user;
  if (user == null) throw Exception("User not authenticated");
  final bodyweightKg = user.weight ?? 90.7;
  final gender = user.gender?.toLowerCase() ?? 'male';
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/standards/$bodyweightKg?gender=$gender');
  return response.data as Map<String, dynamic>;
});

final highScoresProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull?.user;
  if (user == null) return {};
  final client = ref.watch(privateHttpClientProvider);
  final liftIds = ['back_squat', 'barbell_bench_press', 'deadlift'];
  final liftNames = ['Squat', 'Bench', 'Deadlift'];
  final scoreFutures = liftIds.map((id) => 
    client.get('/scores/user/${user.id}/scenario/$id/highscore')
      .then((res) => (res.data['score_value'] as num?)?.toDouble() ?? 0.0)
      .catchError((_) => 0.0)
  );
  final scores = await Future.wait(scoreFutures);
  return Map.fromIterables(liftNames, scores);
});

final rankedScreenDataProvider = FutureProvider.autoDispose<RankedScreenData>((ref) async {
  final standards = await ref.watch(liftStandardsProvider.future);
  final highScores = await ref.watch(highScoresProvider.future);
  return RankedScreenData(liftStandards: standards, userHighScores: highScores);
});

// --- THE WIDGET ---
class RankedScreen extends ConsumerStatefulWidget {
  const RankedScreen({super.key});

  @override
  ConsumerState<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends ConsumerState<RankedScreen> {
  bool _showBenchmarks = false;

  @override
  Widget build(BuildContext context) {
    // THIS IS THE FIX: A listener for handling side-effects like submitting data.
    ref.listen<AsyncValue<RankedScreenData>>(rankedScreenDataProvider, (previous, next) {
      // This condition ensures the action runs ONLY when we get data for the first time.
      if (next is AsyncData && (previous is! AsyncData || previous is AsyncError)) {
        final data = next.value;
        final user = ref.read(authProvider).valueOrNull?.user;
        if (data == null || user == null) return;
        
        // Re-implement the energy calculation logic here for the side-effect.
        final weightMultiplier = user.weightMultiplier;
        final energies = data.userHighScores.entries.map((entry) {
          final liftName = entry.key;
          final scoreInKg = entry.value;
          final scoreWithMultiplier = scoreInKg * weightMultiplier;
          return RankUtils.getInterpolatedEnergy(
              score: scoreWithMultiplier,
              thresholds: data.liftStandards,
              liftKey: liftName.toLowerCase(),
              userMultiplier: weightMultiplier);
        }).toList();

        if (energies.isNotEmpty) {
          final averageEnergy = energies.reduce((a, b) => a + b) / energies.length;
          final entries = RankUtils.rankEnergy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          String overallRank = 'Unranked';
          for (final entry in entries) {
            if (averageEnergy >= entry.value) {
              overallRank = entry.key;
              break;
            }
          }
          
          // Submit the calculated data as a one-time side effect.
          final client = ref.read(privateHttpClientProvider);
          client.post('/energy/submit', data: {
            'user_id': user.id,
            'energy': averageEnergy.round(),
            'rank': overallRank,
          }).then((_) {
            ref.read(authProvider.notifier).refreshUserData();
          }).catchError((e) {
            debugPrint("Error submitting energy: $e");
          });
        }
      }
    });

    // The rest of the build method watches for UI state changes.
    final rankedDataAsync = ref.watch(rankedScreenDataProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(rankedScreenDataProvider.future),
        child: rankedDataAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.refresh(rankedScreenDataProvider.future))),
          data: (data) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _showBenchmarks
                  ? BenchmarksTable(
                      standards: data.liftStandards,
                      onViewRankings: () => setState(() => _showBenchmarks = false),
                    )
                  // The call to RankingTable is now simpler and has no onEnergyComputed.
                  : RankingTable(
                      liftStandards: data.liftStandards,
                      userHighScores: data.userHighScores,
                      onViewBenchmarks: () => setState(() => _showBenchmarks = true),
                      onLiftTapped: (liftName) {
                        final scenarioMap = {'Squat': 'back_squat', 'Bench': 'barbell_bench_press', 'Deadlift': 'deadlift'};
                        // This navigation might need adjustment based on your router setup.
                        context.push('/exercise-play-by-id/${scenarioMap[liftName]}');
                      },
                      onLeaderboardTapped: (scenarioId) => context.push('/leaderboard/$scenarioId'),
                      onEnergyLeaderboardTapped: () => context.push('/leaderboard/energy'),
                    ),
            );
          },
        ),
      ),
    );
  }
}