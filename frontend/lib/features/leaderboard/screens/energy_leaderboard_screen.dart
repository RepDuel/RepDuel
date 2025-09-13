// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';

class EnergyLeaderboardEntry {
  final String username;
  final int totalEnergy;

  EnergyLeaderboardEntry({required this.username, required this.totalEnergy});

  factory EnergyLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return EnergyLeaderboardEntry(
      username: json['username'] ?? 'Anonymous',
      totalEnergy: (json['total_energy'] ?? 0).round(),
    );
  }
}

final energyLeaderboardProvider =
    FutureProvider<List<EnergyLeaderboardEntry>>((ref) async {
  final url = '${Env.baseUrl}/api/v1/energy/leaderboard';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((entry) => EnergyLeaderboardEntry.fromJson(entry))
          .toList();
    } else {
      throw Exception(
          'Failed to load leaderboard: Status code ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load leaderboard: $e');
  }
});

class EnergyLeaderboardScreen extends ConsumerWidget {
  const EnergyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EnergyLeaderboardEntry>> leaderboardData =
        ref.watch(energyLeaderboardProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Energy Leaderboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: leaderboardData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (entries) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      'Rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'User',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Energy',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, index) {
                  final entry = entries[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.totalEnergy}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
