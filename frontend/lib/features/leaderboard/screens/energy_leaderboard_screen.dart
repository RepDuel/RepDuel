// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../../ranked/utils/rank_utils.dart';

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

String _rankForEnergy(int energy) {
  String currentRank = 'Iron';
  int currentThreshold = 0;
  rankEnergy.forEach((rank, threshold) {
    if (energy >= threshold && threshold >= currentThreshold) {
      currentRank = rank;
      currentThreshold = threshold;
    }
  });
  return currentRank;
}

class EnergyLeaderboardScreen extends ConsumerWidget {
  const EnergyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EnergyLeaderboardEntry>> leaderboardData =
        ref.watch(energyLeaderboardProvider);
    final user = ref.watch(authProvider).valueOrNull?.user;
    final officialEnergy = user?.energy.round();
    final officialRank = user?.rank ?? 'Unranked';
    final overallColor = getRankColor(officialRank);

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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: const [
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
                    final entryRank = _rankForEnergy(entry.totalEnergy);
                    final entryRankColor = getRankColor(entryRank);

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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${entry.totalEnergy} $entryRank',
                                style: TextStyle(
                                  color: entryRankColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SvgPicture.asset(
                                'assets/images/ranks/${entryRank.toLowerCase()}.svg',
                                height: 20,
                                width: 20,
                              ),
                            ],
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
