// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_providers.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';

class EnergyLeaderboardEntry {
  final String username;
  final int totalEnergy;

  EnergyLeaderboardEntry({
    required this.username,
    required this.totalEnergy,
  });

  factory EnergyLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final userNode = json['user'] as Map<String, dynamic>?;
    final name = json['username'] ?? userNode?['username'];
    return EnergyLeaderboardEntry(
      username: (name is String && name.isNotEmpty) ? name : 'Anonymous',
      totalEnergy: (json['total_energy'] ?? 0).round(),
    );
  }
}

final energyLeaderboardProvider =
    FutureProvider<List<EnergyLeaderboardEntry>>((ref) async {
  final client = ref.watch(privateHttpClientProvider);
  final response = await client.get('/energy/leaderboard');
  final data = response.data as List<dynamic>;
  return data.map((entry) => EnergyLeaderboardEntry.fromJson(entry)).toList();
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
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(
          child: ErrorDisplay(
            message: err.toString(),
            onRetry: () => ref.refresh(energyLeaderboardProvider),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No scores yet. Be the first!',
                style: TextStyle(color: Colors.white54, fontSize: 16),
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
                      child: Text(
                        'Rank',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
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
                    final rowColor = index.isEven
                        ? const Color(0xFF101218)
                        : const Color(0xFF0B0D13);

                    return Container(
                      color: rowColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
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
  }
}
