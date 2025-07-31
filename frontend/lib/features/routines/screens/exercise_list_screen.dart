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

  num _totalVolumeKg = 0; // keep the base in kg*reps for consistent math
  late DateTime _startTime;

  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load exercises';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _futureExercises = _fetchExercises();
  }

  Future<List<dynamic>> _fetchExercises() async {
    final token = ref.read(authStateProvider).token;

    final response = await http.get(
      Uri.parse('http://localhost:8000/api/v1/routines/${widget.routineId}'),
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
    // total volume is sum(weight * reps) — keep base in kg
    // If ExercisePlayScreen is already in kg, this is correct.
    // If you ever let users enter lbs there, convert to kg before adding.
    setState(() {
      for (var set in setData) {
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
        // Expecting: { 'scenario_id': ..., 'name': ..., 'sets': int, 'reps': int }
        _localAddedExercises.add(Map<String, dynamic>.from(newExercise));
      });
    }
  }

  Future<void> _finishRoutine() async {
    final user = ref.read(authStateProvider).user;
    final token = ref.read(authStateProvider).token;
    final sets = ref.read(routineSetProvider);

    if (!mounted) return;

    if (user == null || token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated.")),
      );
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
      Uri.parse('http://localhost:8000/api/v1/routine_submission'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(submissionBody),
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryScreen(totalVolume: _displayVolume(ref)),
        ),
      );
    } else if (response.statusCode == 401) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to finish the routine.")),
      );
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submission failed: ${response.body}")),
      );
    }
  }

  void _quitRoutine() {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  /// Helpers for unit display based on weight multiplier (kg vs lb)
  static const _kgToLbs = 2.20462;

  bool _isLbs(WidgetRef ref) {
    final wm = ref.read(authStateProvider).user?.weightMultiplier ?? 1.0;
    return wm > 1.5; // heuristic: ~2.2 => lbs
    // If you have a dedicated unit flag, prefer that instead of this heuristic.
  }

  String _unitLabel(WidgetRef ref) => _isLbs(ref) ? 'lb' : 'kg';

  num _displayVolume(WidgetRef ref) =>
      _isLbs(ref) ? _totalVolumeKg * _kgToLbs : _totalVolumeKg;

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
                  'Total Volume: ${_displayVolume(ref)} $unit',
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
                                    List<Map<String, dynamic>>.from(setData));
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
                  onPressed: _finishRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Finish Routine'),
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
