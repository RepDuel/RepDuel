import 'package:flutter/material.dart';
import 'package:frontend/widgets/main_bottom_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/features/scenario/screens/scenario_screen.dart';

class NormalScreen extends StatefulWidget {
  const NormalScreen({super.key});

  @override
  State<NormalScreen> createState() => _NormalScreenState();
}

class _NormalScreenState extends State<NormalScreen> {
  List<dynamic> scenarios = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }

  Future<void> _fetchScenarios() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/scenarios/'),
      );

      if (response.statusCode == 200) {
        setState(() {
          scenarios = json.decode(response.body);
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
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : ListView.builder(
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    return GestureDetector(
                      onTap: () {
                        // Navigate to the ScenarioScreen with the name of the scenario
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScenarioScreen(
                              liftName: scenario['name'] ?? 'Unnamed Scenario',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          scenario['name'] ?? 'Unnamed Scenario',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (_) {},
      ),
    );
  }
}
