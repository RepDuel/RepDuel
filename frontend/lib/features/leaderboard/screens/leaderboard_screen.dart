// frontend/lib/features/leaderboard/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart'; // Import the auth provider correctly

// --- Step 1: Create a Model for Type Safety ---

class LeaderboardEntry {
  final LeaderboardUser user;
  final num weightLifted;

  LeaderboardEntry({required this.user, required this.weightLifted});

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      user: LeaderboardUser.fromJson(json['user'] ?? {}),
      weightLifted: json['weight_lifted'] ?? 0,
    );
  }
}

class LeaderboardUser {
  final String username;

  LeaderboardUser({required this.username});

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardUser(
      username: json['username'] ?? 'Anonymous',
    );
  }
}

// --- Step 2: Create a Provider for Data Fetching ---

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, String>((ref, scenarioId) async {
  // Get the token safely. This is crucial for authenticated requests.
  // If the token is null (auth is loading/errored/logged out), the request will likely fail
  // at the interceptor level, or the provider will be in a loading/error state anyway.
  final token = ref.read(authProvider).valueOrNull?.token; // Safely get token

  // If you strictly need the token for the URL itself (unlikely for this endpoint, but possible),
  // you'd handle that here. For now, we assume the interceptor adds it.
  // If the token is missing, the interceptor will block, and this provider will error.

  final url = '${Env.baseUrl}/api/v1/scores/scenario/$scenarioId/leaderboard';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      // Headers are typically handled by the HttpClient/Dio interceptor, 
      // but you could add them here if needed for specific endpoints.
      // headers: {'Authorization': 'Bearer $token'} // Example, usually handled by interceptor
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      
      return data
          .where((entry) => entry['user'] != null)
          .map((entry) => LeaderboardEntry.fromJson(entry))
          .toList();
    } else {
      throw Exception('Failed to load leaderboard: Status code ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load leaderboard: $e');
  }
});


// --- Step 3: Refactor the Widget to use AsyncValue.when() ---

class LeaderboardScreen extends ConsumerWidget {
  final String scenarioId;
  final String liftName;

  const LeaderboardScreen({
    super.key,
    required this.scenarioId,
    required this.liftName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider to get the state (data, loading, or error).
    final AsyncValue<List<LeaderboardEntry>> leaderboardData = ref.watch(leaderboardProvider(scenarioId));
    
    // --- Safely Access User Data for Units ---
    // Watch authProvider to get the AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle different auth states and extract user data.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Show loading for auth state if not yet loaded
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold( // Show error if auth state fails
        backgroundColor: Colors.black,
        body: Center(child: Text('Auth Error: $err', style: const TextStyle(color: Colors.red))),
      ),
      data: (authState) { // authState is the actual AuthState object
        // Safely get the user from the loaded AuthState.
        final user = authState.user; 

        // Determine units based on user data. If user is null (logged out, etc.),
        // default to sensible units (e.g., kg).
        final isKg = user?.weightMultiplier == 1.0;
        final multiplier = user?.weightMultiplier ?? 1.0;
        final unit = isKg ? 'kg' : 'lbs';

        // --- Now render the leaderboard based on leaderboardData ---
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text('$liftName Leaderboard'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          // Use AsyncValue.when for clean handling of all possible states for leaderboardData.
          body: leaderboardData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (scores) {
              // Handle the case where scores might be empty but data loaded successfully
              if (scores.isEmpty) {
                return const Center(
                  child: Text(
                    'No scores available yet. Be the first!', 
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text('Rank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        Text('Score', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: scores.length,
                      itemBuilder: (_, index) {
                        final scoreEntry = scores[index];
                        
                        final adjustedScore = scoreEntry.weightLifted * multiplier;
                        final displayScore = adjustedScore % 1 == 0
                            ? adjustedScore.toInt().toString()
                            : adjustedScore.toStringAsFixed(1);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                // Safely access username from the model
                                child: Text(
                                  scoreEntry.user.username, 
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ),
                              Text(
                                '$displayScore $unit',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}