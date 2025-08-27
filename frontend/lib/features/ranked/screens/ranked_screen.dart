// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/features/ranked/models/result_screen_data.dart'; // Import the model
import 'package:repduel/features/ranked/screens/result_screen.dart';

import '../../../core/models/routine_details.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

class RankedScreenData {
  final Map<String, dynamic> liftStandards;
  final Map<String, double> userHighScores;
  RankedScreenData({required this.liftStandards, required this.userHighScores});
}

final liftStandardsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  return authState.when(
    data: (data) async {
      if (data.user == null) throw Exception("User not authenticated");
      final user = data.user!;
      final bodyweightKg = user.weight ?? 90.7;
      final gender = user.gender?.toLowerCase() ?? 'male';
      final client = ref.watch(publicHttpClientProvider);
      final response = await client.get('/standards/$bodyweightKg?gender=$gender');
      return response.data as Map<String, dynamic>;
    },
    loading: () => Future.value(<String, dynamic>{}),
    error: (e, s) => throw e,
  );
});

final highScoresProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final authState = ref.watch(authProvider);
  return authState.when(
    data: (data) async {
      if (data.user == null) return {};
      final user = data.user!;
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
    },
    loading: () => Future.value(<String, double>{}),
    error: (e, s) => throw e,
  );
});

final rankedScreenDataProvider = FutureProvider.autoDispose<RankedScreenData>((ref) async {
  final standards = await ref.watch(liftStandardsProvider.future);
  final highScores = await ref.watch(highScoresProvider.future);
  if (standards.isEmpty || highScores.isEmpty && ref.watch(authProvider).isLoading) {
    // A simple guard to wait for the dependencies to resolve properly
    return Completer<RankedScreenData>().future;
  }
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
    final rankedDataAsync = ref.watch(rankedScreenDataProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(rankedScreenDataProvider.future),
        child: rankedDataAsync.when(
          loading: () => const Center(child: LoadingSpinner()),
          error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.refresh(rankedScreenDataProvider))),
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
                      onLiftTapped: (liftName) async {
                        final scenarioMap = {'Squat': 'back_squat', 'Bench': 'barbell_bench_press', 'Deadlift': 'deadlift'};
                        final scenarioId = scenarioMap[liftName];
                        if (scenarioId == null) return;
                        
                        // We need to fetch the exercise details before navigating
                        final client = ref.read(publicHttpClientProvider);
                        try {
                           final response = await client.get('/scenarios/$scenarioId');
                           final scenario = Scenario.fromJson(response.data);
                           final shouldRefresh = await context.push<bool>('/exercise-play', extra: scenario);
                           if (shouldRefresh == true && mounted) {
                              ref.invalidate(rankedScreenDataProvider);
                           }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not load exercise: $e")));
                        }
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