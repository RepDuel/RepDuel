// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'dart:async'; // For async operations if needed
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // For GoRouter navigation

import '../providers/set_data_provider.dart';
import 'summary_screen.dart'; // Assuming SummaryScreen is the destination after submit
import 'add_exercise_screen.dart'; // Not directly used here, but might be a dependency

import '../../../core/config/env.dart'; // For environment variables
import '../../../core/providers/auth_provider.dart'; // Import the auth provider

class ExercisePlayScreen extends ConsumerStatefulWidget {
  final String exerciseId; // This is likely the scenarioId
  final String exerciseName;
  final int sets;
  final int reps;

  const ExercisePlayScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
  });

  @override
  ConsumerState<ExercisePlayScreen> createState() => _ExercisePlayScreenState();
}

class _ExercisePlayScreenState extends ConsumerState<ExercisePlayScreen> {
  late final List<TextEditingController> weightControllers;
  late final List<TextEditingController> repControllers;
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();
  bool _isSubmitting = false;

  // Static const _kgToLbs = 2.20462; // Moved to helper methods for better context

  @override
  void initState() {
    super.initState();
    // Initialization of controllers is done lazily in build or setup when needed.
    // For simplicity and directness, we'll initialize them here.
    // It's critical to get the weightMultiplier *when initializing* if it affects default values.
    // However, since it's fetched reactively, we can initialize with defaults and adjust later.
    
    // Initialize controllers. Default values are handled within the controller generation.
    weightControllers = List.generate(widget.sets, (index) => TextEditingController());
    repControllers = List.generate(widget.sets, (index) => TextEditingController());

    _setupKeyboardDismissal();
  }

