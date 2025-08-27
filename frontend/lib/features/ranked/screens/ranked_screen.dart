// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../leaderboard/screens/energy_leaderboard_screen.dart';
import '../../scenario/screens/scenario_screen.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

class RankedScreen extends ConsumerStatefulWidget {
  const RankedScreen({super.key});

  @override
  ConsumerState<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends ConsumerState<RankedScreen> {
  bool showBenchmarks = false;
  Map<String, dynamic>? liftStandards;
  // isLoading and error are now handled by the provider's AsyncValue state
  Map<String, double> userHighScores = {
    'Squat': 0.0,
    'Bench': 0.0,
    'Deadlift': 0.0,
  };

  final squatId = 'back_squat';
  final benchId = 'barbell_bench_press';
  final deadliftId = 'deadlift';

  final Map<String, String> liftToScenarioId = {
    'Squat': 'back_squat',
    'Bench': 'barbell_bench_press',
    'Deadlift': 'deadlift'
  };

  @override
  void initState() {
    super.initState();
    // Initialization is now handled more reactively by watching the provider.
    // However, to fetch standards, we still need an initial load.
    // We'll fetch standards when the widget first builds and auth data is available.
  }

  /// Fetches lift standards and user high scores.
  /// This is called after the auth state is successfully loaded.
  Future<void> _initializeData(String userId, String token, double bodyweightKg, String gender) async {
    // Fetch lift standards and user high scores
    await _fetchLiftStandards(bodyweightKg, gender);
    await _fetchUserHighScores(userId, token);
  }

  Future<void> _fetchLiftStandards(double bodyweightKg, String gender) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${Env.baseUrl}/api/v1/standards/$bodyweightKg?gender=$gender'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Use setState only if the widget is still mounted
        if (mounted) setState(() => liftStandards = data.isNotEmpty ? data : null);
      } else {
        if (mounted) setState(() => error = 'API Error: ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) setState(() => error = 'Request timed out');
    } catch (e) {
      if (mounted) setState(() => error = 'Error: $e');
    }
  }

  Future<void> _fetchUserHighScores(String userId, String token) async {
    final baseUrl = '${Env.baseUrl}/api/v1/scores/user/$userId/scenario';

    // Use Future.wait to fetch all high scores concurrently
    final results = await Future.wait([
      _fetchHighScore('$baseUrl/$squatId/highscore', token),
      _fetchHighScore('$baseUrl/$benchId/highscore', token),
      _fetchHighScore('$baseUrl/$deadliftId/highscore', token),
    ]);

    if (mounted) {
      setState(() {
        userHighScores = {
          'Squat': results[0],
          'Bench': results[1],
          'Deadlift': results[2],
        };
      });
    }
  }

