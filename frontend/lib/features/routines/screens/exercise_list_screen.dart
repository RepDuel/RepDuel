import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'exercise_play_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  _ExerciseListScreenState createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<dynamic>> exercises;

  // Fetch exercises for the selected routine
  Future<List<dynamic>> fetchExercises() async {
    final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/routines/${widget.routineId}'));

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
    exercises = fetchExercises(); // Fetch exercises for the selected routine
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
              child: ListView.builder(
                itemCount: exercisesData.length,
                itemBuilder: (context, index) {
                  final exercise = exercisesData[index];

                  return Card(
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        exercise['scenario_id'],
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      subtitle: Text(
                        'Sets: ${exercise['sets']} | Reps: ${exercise['reps']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                        onPressed: () {
                          // Navigate to the exercise play screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExercisePlayScreen(
                                exerciseId: exercise['scenario_id'],
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
            );
          }
        },
      ),
    );
  }
}