  void _setupKeyboardDismissal() {
    _weightFocusNode.addListener(() {
      if (!_weightFocusNode.hasFocus) {
        _dismissKeyboard();
      }
    });
    
    _repsFocusNode.addListener(() {
      if (!_repsFocusNode.hasFocus) {
        _dismissKeyboard();
      }
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // Helper method to safely get weightMultiplier from authProvider.
  double _getWeightMultiplier(WidgetRef ref) {
    // Safely access user data from authProvider's AsyncValue.
    return ref.read(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0;
  }

  // Helper to determine if units are lbs.
  bool _isLbs(WidgetRef ref) {
    final wm = _getWeightMultiplier(ref);
    return wm > 1.5; // Heuristic: ~2.2 multiplier indicates lbs.
  }

  // Helper to get the unit label (kg or lb).
  String _unitLabel(WidgetRef ref) => _isLbs(ref) ? 'lb' : 'kg';

  // Helper to convert KG to the user's display unit.
  double _toDisplayUnit(WidgetRef ref, double kg) {
    return _isLbs(ref) ? kg * 2.20462 : kg;
  }

  // Helper to convert user's display unit back to KG for backend storage.
  double _toKg(WidgetRef ref, double valueInUserUnit) {
    return _isLbs(ref) ? valueInUserUnit / 2.20462 : valueInUserUnit;
  }

  // Formatter for displaying numbers (integer if whole, else fixed to 1 decimal).
  String _fmt(num n) => (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

  double _calculateOneRepMax(double weightKg, int reps) {
    if (reps <= 0) return 0.0; // Handle zero reps case
    if (reps == 1) return weightKg;
    // Standard formula for estimated 1RM
    return weightKg * (1 + reps / 30.0); 
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId, String token) async {
    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Add token for authenticated request
        },
      ).timeout(const Duration(seconds: 5)); // Added timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Safely parse score_value, defaulting to 0 if null or invalid
        return (data['score_value'] as num?)?.round() ?? 0; 
      }
    } catch (e) {
      debugPrint("Error fetching previous best score: $e");
    }
    return 0; // Return 0 if score not found or error occurs
  }

  Future<void> _submitScore(double weightLiftedKg, int reps, String token) async {
    // Safely get user ID.
    final userId = _ref.read(authProvider).valueOrNull?.user?.id;
    if (userId == null) {
      throw Exception("User ID not found. Cannot submit score.");
    }

    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/scenario/${widget.exerciseId}/'); // Using widget.exerciseId as scenarioId
    final body = {
      'user_id': userId,
      'weight_lifted': weightLiftedKg, // This is the score value to submit, already in KG
      'reps': reps,
      'sets': 1, // Assuming each submission is for a single set/attempt
    };

    await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the safely retrieved token
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 5)); // Add timeout
  }

  Future<void> _handleSubmit() async {
    // Safely get user and token
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final token = authStateData?.token;

    if (user == null || token == null) {
      // If user or token is missing, cannot proceed. Show message and redirect.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication required to submit score.")),
      );
      // Redirect to login if not authenticated.
      GoRouter.of(context).go('/login'); 
      return;
    }

    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid reps.")),
      );
      return;
    }

    setState(() => _isSubmitting = true); // Show submitting state

    double scoreToSubmitForRank; // Score used for ranking (e.g., normalized 1RM)
    double weightLiftedKgForBackend; // Score sent to backend (weight in KG)

    try {
      if (_isBodyweight(ref)) { // Use helper to check if bodyweight exercise
        scoreToSubmitForRank = reps.toDouble();
        weightLiftedKgForBackend = 0.0; // Backend might not track weight for bodyweight
      } else {
        final weightText = _weightController.text.trim();
        final weightUserUnit = double.tryParse(weightText);
        if (weightUserUnit == null || weightUserUnit <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please enter valid weight.")),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }

        final weightMultiplier = _getWeightMultiplier(ref); // Safely get multiplier
        final weightKg = _toKg(ref, weightUserUnit); // Convert user input to KG for backend

        final oneRepMax = _calculateOneRepMax(weightKg, reps);
        
        scoreToSubmitForRank = oneRepMax; // Score for rank calculation (e.g., 1RM)
        weightLiftedKgForBackend = weightKg; // Send the weight in KG to backend
      }

      // Fetch previous best score using user ID and token.
      final previousBest = await _fetchPreviousBest(user.id, widget.exerciseId, token); // Use widget.exerciseId as scenarioId

      // Submit the score to the backend.
      await _submitScore(weightLiftedKgForBackend, reps, token);

      if (!mounted) return; // Check mounted status after async operation

      // Navigate to ResultScreen.
      // The 'shouldRefresh' logic might need to be handled differently if ResultScreen doesn't pop back with a value.
      // Assuming Navigator.push returns a value that signals a refresh.
      final shouldRefresh = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            finalScore: scoreToSubmitForRank, // Score used for rank calculation
            previousBest: previousBest,
            scenarioId: widget.exerciseId, // Pass scenarioId
          ),
        ),
      );

      // If the ResultScreen indicated a change that requires refresh, pop true back.
      if (shouldRefresh == true && mounted) {
        Navigator.pop(context, true); // Signal back to previous screen if needed
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false); // Ensure submitting state is reset
      }
    }
  }

  // Helper to build bullet points from description.
  List<Widget> _buildBulletDescription(String? description) {
    if (description == null || description.isEmpty) return [];
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+')); // Split by sentence terminators
    return sentences
        .where((s) => s.trim().isNotEmpty) // Remove empty strings
        .map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
                Expanded(
                    child: Text(s.trim(),
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))),
              ],
            ),
          ),
        )
        .toList();
  }

  Widget _buildRepsOnlyInput() {
    return Column(
      children: [
        const Text('Reps', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _repsController,
            focusNode: _repsFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dismissKeyboard(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), // Clean border
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightAndRepsInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            const Text('Weight', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _weightController,
                focusNode: _weightFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false), // Allow decimals, no sign
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _repsFocusNode.requestFocus(), // Move focus to reps
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), // Clean border
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('x', style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
        Column(
          children: [
            const Text('Reps', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _dismissKeyboard(), // Dismiss keyboard on submit
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), // Clean border
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth provider to get AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Display loading screen while auth state is loading
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
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
                  const Text('Please log in to record scores.', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        // Fetch scenario details once user data is available.
        // Use FutureBuilder to handle the async loading of scenario details.
        return FutureBuilder(
          future: _loadScenarioDetails(), // Call the method to fetch details
          builder: (context, snapshot) {
            // Handle loading state for scenario details.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold( // Wrap in Scaffold for consistent app structure
                backgroundColor: Colors.black,
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            // Handle errors during scenario details fetch.
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading details: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadScenarioDetails, // Retry loading details
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // --- Scenario details loaded successfully ---
            return GestureDetector(
              onTap: _dismissKeyboard, // Dismiss keyboard when tapping outside input fields
              child: Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  title: Text(widget.liftName),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                body: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Display description points (if available)
                        ..._buildBulletDescription(_description),
                        const SizedBox(height: 32),
                        // Show appropriate input fields based on bodyweight status
                        if (_isBodyweight)
                          _buildRepsOnlyInput()
                        else
                          _buildWeightAndRepsInput(),
                      ],
                    ),
                  ),
                ),
                bottomNavigationBar: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _handleSubmit, // Disable if submitting
                    icon: _isSubmitting
                        ? const SizedBox( // Show spinner while submitting
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}