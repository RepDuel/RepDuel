// frontend/lib/features/normal/screens/normal_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/config/env.dart';
import 'package:frontend/features/scenario/screens/scenario_screen.dart';
import 'package:frontend/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:frontend/widgets/main_bottom_nav_bar.dart';

class NormalScreen extends StatefulWidget {
  const NormalScreen({super.key});

  @override
  State<NormalScreen> createState() => _NormalScreenState();
}

class _NormalScreenState extends State<NormalScreen> {
  List<dynamic> scenarios = [];
  bool isLoading = true;
  String? error;

  static const _headerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }

  Future<void> _fetchScenarios() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${Env.baseUrl}/api/v1/scenarios/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        data.sort(
          (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
        );
        setState(() {
          scenarios = data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load scenarios';
        isLoading = false;
      });
    }
  }

  void _goToScenario(String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScenarioScreen(
          liftName: name,
          scenarioId: id,
        ),
      ),
    );
  }

  void _goToLeaderboard(String scenarioId, String liftName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          scenarioId: scenarioId,
          liftName: liftName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Normal'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchScenarios,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Column header
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text('Lift', style: _headerStyle),
                          ),
                          Expanded(
                            child: Center(
                              child: Text('Leaderboard', style: _headerStyle),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of scenarios
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _fetchScenarios(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: scenarios.length,
                          itemBuilder: (context, index) {
                            final scenario = scenarios[index];
                            final name =
                                (scenario['name'] ?? 'Unnamed Scenario')
                                    .toString();
                            final id = scenario['id']?.toString();

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 0),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (id != null) {
                                          _goToScenario(id, name);
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0),
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.leaderboard,
                                            color: Colors.blue),
                                        onPressed: () {
                                          if (id != null) {
                                            _goToLeaderboard(id, name);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (_) {},
      ),
    );
  }
}
