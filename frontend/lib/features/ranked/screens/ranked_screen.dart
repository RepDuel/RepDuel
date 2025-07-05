import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:frontend/features/ranked/widgets/benchmarks_table.dart';
import 'package:frontend/features/ranked/widgets/ranking_table.dart';
import '../../../widgets/main_bottom_nav_bar.dart';

class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  double bodyweightKg = 90.7;
  String gender = "male";
  bool showBenchmarks = false;
  Map<String, dynamic>? liftStandards; // Keep original name for RankingTable
  bool isLoading = true;
  String? error;

  final Map<String, double> userHighScores = {
    'Bench': 135.0,
    'Squat': 185.0,
    'Deadlift': 225.0,
  };

  @override
  void initState() {
    super.initState();
    _fetchLiftStandards();
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
          setState(() {
            liftStandards = data;
            isLoading = false;
          });
        } else {
          setState(() {
            error = 'Received empty data from API';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'API Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } on TimeoutException catch (_) {
      setState(() {
        error = 'Request timed out';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoading();
    }

    if (error != null) {
      return _buildError();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(showBenchmarks ? 'Benchmark Standards' : 'My Rankings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiftStandards,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: showBenchmarks
                ? BenchmarksTable(
                    standards: liftStandards!, // Pass the data
                    onViewRankings: () =>
                        setState(() => showBenchmarks = false),
                  )
                : RankingTable(
                    liftStandards: liftStandards!, // Use correct parameter name
                    userHighScores: userHighScores,
                    onViewBenchmarks: () =>
                        setState(() => showBenchmarks = true),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // Navigation implementation
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchLiftStandards,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
