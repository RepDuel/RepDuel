import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/routine.dart';

class RoutinePlayScreen extends StatefulWidget {
  final Routine routine;

  const RoutinePlayScreen({super.key, required this.routine});

  @override
  State<RoutinePlayScreen> createState() => _RoutinePlayScreenState();
}

class _RoutinePlayScreenState extends State<RoutinePlayScreen> {
  Map<String, String> scenarioIdToName = {};

  @override
  void initState() {
    super.initState();
    fetchScenarioNames();
  }

  Future<void> fetchScenarioNames() async {
    final response =
        await http.get(Uri.parse('http://localhost:8000/api/v1/scenarios/'));
    if (response.statusCode == 200) {
      final List scenarios = jsonDecode(response.body);
      setState(() {
        scenarioIdToName = {
          for (var s in scenarios) s['id'] as String: s['name'] as String
        };
      });
    } else {
      print('Failed to load scenarios');
    }
  }

  @override
  Widget build(BuildContext context) {
    final routine = widget.routine;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Play Routine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: scenarioIdToName.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Table headers
                  const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Name',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Sets',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Scenario rows
                  ...routine.scenarios.map(
                    (scenario) {
                      final name = scenarioIdToName[scenario.scenarioId] ??
                          scenario.scenarioId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${scenario.sets}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).toList(),
                ],
              ),
      ),

      // START button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // TODO: Start the routine logic
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }
}
