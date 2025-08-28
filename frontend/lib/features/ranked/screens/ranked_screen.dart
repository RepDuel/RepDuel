// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

// Data model for this screen's combined data
class RankedScreenData {
  final Map<String, dynamic> liftStandards;
  final Map<String, double> userHighScores;
  RankedScreenData({required this.liftStandards, required this.userHighScores});
}

// Provider for fetching public lift standards
final liftStandardsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // This provider will re-run if authProvider changes, ensuring we have the latest user stats.
  final user = ref.watch(authProvider.select((state) => state.valueOrNull?.user));
  if (user == null) throw Exception("User not authenticated.");

  final bodyweightKg = user.weight ?? 90.7;
  final gender = user.gender?.toLowerCase() ?? 'male';
  
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/standards/$bodyweightKg?gender=$gender');
  return response.data as Map<String, dynamic>;
});

// Provider for fetching the user's high scores
final highScoresProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final user = ref.watch(authProvider.select((state) => state.valueOrNull?.user));
  if (user == null) return {}; // If no user, no scores

  final client = ref.watch(privateHttpClientProvider);
  final liftIds = ['back_squat', 'barbell_bench_press', 'deadlift'];
  final liftNames = ['Squat', 'Bench', 'Deadlift'];

  final scoreFutures = liftIds.map((id) => 
    client.get('/scores/user/${user.id}/scenario/$id/highscore')
      .then((res) => (res.data['score_value'] as num?)?.toDouble() ?? 0.0)
      .catchError((_) => 0.0) // Gracefully handle 404s by returning 0
  );
  
  final scores = await Future.wait(scoreFutures);
  return Map.fromIterables(liftNames, scores);
});

// Provider that combines the data from the two providers above
final rankedScreenDataProvider = FutureProvider.autoDispose<RankedScreenData>((ref) async {
  // By awaiting the .future, this provider will wait for both dependencies to complete.
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
    final rankedDataAsync = ref.watch(rankedScreenDataProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(rankedScreenDataProvider.future),
        child: rankedDataAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.invalidate(rankedScreenDataProvider))),
          data: (data) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _showBenchmarks
                  ? BenchmarksTable(
                      standards: data.liftStandards,
                      onViewRankings: () => setState(() => _showBenchmarks = false),
                    )
                  : RankingTable(
                      liftStandards: data.liftStandards,
                      userHighScores: data.userHighScores,
                      onViewBenchmarks: () => setState(() => _showBenchmarks = true),
                      // --- THIS IS THE FIX ---
                      onLiftTapped: (liftName) async {
                        final scenarioMap = {'Squat': 'back_squat', 'Bench': 'barbell_bench_press', 'Deadlift': 'deadlift'};
                        final scenarioId = scenarioMap[liftName];
                        if (scenarioId == null) return;
                        
                        // Correctly navigate to the single-set `ScenarioScreen` by path.
                        final shouldRefresh = await context.push<bool>(
                          '/scenario/$scenarioId',
                          extra: liftName,
                        );

                        // If the user submits a new score and comes back, refresh the high scores.
                        if (shouldRefresh == true && mounted) {
                           ref.invalidate(highScoresProvider);
                           ref.invalidate(rankedScreenDataProvider);
                        }
                      },
                      // --- END OF FIX ---
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