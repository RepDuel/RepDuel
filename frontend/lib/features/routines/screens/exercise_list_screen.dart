// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'dart:async'; // For TimeoutException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../providers/set_data_provider.dart';
import 'exercise_play_screen.dart';
import 'summary_screen.dart';
import 'add_exercise_screen.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import the auth provider

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String routineId;

  const ExerciseListScreen({super.key, required this.routineId});

  @override
  ConsumerState<ExerciseListScreen> createState() => ExerciseListScreenState();
}

class ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  late Future<List<dynamic>> _futureExercises;

  final List<Map<String, dynamic>> _localAddedExercises = [];

  num _totalVolumeKg = 0;
  late DateTime _startTime;

  bool _isFinishing = false;
  bool _scoresSubmitted = false;

  // --- Constants ---
  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load exercises';
  static const _kgToLbs = 2.20462;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // _fetchExercises is called later, after auth state is resolved.
    // We can't await futures directly in initState reliably without causing issues.
    // Instead, we'll handle the initial fetch within the build method's async logic.
  }

  // Fetch exercises: This function now needs to be called when auth data is available.
  // It's better handled within the build method's .when() or a separate provider.
  // For now, let's make this fetch conditional or trigger it after auth check.
  Future<List<dynamic>> _fetchExercises() async {
    // Safely get token from authProvider
    final token = ref.read(authProvider).valueOrNull?.token; 

    if (token == null) {
      // If no token, the request would be blocked by the interceptor anyway,
      // but it's good to handle here too to prevent unnecessary http calls.
      throw Exception(_unauthorizedMessage); 
    }

    final response = await http.get(
      Uri.parse('${Env.baseUrl}/api/v1/routines/${widget.routineId}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Token is now guaranteed non-null here
      },
    ).timeout(const Duration(seconds: 10)); // Added timeout for robustness

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
    // Re-fetch exercises if needed. This should be called when auth state is ready.
    // This method might be called by a RefreshIndicator.
    // We can re-assign the future here.
    setState(() {
      _futureExercises = _fetchExercises();
    });
    await _futureExercises; // Wait for fetch to complete
  }

  void _updateVolume(List<Map<String, dynamic>> setData) {
    setState(() {
      for (final set in setData) {
        final weight = (set['weight'] as num?) ?? 0;
        final reps = (set['reps'] as num?) ?? 0;
        _totalVolumeKg += weight * reps;
      }
    });
  }

  void _navigateToAddExercise() async {
    // Navigator.push is fine here as it's within the widget's context.
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );

    if (newExercise != null) {
      setState(() {
        _localAddedExercises.add(Map<String, dynamic>.from(newExercise));
      });
    }
  }

  // Unit helpers now need to safely access user data from authProvider.
  bool _isLbs(WidgetRef ref) {
    // Safely get weightMultiplier from authProvider's data.
    final wm = ref.read(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0;
    return wm > 1.5; // heuristic (~2.2 => lbs)
  }

  String _unitLabel(WidgetRef ref) => _isLbs(ref) ? 'lb' : 'kg';

  num _displayVolume(WidgetRef ref) =>
      _isLbs(ref) ? _totalVolumeKg * _kgToLbs : _totalVolumeKg;

  double _calc1RM(double weightKg, int reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  // Submit "best per scenario" to /api/v1/scores/
  Future<void> _submitScoresBestPerScenario() async {
    if (_scoresSubmitted) return; // Prevent multiple submissions

    final sets = ref.read(routineSetProvider); // Your set models
    if (sets.isEmpty) return;

    // Safely get user and token
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final token = authStateData?.token;

    if (user == null || token == null) {
      debugPrint("[ExerciseListScreen] Cannot submit scores: User or token missing.");
      return; // Exit if not authenticated
    }

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
            'Authorization': 'Bearer $token', // Use the safely retrieved token
          },
          body: jsonEncode(body),
        );
      } catch (e) {
        debugPrint("[ExerciseListScreen] Error submitting best score: $e");
        // Optionally handle errors more gracefully, but don't block user flow.
      }
    }

    _scoresSubmitted = true;
  }

  // Reset local widget state and provider sets
  void _resetLocalState() {
    setState(() {
      _totalVolumeKg = 0;
      _startTime = DateTime.now();
      _localAddedExercises.clear();
      _isFinishing = false;
      // _scoresSubmitted is intentionally left true after submission
    });
    ref.invalidate(routineSetProvider); // Invalidate the provider to reset its state
  }

  Future<void> _finishRoutine() async {
    if (_isFinishing) return; // Prevent double taps
    setState(() => _isFinishing = true);

    // Safely get user and token
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final token = authStateData?.token;

    if (user == null || token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated. Please log in.")),
      );
      setState(() => _isFinishing = false);
      // Redirect to login if auth state is missing
      GoRouter.of(context).go('/login'); 
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
      'scenarios': _localAddedExercises.map((ex) => { // Include locally added exercises
          'scenario_id': ex['scenario_id'],
          'sets': ex['sets'],
          'reps': ex['reps'],
          'weight': ex['weight'] ?? 0, // Assuming weight is available, otherwise default
        }).toList()
         + ref.read(routineSetProvider).map((set) => set.toJson()).toList(), // Combine with provider sets
    };

    final response = await http.post(
      Uri.parse('${Env.baseUrl}/api/v1/routine_submission'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the safely retrieved token
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
      // Navigate to summary screen using GoRouter if desired, or Navigator.push
      GoRouter.of(context).push('/summary'); // Assuming '/summary' route exists
    } else if (response.statusCode == 401) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to finish the routine.")),
      );
      if (!mounted) return;
      GoRouter.of(context).go('/login'); // Redirect to login
      setState(() => _isFinishing = false);
    } else if (response.statusCode == 404) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("**Invalid data submitted. Please check and try again.**")),
      );
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
    // Use GoRouter for navigation if possible, or Navigator.pop
    GoRouter.of(context).pop(); // Navigate back from ExerciseListScreen
    GoRouter.of(context).pop(); // Navigate back from RoutinePlayScreen (or previous)
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth provider to get AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Display loading screen while auth state is loading
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      ),
      error: (error, stackTrace) => Scaffold( // Display error message if auth fails to load
        backgroundColor: Colors.black,
        body: Center(child: Text('Auth Error: $error', style: const TextStyle(color: Colors.red))),
      ),
      data: (authState) { // authState is the actual AuthState object here
        final user = authState.user;
        final token = authState.token;

        // If user or token is null, it means the user is not authenticated.
        // The router should handle redirecting to login. We'll show a message here.
        if (user == null || token == null) {
          // This case should ideally be handled by the router redirecting to login.
          // As a fallback, we show a message prompting login.
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to start routines.', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => GoRouter.of(context).go('/login'), // Use GoRouter for navigation
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // --- User is logged in and data is available ---
        // Now that we know user and token are available, fetch initial data.
        // We use a FutureBuilder for fetching exercises.
        final bodyweightKg = user.weight ?? 70.0; // Use user's weight, default if null
        final gender = user.gender ?? 'male';     // Use user's gender, default if null

        // _futureExercises is initialized in initState, but if auth state changes
        // dynamically, we might need to re-fetch. For now, assuming initState is sufficient
        // for the initial load. If dynamic auth state changes need to trigger re-fetch here,
        // a different approach like a dedicated provider for exercises would be better.
        // However, for now, we'll rely on initState's initial fetch.

        final unit = _isLbs(ref) ? 'lb' : 'kg'; // Get unit based on user's weight multiplier

        return Scaffold(
          appBar: AppBar(
            title: const Text('Exercise List'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          backgroundColor: Colors.black,
          body: FutureBuilder<List<dynamic>>(
            future: _futureExercises, // Use the future initialized in initState
            builder: (context, snapshot) {
              // Loading state for exercises
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Error state for exercises
              if (snapshot.hasError) {
                final message = snapshot.error?.toString() ?? _genericFailMessage;
                final isUnauthorized = message.contains('401');

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (isUnauthorized)
                          ElevatedButton(
                            onPressed: () => GoRouter.of(context).go('/login'), // Redirect on unauthorized
                            child: const Text('Login'),
                          )
                        else
                          ElevatedButton(
                            onPressed: _refresh, // Retry fetching exercises
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                );
              }

              // Data ready for exercises
              final serverExercises = snapshot.data ?? <dynamic>[];

              // Combine server exercises with locally added ones
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
                          final scenarioName = exercise['name'] ?? 'Unnamed Exercise';
                          final sets = exercise['sets'] ?? 0;
                          final reps = exercise['reps'] ?? 0;

                          // Watch the routineSetProvider to see completed sets
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
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              subtitle: Text(
                                'Sets: $sets | Reps: $reps',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_arrow, color: Colors.green),
                                onPressed: () async {
                                  // Navigate to exercise play screen
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

                                  // If sets data is returned, update total volume
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
                    // Button to add new exercises
                    ElevatedButton(
                      onPressed: _navigateToAddExercise,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('Add Exercise'),
                    ),
                    const SizedBox(height: 16),
                    // Button to finish the routine
                    ElevatedButton(
                      onPressed: _isFinishing ? null : _finishRoutine, // Disable if already finishing
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: _isFinishing
                          ? const SizedBox( // Show spinner while finishing
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
                    // Button to quit the routine
                    ElevatedButton(
                      onPressed: _quitRoutine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
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
      },
    );
  }
}