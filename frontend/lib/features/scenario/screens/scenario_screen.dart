// frontend/lib/features/scenario/screens/scenario_screen.dart

import 'dart:async'; // For TimeoutException
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart'; // For GoRouter navigation

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../ranked/screens/result_screen.dart'; // For navigation

class ScenarioScreen extends ConsumerStatefulWidget {
  final String liftName;
  final String scenarioId;

  const ScenarioScreen({
    super.key,
    required this.liftName,
    required this.scenarioId,
  });

  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();
  bool _isSubmitting = false;

  String? _description;
  bool _isBodyweight = false;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    // _loadScenarioDetails is called once when the widget mounts.
    _loadScenarioDetails(); 
    _setupKeyboardDismissal();
  }

  void _setupKeyboardDismissal() {
    // Add listeners to dismiss keyboard when focus is lost.
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

  Future<void> _loadScenarioDetails() async {
    final url = Uri.parse('${Env.baseUrl}/api/v1/scenarios/${widget.scenarioId}/details');
    try {
      // Note: For fetching details that don't require auth, a public client might be used.
      // If this endpoint requires auth, you'd need to pass the token here.
      // Assuming it's a public endpoint for simplicity.
      final response = await http.get(url).timeout(const Duration(seconds: 5)); // Added timeout
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) { // Check if the widget is still mounted before calling setState
          setState(() {
            _description = data['description'];
            _isBodyweight = data['is_bodyweight'] ?? false;
          });
        }
      } else {
        if (mounted) setState(() => _description = 'Failed to load description. Status: ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) setState(() => _description = 'Request timed out.');
    } catch (e) {
      if (mounted) setState(() => _description = 'Failed to load description: $e');
    } finally {
      // Ensure loading state is set to false even if there was an error
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  double _calculateOneRepMax(double weight, int reps) {
    if (reps <= 0) return 0.0; // Handle zero reps case
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }

  Future<int> _fetchPreviousBest(String userId, String scenarioId, String token) async {
    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/user/$userId/scenario/$scenarioId/highscore');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'}, // Add token for authenticated request
      );
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
    // User ID is needed for submission. It should be safely accessed.
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final userId = user?.id;

    if (userId == null) {
      throw Exception("User ID not found. Cannot submit score.");
    }

    final url = Uri.parse('${Env.baseUrl}/api/v1/scores/scenario/${widget.scenarioId}/');
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
        'Authorization': 'Bearer $token', // Add token for authenticated request
      },
      body: json.encode(body),
    ).timeout(const Duration(seconds: 5)); // Add timeout
  }

  Future<void> _handleSubmit() async {
    // Safely get user and token
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final token = authStateData?.token;

    if (user == null || token == null) {
      // If user or token is missing, cannot proceed. Show message and potentially redirect.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication required to submit score.")),
      );
      // Optionally redirect to login: GoRouter.of(context).go('/login');
      return; 
    }

    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid reps.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    double scoreToSubmitForRank; // This is the score used for calculating rank (might be 1RM or just reps)
    double weightLiftedKgForBackend; // This is what's sent to the backend for score tracking

    try {
      if (_isBodyweight) {
        // For bodyweight exercises, the 'score' is usually just the reps.
        scoreToSubmitForRank = reps.toDouble();
        weightLiftedKgForBackend = 0.0; // Backend might not track weight for bodyweight
      } else {
        final weightText = _weightController.text;
        final weight = double.tryParse(weightText);
        if (weight == null || weight <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please enter valid weight.")),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }

        final userMultiplier = user.weightMultiplier; // Get multiplier from user data
        final weightInKg = weight * userMultiplier; // Convert input weight to KG if necessary

        final oneRepMax = _calculateOneRepMax(weightInKg, reps);
        
        // The score used for ranking might be normalized (e.g., 1RM / bodyweight)
        // For now, let's assume the backend expects the 1RM for non-bodyweight.
        scoreToSubmitForRank = oneRepMax; 
        weightLiftedKgForBackend = weightInKg; // Submit the weight in KG
      }

      // Fetch previous best using the user's ID and token
      final previousBest = await _fetchPreviousBest(user.id, widget.scenarioId, token);

      // Submit the score to the backend
      await _submitScore(weightLiftedKgForBackend, reps, token);

      if (!mounted) return; // Check mounted status after async operation

      // Navigate to ResultScreen, passing the score that determines rank and backend values
      // Note: Ensure ResultScreen can handle these values correctly.
      final shouldRefresh = await Navigator.of(context).push<bool>( // Use Navigator.of(context).push for ModalRoutes
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            finalScore: scoreToSubmitForRank, // Score used for rank calculation
            previousBest: previousBest,
            scenarioId: widget.scenarioId,
          ),
        ),
      );

      // If the result screen indicated a change that requires refresh, pop true back.
      // This logic might need refinement depending on how ResultScreen signals back.
      if (shouldRefresh == true && mounted) {
        // Typically, you'd pop the ResultScreen and return true to the caller.
        // If ResultScreen pushes/replaces, this pop might need adjustment.
        Navigator.of(context).pop(true); 
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<Widget> _buildBulletDescription(String? description) {
    if (description == null || description.isEmpty) return [];
    // Split description into sentences for bullet points. Handles ., !, ? as terminators.
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+')); 
    return sentences
        .where((s) => s.trim().isNotEmpty) // Filter out empty strings
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Allow decimals
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _repsFocusNode.requestFocus(),
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
                onSubmitted: (_) => _dismissKeyboard(),
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
    // Watch authProvider to get the AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for authentication.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Display loading spinner while auth state is loading
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
                    // Show loading indicator only if details are still being fetched
                    if (_isLoadingDetails)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      )
                    else ...[ // Use spread operator for conditional children
                      // Display description points
                      ..._buildBulletDescription(_description),
                      const SizedBox(height: 32),
                      // Show appropriate input fields based on bodyweight status
                      if (_isBodyweight)
                        _buildRepsOnlyInput()
                      else
                        _buildWeightAndRepsInput(),
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit, // Disable button if submitting
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}