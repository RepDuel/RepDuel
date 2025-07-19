// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'exercise_play_screen.dart';
import 'summary_screen.dart'; // Import SummaryScreen

class ExerciseListScreen extends StatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ExerciseListScreenState createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<dynamic>> exercises;
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
    // Navigate to SummaryScreen with total volume as a parameter
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SummaryScreen(totalVolume: totalVolume)),
    );
  }

  void _quitRoutine() {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise List'),
        backgroundColor: Colors.black, // Use backgroundColor instead of primary
        foregroundColor:
            Colors.white, // Use foregroundColor instead of primaryColor
      ),
      body: FutureBuilder<List<dynamic>>(
        future: exercises,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final exercisesData = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Display the total volume
                  Text(
                    'Total Volume: $totalVolume kg',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exercisesData.length,
                      itemBuilder: (context, index) {
                        final exercise = exercisesData[index];
                        final scenarioName =
                            exercise['name'] ?? 'Unnamed Exercise';
                        final sets = exercise['sets'] ?? 0;
                        final reps = exercise['reps'] ?? 0;

                        return Card(
                          color: Colors.white12,
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
                                // Navigate to ExercisePlayScreen and await the returned data
                                final setData = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExercisePlayScreen(
                                      exerciseId: exercise['scenario_id'],
                                      exerciseName: scenarioName,
                                      sets: sets,
                                      reps: reps,
                                    ),
                                  ),
                                );

                                // Update total volume with the returned data
                                if (setData != null) {
                                  _updateVolume(
                                      setData); // Update volume based on returned data
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Finish Routine Button with white text
                  ElevatedButton(
                    onPressed: _finishRoutine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white, // Set text color to white
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Finish Routine'),
                  ),
                  const SizedBox(height: 16),
                  // Quit Routine Button with white text
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
