import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'exercise_play_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ExerciseListScreenState createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<dynamic>> exercises;

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

  @override
  void initState() {
    super.initState();
    exercises = fetchExercises();
  }

  @override
  Widget build(BuildContext context) {
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
            final exercisesData = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: exercisesData.length,
                      itemBuilder: (context, index) {
                        final exercise = exercisesData[index];
                        final scenarioName =
                            exercise['name'] ?? 'Unnamed Exercise';

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
                              'Sets: ${exercise['sets']} | Reps: ${exercise['reps']}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.green),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExercisePlayScreen(
                                      exerciseId: exercise['scenario_id'],
                                      exerciseName: scenarioName,
                                      sets: exercise['sets'],
                                      reps: exercise['reps'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      int count = 0;
                      Navigator.of(context).popUntil((_) => count++ >= 2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Submit Routine'),
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
