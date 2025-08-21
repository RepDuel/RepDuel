// frontend/lib/features/routines/screens/routine_play_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/env.dart';
import '../../../core/models/routine.dart';
import '../../../theme/app_theme.dart';

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
        await http.get(Uri.parse('${Env.baseUrl}/api/v1/scenarios/'));
    if (response.statusCode == 200) {
      final List scenarios = jsonDecode(response.body);
      setState(() {
        scenarioIdToName = {
          for (var s in scenarios) s['id'] as String: s['name'] as String
        };
      });
    } else {
      if (kDebugMode) {
        debugPrint('Failed to load scenarios');
      }
      // In production, you might want to use a proper logging package
      // or show an error to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    final routine = widget.routine;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Play Routine'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
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
                          style: theme.textTheme.labelLarge?.copyWith(fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Sets',
                          style: theme.textTheme.labelLarge?.copyWith(fontSize: 16),
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
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${scenario.sets}',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),

      // START button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // Navigate to ExerciseListScreen and pass the routineId
            context.push('/exercise_list/${routine.id}');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
          child: const Text('Start'),
        ),
      ),
    );
  }
}
