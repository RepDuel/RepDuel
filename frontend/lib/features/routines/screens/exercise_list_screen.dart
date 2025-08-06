// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../providers/set_data_provider.dart';
import 'exercise_play_screen.dart';
import 'summary_screen.dart';
import 'add_exercise_screen.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ConsumerState<ExerciseListScreen> createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  late Future<List<dynamic>> _futureExercises;

  /// Locally added exercises (kept separate from server items so we don't overwrite)
  final List<Map<String, dynamic>> _localAddedExercises = [];

  num _totalVolumeKg = 0; // keep base in kg*reps
  late DateTime _startTime;

  bool _isFinishing = false; // prevent double taps
  bool _scoresSubmitted = false; // submit best-per-scenario once

  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load exercises';
  static const _kgToLbs = 2.20462;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _futureExercises = _fetchExercises();
  }

  Future<List<dynamic>> _fetchExercises() async {
    final token = ref.read(authStateProvider).token;

    final response = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/routines/${widget.routineId}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List.from(data['scenarios']);
    } else if (response.statusCode == 401) {
      throw Exception(_unauthorizedMessage);
    } else {
      throw Exception('$_genericFailMessage (HTTP ${response.statusCode})');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _futureExercises = _fetchExercises();
    });
    await _futureExercises;
  }

  void _updateVolume(List<Map<String, dynamic>> setData) {
    // total volume = sum(weight * reps) — weights already in KG
    setState(() {
      for (final set in setData) {
        final weight = (set['weight'] as num?) ?? 0;
        final reps = (set['reps'] as num?) ?? 0;
        _totalVolumeKg += weight * reps;
      }
    });
  }

  void _navigateToAddExercise() async {
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );

    if (newExercise != null) {
      setState(() {
        // Expect: { 'scenario_id': ..., 'name': ..., 'sets': int, 'reps': int }
        _localAddedExercises.add(Map<String, dynamic>.from(newExercise));
      });
    }
  }

  /// Unit helpers based on weight multiplier (kg vs lb)
  bool _isLbs(WidgetRef ref) {
    final wm = ref.read(authStateProvider).user?.weightMultiplier ?? 1.0;
    return wm > 1.5; // heuristic (~2.2 => lbs)
  }

  String _unitLabel(WidgetRef ref) => _isLbs(ref) ? 'lb' : 'kg';

  num _displayVolume(WidgetRef ref) =>
      _isLbs(ref) ? _totalVolumeKg * _kgToLbs : _totalVolumeKg;

  double _calc1RM(double weightKg, int reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  /// Submit "best per scenario" to /api/v1/scores/
  Future<void> _submitScoresBestPerScenario() async {
    if (_scoresSubmitted) return;
    final sets = ref.read(routineSetProvider); // your set models
    if (sets.isEmpty) return;

    final token = ref.read(authStateProvider).token;
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    // Group sets by scenarioId
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final s in sets) {
      grouped.putIfAbsent(s.scenarioId, () => []).add({
        'weight': (s.weight as num).toDouble(), // KG stored in provider
        'reps': s.reps,
      });
    }

    // Build one payload per scenario using the set with highest 1RM
    final List<Map<String, dynamic>> payloads = [];
    grouped.forEach((scenarioId, list) {
      double best1RM = -1.0;
      double bestWeightKg = 0.0;
      int bestReps = 0;

      for (final set in list) {
        final w = (set['weight'] as num).toDouble();
        final r = (set['reps'] as num).toInt();
        final oneRm = _calc1RM(w, r);
        if (oneRm > best1RM) {
          best1RM = oneRm;
          bestWeightKg = w; // RAW WEIGHT (kg) for submission
          bestReps = r;
        }
      }

      if (best1RM >= 0) {
        payloads.add({
          'user_id': user.id,
          'scenario_id': scenarioId,
          'weight_lifted': bestWeightKg, // raw weight in KG
          'reps': bestReps,
          'sets': 1,
        });
      }
    });

    // POST each payload to /api/v1/scores/
    for (final body in payloads) {
      try {
        await http.post(
          Uri.parse('${Env.baseUrl}/api/v1/scores/'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );
      } catch (_) {
        // Optionally log; don't block user flow
      }
    }

    _scoresSubmitted = true;
  }

  /// Reset local widget state and provider sets
  void _resetLocalState() {
    setState(() {
      _totalVolumeKg = 0;
      _startTime = DateTime.now();
      _localAddedExercises.clear();
      _isFinishing = false;
      // _scoresSubmitted intentionally left as-is to prevent re-posts if user navigates back.
    });
    ref.invalidate(routineSetProvider);
  }

  Future<void> _finishRoutine() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    final user = ref.read(authStateProvider).user;
    final token = ref.read(authStateProvider).token;
    final sets = ref.read(routineSetProvider);

    if (!mounted) return;

    if (user == null || token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated.")),
      );
      setState(() => _isFinishing = false);
      return;
    }

    final now = DateTime.now();
    final durationInMinutes = now.difference(_startTime).inSeconds / 60.0;

    final submissionBody = {
      'routine_id': widget.routineId,
      'user_id': user.id,
      'duration': durationInMinutes,
      'completion_timestamp': now.toIso8601String(),
      'status': 'completed',
      'scenarios': sets.map((set) => set.toJson()).toList(),
    };

    final response = await http.post(
      Uri.parse('${Env.baseUrl}/api/v1/routine_submission'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(submissionBody),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      // After routine submission, submit best-per-scenario scores
      await _submitScoresBestPerScenario();

      // Capture final display volume before resetting state
      final finalDisplayVolume = _displayVolume(ref).round();

      // Reset for next session
      _resetLocalState();

      if (!mounted) return;
      // Go to summary with final rounded volume
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryScreen(totalVolume: finalDisplayVolume),
        ),
      );
    } else if (response.statusCode == 401) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to finish the routine.")),
      );
      if (!mounted) return;
      context.go('/login');
      setState(() => _isFinishing = false);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission failed: ${response.body}")),
      );
      setState(() => _isFinishing = false);
    }
  }

  void _quitRoutine() {
    _resetLocalState();
    Navigator.pop(context); // back from ExerciseList
    Navigator.pop(context); // back from RoutinePlay (or previous)
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unitLabel(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise List'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<List<dynamic>>(
        future: _futureExercises,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            final message = snapshot.error?.toString() ?? _genericFailMessage;
            final isUnauthorized = message.contains('401');

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (isUnauthorized)
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Login'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            );
          }

          // Data ready
          final serverExercises = snapshot.data ?? <dynamic>[];

          // Combine server exercises with locally added ones (without mutating state here)
          final combined = <Map<String, dynamic>>[
            ...serverExercises.cast<Map<String, dynamic>>(),
            ..._localAddedExercises,
          ];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Total Volume: ${_displayVolume(ref).round()} $unit',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: combined.length,
                    itemBuilder: (context, index) {
                      final exercise = combined[index];
                      final scenarioId = exercise['scenario_id'];
                      final scenarioName =
                          exercise['name'] ?? 'Unnamed Exercise';
                      final sets = exercise['sets'] ?? 0;
                      final reps = exercise['reps'] ?? 0;

                      final completedSets = ref
                          .watch(routineSetProvider)
                          .where((s) => s.scenarioId == scenarioId)
                          .length;

                      final isCompleted = completedSets >= sets;

                      return Card(
                        color: isCompleted ? Colors.green[800] : Colors.white12,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            scenarioName,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          subtitle: Text(
                            'Sets: $sets | Reps: $reps',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Colors.green),
                            onPressed: () async {
                              final setData = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExercisePlayScreen(
                                    exerciseId: scenarioId,
                                    exerciseName: scenarioName,
                                    sets: sets,
                                    reps: reps,
                                  ),
                                ),
                              );

                              if (setData != null) {
                                _updateVolume(
                                  List<Map<String, dynamic>>.from(setData),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _navigateToAddExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Add Exercise'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isFinishing ? null : _finishRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: _isFinishing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Finish Routine'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _quitRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Quit Routine'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