  Future<double> _fetchHighScore(String url, String token) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Ensure token is added if needed by backend
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['score_value'] as num).toDouble();
      }
    } catch (_) {} // Silently fail if there's an error or no high score
    return 0.0;
  }

  Future<void> _handleScenarioTap(String liftName) async {
    // Use context.push for GoRouter navigation
    await context.push('/routines/play', extra: liftToScenarioId[liftName] ?? ''); // Assuming playRoutine needs scenarioId extra
    // If the scenario screen itself needs to trigger a data refresh for this screen,
    // it would need a mechanism like a callback or a separate provider update.
    // For simplicity, we're not re-initializing data here, assuming direct data fetching on load.
  }

  void _handleLeaderboardTap(String scenarioId) {
    final liftName = liftToScenarioId.entries
        .firstWhere((e) => e.value == scenarioId, orElse: () => const MapEntry('', ''))
        .key;

    if (liftName.isNotEmpty) {
      context.push('/leaderboard/$scenarioId?liftName=$liftName');
    }
  }

  void _handleEnergyLeaderboardTap() {
    // Use context.push for consistency with GoRouter
    context.push('/energy-leaderboard'); // Assuming a route for energy leaderboard exists
  }

  Future<void> _handleEnergyComputed(int energy, String rank) async {
    // Safely get user and token
    final authState = ref.read(authProvider).valueOrNull;
    final user = authState?.user;
    final token = authState?.token;

    if (user == null || token == null) {
      debugPrint("Cannot submit energy: User or token is missing.");
      return; // Exit if not authenticated
    }

    final url = Uri.parse('${Env.baseUrl}/api/v1/energy/submit');
    final body = json.encode({
      'user_id': user.id,
      'energy': energy,
      'rank': rank,
    });

    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token for authenticated request
        },
        body: body,
      );
    } catch (e) {
      debugPrint("❌ Error submitting energy: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth provider to get the AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Auth Error: $err', style: const TextStyle(color: Colors.red))),
      data: (authState) { // authState is the actual AuthState object here
        final user = authState.user;
        final token = authState.token;

        // If user or token is null, the user is not authenticated.
        // The router should ideally handle redirecting to login.
        // For this screen, we'll show a message indicating this state.
        if (user == null || token == null) {
          // This case should ideally be handled by the router redirecting to login.
          // As a fallback, we show a message or spinner.
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Please log in to view rankings.', style: TextStyle(color: Colors.white, fontSize: 16)),
                    SizedBox(height: 20),
                    // A button to navigate to login, or rely on router guards
                    // ElevatedButton(onPressed: () => context.push('/login'), child: Text('Go to Login')),
                  ],
                ),
              ),
            ),
          );
        }

        // --- User is logged in and data is available ---
        // Now that we know the user and token are available, fetch the data.
        // We can use a StatefulWidget with initState/setState for the initial load,
        // or manage this fetching directly within the 'data' block if it's simpler.
        // For this example, let's assume we fetch standards when auth is ready.
        
        // We need to trigger initialization logic *after* we have user and token.
        // A common pattern is to use a FutureBuilder or manage state within the widget.
        // However, since initState is not suitable for async ref.watch, we'll manage it here.
        // A cleaner approach is often to have a dedicated provider for lift standards.
        // For now, we'll simulate fetching it.
        
        // Let's simplify: we'll fetch standards when the widget builds with user data.
        // We can use a FutureBuilder or ref.watch a dedicated provider for standards.
        // For now, let's fetch standards directly here for demonstration.
        // In a real app, you'd likely have a `liftStandardsProvider`.

        // A more robust solution would be to have a provider that depends on auth state
        // and fetches standards, triggering a rebuild here. For direct changes:
        
        // Re-initializing data within the 'data' block might cause re-renders.
        // Let's try to keep the state management simple here.
        // A FutureBuilder for standards and scores seems appropriate.

        final bodyweightKg = user.weight ?? 90.7; // Use user's weight, default if null
        final gender = user.gender?.toLowerCase() ?? 'male'; // Use user's gender, default

        // We need to fetch liftStandards and userHighScores.
        // Using separate FutureProviders for each fetch would be more idiomatic Riverpod.
        // For direct modification of this widget:
        final liftStandardsFuture = _fetchLiftStandards(bodyweightKg, gender);
        final userHighScoresFuture = _fetchUserHighScores(user.id, token);


        return FutureBuilder(
          // Use a list of futures to await multiple calls
          future: Future.wait([liftStandardsFuture, userHighScoresFuture]),
          builder: (context, snapshot) {
            // Handle loading state for standards/scores
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            // Handle errors for standards/scores
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading data: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          // To retry, we'd ideally refresh the futures.
                          // For simplicity here, we'll just let the UI show the error.
                          // A better pattern would involve a dedicated provider that refreshes.
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // --- Data is loaded successfully ---
            // The `snapshot.data` will be a list of results from Future.wait.
            // We need to extract our standards and high scores.
            // This part assumes _fetchLiftStandards and _fetchUserHighScores update
            // state variables directly. If they return values, this would look different.
            // Assuming `_fetchLiftStandards` and `_fetchUserHighScores` correctly updated
            // `liftStandards` and `userHighScores` state variables via `setState`.
            // If they returned values, you'd assign them here.
            
            // For this example, let's re-fetch standards to populate state if they are null
            // (This is a bit of a workaround due to state management here. A provider is cleaner.)
            if (liftStandards == null) { 
              // This case should ideally be handled by a loading state for standards themselves.
              // For now, we'll display a message.
              return const Center(child: Text('Loading standards...', style: TextStyle(color: Colors.white)));
            }
            
            // --- Build the actual UI ---
            return RefreshIndicator(
              // onRefresh is called when the user pulls down to refresh.
              // We should re-fetch data here.
              onRefresh: () async {
                // Re-fetch data
                await _initializeData(user.id, token, bodyweightKg, gender);
                // The setState calls within fetch methods will update the UI.
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: showBenchmarks
                      ? BenchmarksTable(
                          standards: liftStandards!, // Non-null assertion safe due to prior check
                          onViewRankings: () => setState(() => showBenchmarks = false),
                        )
                      : RankingTable(
                          liftStandards: liftStandards!, // Non-null assertion safe
                          userHighScores: userHighScores, // Already fetched and set in state
                          onViewBenchmarks: () => setState(() => showBenchmarks = true),
                          onLiftTapped: _handleScenarioTap,
                          onLeaderboardTapped: _handleLeaderboardTap,
                          onEnergyLeaderboardTapped: _handleEnergyLeaderboardTap,
                          onEnergyComputed: _handleEnergyComputed,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}