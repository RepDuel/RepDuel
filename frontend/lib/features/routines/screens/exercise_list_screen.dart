import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/set_data_provider.dart';
import 'exercise_play_screen.dart';
import 'summary_screen.dart';
import 'add_exercise_screen.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ConsumerState<ExerciseListScreen> createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  late Future<List<dynamic>> exercises;
  List<dynamic> exercisesList = [];
  num totalVolume = 0;

  Future<List<dynamic>> fetchExercises() async {
    final response = await http.get(
      Uri.parse('http://localhost:8000/api/v1/routines/${widget.routineId}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List.from(data['scenarios']);
    } else {
      throw Exception('Failed to load exercises');
    }
  }

  void _updateVolume(List<Map<String, dynamic>> setData) {
    setState(() {
      for (var set in setData) {
        totalVolume += set['weight'] * set['reps'];
      }
    });
  }

  @override
  void initState() {
    super.initState();
    exercises = fetchExercises();
  }

  void _finishRoutine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(totalVolume: totalVolume),
      ),
    );
  }

  void _quitRoutine() {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  void _navigateToAddExercise() async {
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExerciseScreen()),
    );

    if (newExercise != null) {
      setState(() {
        exercisesList.add(newExercise);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final setData = ref.watch(routineSetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise List'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: exercises,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            if (snapshot.hasData) {
              exercisesList = snapshot.data!;
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Total Volume: $totalVolume kg',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exercisesList.length,
                      itemBuilder: (context, index) {
                        final exercise = exercisesList[index];
                        final scenarioId = exercise['scenario_id'];
                        final scenarioName =
                            exercise['name'] ?? 'Unnamed Exercise';
                        final sets = exercise['sets'] ?? 0;
                        final reps = exercise['reps'] ?? 0;

                        final isCompleted = setData
                                .where((s) => s.scenarioId == scenarioId)
                                .length >=
                            sets;

                        return Card(
                          color:
                              isCompleted ? Colors.green[800] : Colors.white12,
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
                                  _updateVolume(setData);
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
          }
        },
      ),
    );
  }
}
