// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/env.dart';

// --- Step 1: Create a Model for Type Safety ---

class EnergyLeaderboardEntry {
  final String username;
  final int totalEnergy;

  EnergyLeaderboardEntry({required this.username, required this.totalEnergy});

  factory EnergyLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return EnergyLeaderboardEntry(
      username: json['username'] ?? 'Anonymous',
      // Ensure total_energy is treated as an integer, defaulting to 0 if null.
      totalEnergy: (json['total_energy'] ?? 0).round(),
    );
  }
}

// --- Step 2: Create a Provider for Data Fetching ---

// A simple FutureProvider is perfect here since it doesn't need any parameters.
final energyLeaderboardProvider = FutureProvider<List<EnergyLeaderboardEntry>>((ref) async {

  // The API call logic now lives inside the provider.
  final url = '${Env.baseUrl}/api/v1/energy/leaderboard';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      
      // Parse the raw JSON list into our strongly-typed model.
      return data.map((entry) => EnergyLeaderboardEntry.fromJson(entry)).toList();
    } else {
      // Let Riverpod handle the error state by throwing an exception.
      throw Exception('Failed to load leaderboard: Status code ${response.statusCode}');
    }
  } catch (e) {
    // Rethrow the error to be caught by AsyncValue.when in the UI.
    throw Exception('Failed to load leaderboard: $e');
  }
});

// --- Step 3: Refactor the Widget to be Stateless and Use the Provider ---

class EnergyLeaderboardScreen extends ConsumerWidget {
  const EnergyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider to get its current state (data, loading, or error).
    final AsyncValue<List<EnergyLeaderboardEntry>> leaderboardData = ref.watch(energyLeaderboardProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Energy Leaderboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      // Use AsyncValue.when for clean and robust state handling.
      body: leaderboardData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (entries) => Column(
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
                  Text('Energy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, index) {
                  final entry = entries[index];

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
                            entry.username, // Safe access from our model
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        Text(
                          '${entry.totalEnergy}', // Safe access from our model
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