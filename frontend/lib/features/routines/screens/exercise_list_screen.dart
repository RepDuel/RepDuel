import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'exercise_play_screen.dart';
import 'dart:async'; // For the session timer

class ExerciseListScreen extends StatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ExerciseListScreenState createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<dynamic>> exercises;
  Stopwatch _stopwatch = Stopwatch(); // To track the session time
  Timer? _timer; // Timer to periodically update the UI
  int totalVolume = 0; // To track the total volume lifted during the session
  String sessionTime = "00:00"; // Store the session time as a string

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
    _startSessionTimer(); // Start the timer when the screen is initialized
  }

  // Function to start the session timer
  void _startSessionTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), _updateSessionTime);
  }

  // Function to stop the session timer
  void _stopSessionTimer() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  // Update session time every second
  void _updateSessionTime(Timer timer) {
    setState(() {
      final elapsed = _stopwatch.elapsed;
      final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
      final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
      sessionTime = "$minutes:$seconds"; // Update session time string
    });
  }

  // Function to update the volume counter
  void _updateVolume(int sets, int reps, double weight) {
    setState(() {
      totalVolume += sets * reps * weight.toInt();
    });
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
                  // Display the session timer and volume counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session Time: $sessionTime',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        'Total Volume: $totalVolume kg',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
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
                        final weight = exercise['weight'] ?? 0.0;

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
                              'Sets: $sets | Reps: $reps | Weight: $weight kg',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.green),
                              onPressed: () {
                                // Update volume when the exercise starts
                                _updateVolume(sets, reps, weight);
                                Navigator.push(
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
                      _stopSessionTimer(); // Stop the session timer when the routine is completed
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
