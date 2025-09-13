// frontend/lib/features/leaderboard/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repduel/core/providers/api_providers.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';

class LeaderboardEntry {
  final String username;
  final String? avatarUrl;
  final double scoreValue;

  LeaderboardEntry({
    required this.username,
    this.avatarUrl,
    required this.scoreValue,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      username: json['user']?['username'] ?? 'Anonymous',
      avatarUrl: json['user']?['avatar_url'],
      scoreValue: (json['score_value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

final leaderboardProvider = FutureProvider.autoDispose
    .family<List<LeaderboardEntry>, String>((ref, scenarioId) async {
  final client = ref.watch(privateHttpClientProvider);
  try {
    final response =
        await client.get('/scores/scenario/$scenarioId/leaderboard');
    final List<dynamic> data = response.data;
    return data
        .where((entry) => entry['user'] != null)
        .map((entry) => LeaderboardEntry.fromJson(entry))
        .toList();
  } catch (_) {
    throw Exception('Failed to load leaderboard. Please try again.');
  }
});

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
    final leaderboardDataAsync = ref.watch(leaderboardProvider(scenarioId));
    final weightMultiplier = ref.watch(authProvider
        .select((state) => state.valueOrNull?.user?.weightMultiplier ?? 1.0));
    final unit = weightMultiplier > 1.5 ? 'lbs' : 'kg';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('$liftName Leaderboard'),
        backgroundColor: Colors.black,
      ),
      body: leaderboardDataAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(
          child: ErrorDisplay(
            message: err.toString(),
            onRetry: () => ref.refresh(leaderboardProvider(scenarioId)),
          ),
        ),
        data: (scores) {
          if (scores.isEmpty) {
            return const Center(
              child: Text(
                'No scores yet. Be the first!',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: scores.length,
            itemBuilder: (_, index) {
              final entry = scores[index];
              final adjustedScore = entry.scoreValue * weightMultiplier;
              final displayScore = adjustedScore % 1 == 0
                  ? adjustedScore.toInt().toString()
                  : adjustedScore.toStringAsFixed(1);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  backgroundImage: entry.avatarUrl != null
                      ? NetworkImage(entry.avatarUrl!)
                      : null,
                  child: entry.avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white54)
                      : null,
                ),
                title: Text(
                  '${index + 1}. ${entry.username}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '$displayScore $unit',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
