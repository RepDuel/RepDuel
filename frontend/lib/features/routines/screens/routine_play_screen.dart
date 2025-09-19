// frontend/lib/features/routines/screens/routine_play_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/env.dart';
import '../../../core/models/routine.dart';
import '../../../core/providers/navigation_provider.dart';

class RoutinePlayScreen extends ConsumerStatefulWidget {
  final Routine routine;

  const RoutinePlayScreen({super.key, required this.routine});

  @override
  ConsumerState<RoutinePlayScreen> createState() => _RoutinePlayScreenState();
}

class _RoutinePlayScreenState extends ConsumerState<RoutinePlayScreen> {
  Map<String, String> scenarioIdToName = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bottomNavVisibilityProvider.notifier).state = false;
    });
    fetchScenarioNames();
  }

  @override
  void dispose() {
    ref.read(bottomNavVisibilityProvider.notifier).state = true;
    super.dispose();
  }

  Future<void> fetchScenarioNames() async {
    try {
      final response =
          await http.get(Uri.parse('${Env.baseUrl}/api/v1/scenarios/'));
      if (response.statusCode == 200) {
        final List scenarios = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          scenarioIdToName = {
            for (var s in scenarios) s['id'] as String: s['name'] as String
          };
        });
      } else {
        if (kDebugMode) {
          debugPrint(
              'Failed to load scenarios. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading scenarios: $e');
      }
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
          onPressed: () => context.pop(),
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
                  ),
                ],
              ),
      ),

      // START button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // ✅ Use named route with path parameters (Option A flow)
            context.pushNamed(
              'exerciseList',
              pathParameters: {'routineId': routine.id},
            );
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
