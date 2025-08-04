// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/config/env.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import '../../scenario/screens/scenario_screen.dart';
import '../../leaderboard/screens/leaderboard_screen.dart';
import '../../leaderboard/screens/energy_leaderboard_screen.dart';

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
  bool isLoading = true;
  String? error;
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
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    // Get the user's bodyweight and gender from authProvider
    final user = ref.read(authProvider).user;
    final bodyweightKg = user?.weight ?? 90.7; // Default to 90.7 if not found
    final gender =
        user?.gender?.toLowerCase() ?? 'male'; // Convert to lowercase

    await _fetchLiftStandards(bodyweightKg, gender);
    await _fetchUserHighScores();
    setState(() => isLoading = false);
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
        if (data.isNotEmpty) {
          liftStandards = data;
        } else {
          error = 'Received empty data from API';
        }
      } else {
        error = 'API Error: ${response.statusCode}';
      }
    } on TimeoutException {
      error = 'Request timed out';
    } catch (e) {
      error = 'Error: $e';
    }
  }

  Future<void> _fetchUserHighScores() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final baseUrl =
        '${Env.baseUrl}/api/v1/scores/user/${user.id}/scenario';

    final results = await Future.wait([
      _fetchHighScore('$baseUrl/$squatId/highscore'),
      _fetchHighScore('$baseUrl/$benchId/highscore'),
      _fetchHighScore('$baseUrl/$deadliftId/highscore'),
    ]);

    userHighScores = {
      'Squat': results[0],
      'Bench': results[1],
      'Deadlift': results[2],
    };
  }

  Future<double> _fetchHighScore(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['weight_lifted'] as num).toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  Future<void> _handleScenarioTap(String liftName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioScreen(
          liftName: liftName,
          scenarioId: liftToScenarioId[liftName] ?? '',
        ),
      ),
    );

    if (result == true && mounted) {
      await _initializeData();
    }
  }

  Future<void> _handleLeaderboardTap(String scenarioId) async {
    final liftName = liftToScenarioId.entries
        .firstWhere((e) => e.value == scenarioId,
            orElse: () => const MapEntry('', ''))
        .key;

    if (liftName.isEmpty) {
      debugPrint("❌ No lift name found for scenarioId '$scenarioId'");
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          scenarioId: scenarioId,
          liftName: liftName,
        ),
      ),
    );
  }

  Future<void> _handleEnergyLeaderboardTap() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnergyLeaderboardScreen(),
      ),
    );
  }

  Future<void> _handleEnergyComputed(int energy, String rank) async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    final url = Uri.parse('${Env.baseUrl}/api/v1/energy/submit');
    final body = json.encode({
      'user_id': user.id,
      'energy': energy,
      'rank': rank,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode != 200) {
        debugPrint("❌ Failed to send energy: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error submitting energy: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoading();
    if (error != null) return _buildError();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(showBenchmarks ? 'Benchmarks' : 'Ranked'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _initializeData,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: showBenchmarks
                ? BenchmarksTable(
                    standards: liftStandards!,
                    onViewRankings: () =>
                        setState(() => showBenchmarks = false),
                  )
                : RankingTable(
                    liftStandards: liftStandards!,
                    userHighScores: userHighScores,
                    onViewBenchmarks: () =>
                        setState(() => showBenchmarks = true),
                    onLiftTapped: _handleScenarioTap,
                    onLeaderboardTapped: _handleLeaderboardTap,
                    onEnergyLeaderboardTapped: _handleEnergyLeaderboardTap,
                    onEnergyComputed: _handleEnergyComputed,
                  ),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 1,
        onTap: (_) {},
      ),
    );
  }

  Widget _buildLoading() => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );

  Widget _buildError() => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(error!,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
}
