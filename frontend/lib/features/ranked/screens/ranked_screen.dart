// frontend/lib/features/ranked/screens/ranked_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
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
    if (!mounted) return;
    setState(() => isLoading = true);

    final user = ref.read(authProvider).user;
    final bodyweightKg = user?.weight ?? 90.7;
    final gender = user?.gender?.toLowerCase() ?? 'male';

    await _fetchLiftStandards(bodyweightKg, gender);
    await _fetchUserHighScores();

    if (mounted) {
      setState(() => isLoading = false);
    }
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

  Future<void> _fetchUserHighScores() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final baseUrl = '${Env.baseUrl}/api/v1/scores/user/${user.id}/scenario';

    final results = await Future.wait([
      _fetchHighScore('$baseUrl/$squatId/highscore'),
      _fetchHighScore('$baseUrl/$benchId/highscore'),
      _fetchHighScore('$baseUrl/$deadliftId/highscore'),
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

  void _handleLeaderboardTap(String scenarioId) {
    final liftName = liftToScenarioId.entries
        .firstWhere((e) => e.value == scenarioId,
            orElse: () => const MapEntry('', ''))
        .key;

    if (liftName.isNotEmpty) {
      context.push('/leaderboard/$scenarioId?liftName=$liftName');
    }
  }

  void _handleEnergyLeaderboardTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnergyLeaderboardScreen(),
      ),
    );
  }

  Future<void> _handleEnergyComputed(int energy, String rank) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final url = Uri.parse('${Env.baseUrl}/api/v1/energy/submit');
    final body = json.encode({
      'user_id': user.id,
      'energy': energy,
      'rank': rank,
    });

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      debugPrint("❌ Error submitting energy: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: _initializeData,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: showBenchmarks
              ? BenchmarksTable(
                  standards: liftStandards!,
                  onViewRankings: () => setState(() => showBenchmarks = false),
                )
              : RankingTable(
                  liftStandards: liftStandards!,
                  userHighScores: userHighScores,
                  onViewBenchmarks: () => setState(() => showBenchmarks = true),
                  onLiftTapped: _handleScenarioTap,
                  onLeaderboardTapped: _handleLeaderboardTap,
                  onEnergyLeaderboardTapped: _handleEnergyLeaderboardTap,
                  onEnergyComputed: _handleEnergyComputed,
                ),
        ),
      ),
    );
  }
}