// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../../ranked/utils/rank_utils.dart';

class EnergyLeaderboardEntry {
  final String displayName;
  final int totalEnergy;
  final String userRank;

  EnergyLeaderboardEntry({
    required this.displayName,
    required this.totalEnergy,
    required this.userRank,
  });

  factory EnergyLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final userNode = json['user'] as Map<String, dynamic>?;
    final displayName = json['display_name'] ??
        json['displayName'] ??
        userNode?['display_name'] ??
        userNode?['displayName'];
    final username = json['username'] ?? userNode?['username'];
    final rank = json['user_rank'] ?? userNode?['rank'];
    return EnergyLeaderboardEntry(
      displayName: _resolveDisplayName(displayName, username),
      totalEnergy: (json['total_energy'] ?? 0).round(),
      userRank: (rank is String && rank.isNotEmpty) ? rank : 'Unranked',
    );
  }
}

String _resolveDisplayName(dynamic rawDisplayName, dynamic fallbackName) {
  final displayName = rawDisplayName is String ? rawDisplayName.trim() : '';
  if (displayName.isNotEmpty) {
    return displayName;
  }

  final username = fallbackName is String ? fallbackName.trim() : '';
  return username.isNotEmpty ? username : 'Anonymous';
}

final energyLeaderboardProvider =
    FutureProvider.autoDispose<List<EnergyLeaderboardEntry>>((ref) async {
  final client = ref.watch(privateHttpClientProvider);
  final response = await client.get('/energy/leaderboard');
  final data = response.data as List<dynamic>;
  return data.map((entry) => EnergyLeaderboardEntry.fromJson(entry)).toList();
});

class EnergyLeaderboardScreen extends ConsumerWidget {
  const EnergyLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(scoreEventsProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      ref.invalidate(energyLeaderboardProvider);
    });

    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      if (previous == null) {
        return;
      }
      final previousUser = previous.valueOrNull?.user;
      final nextUser = next.valueOrNull?.user;
      final previousName = previousUser?.displayName ?? previousUser?.username;
      final nextName = nextUser?.displayName ?? nextUser?.username;

      if (previousName != nextName) {
        ref.invalidate(energyLeaderboardProvider);
      }
    });

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
                    final entryRank = entry.userRank;
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
                              entry.displayName,
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
