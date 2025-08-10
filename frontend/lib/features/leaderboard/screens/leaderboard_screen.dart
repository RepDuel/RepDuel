// frontend/lib/features/leaderboard/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';

// --- Step 1: Create a Model for Type Safety ---

class LeaderboardEntry {
  final LeaderboardUser user;
  final num weightLifted;

  LeaderboardEntry({required this.user, required this.weightLifted});

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    // This provides robust parsing. If 'user' is null, it will be handled gracefully.
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

// We use a .family provider because we need to pass the `scenarioId` to it.
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, String>((ref, scenarioId) async {
  
  // Best Practice: The API call is now inside the provider, not the widget.
  final url = '${Env.baseUrl}/api/v1/scores/scenario/$scenarioId/leaderboard';
  
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      
      // Filter out entries with null users and parse into our strongly-typed model.
      return data
          .where((entry) => entry['user'] != null)
          .map((entry) => LeaderboardEntry.fromJson(entry))
          .toList();
    } else {
      // Throw an exception to put the provider into an error state.
      throw Exception('Failed to load leaderboard: Status code ${response.statusCode}');
    }
  } catch (e) {
    // Rethrow the error to be caught by AsyncValue.when in the UI.
    throw Exception('Failed to load leaderboard: $e');
  }
});


// --- Step 3: Refactor the Widget to be Stateless ---

// The widget is now a simple ConsumerWidget, no StatefulWidget or State needed.
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
    
    // Get user preferences for displaying units.
    final user = ref.watch(authProvider).user;
    final isKg = user?.weightMultiplier == 1.0;
    final multiplier = user?.weightMultiplier ?? 1.0;
    final unit = isKg ? 'kg' : 'lbs';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('$liftName Leaderboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      // Use AsyncValue.when for clean handling of all possible states.
      body: leaderboardData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (scores) => Column(
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
                  
                  // Use the data from our type-safe model.
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
                          child: Text(
                            scoreEntry.user.username, // Safe access
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
        ),
      ),
    );
  }
}