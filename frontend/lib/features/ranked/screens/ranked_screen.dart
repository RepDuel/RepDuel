import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../core/providers/auth_provider.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import '../../scenario/screens/scenario_screen.dart';
import '../widgets/benchmarks_table.dart';
import '../widgets/ranking_table.dart';

class RankedScreen extends ConsumerStatefulWidget {
  const RankedScreen({super.key});

  @override
  ConsumerState<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends ConsumerState<RankedScreen> {
  double bodyweightKg = 90.7;
  String gender = "male";
  bool showBenchmarks = false;
  Map<String, dynamic>? liftStandards;
  bool isLoading = true;
  String? error;
  Map<String, double> userHighScores = {
    'Squat': 0.0,
    'Bench Press': 0.0,
    'Deadlift': 0.0,
  };

  // Scenario IDs (always the same)
  final squatId = 'a9b52e3a-248d-4a89-82ab-555be989de5b';
  final benchId = 'bf610e59-fb34-4e21-bc36-bdf0f6f7be4f';
  final deadliftId = '9b6cf826-e243-4d3e-81bd-dfe4a8a0c05e';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    await _fetchLiftStandards();
    await _fetchUserHighScores();
    setState(() => isLoading = false);
  }

  Future<void> _fetchLiftStandards() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8000/api/v1/standards/$bodyweightKg?gender=$gender'),
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
        'http://localhost:8000/api/v1/scores/user/${user.id}/scenario';

    final results = await Future.wait([
      _fetchHighScore('$baseUrl/$squatId/highscore'),
      _fetchHighScore('$baseUrl/$benchId/highscore'),
      _fetchHighScore('$baseUrl/$deadliftId/highscore'),
    ]);

    userHighScores = {
      'Squat': results[0],
      'Bench Press': results[1],
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
        builder: (_) => ScenarioScreen(liftName: liftName),
      ),
    );

    if (result == true && mounted) {
      await _initializeData(); // Refresh scores
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
                  ),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          // TODO: Implement navigation
        },
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
