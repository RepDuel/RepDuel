// frontend/lib/features/leaderboard/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/core/providers/api_providers.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';

class LeaderboardEntry {
  final String displayName;
  final double scoreValue;
  final String username;

  LeaderboardEntry({
    required this.displayName,
    required this.scoreValue,
    required this.username,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final userNode = json['user'] as Map<String, dynamic>?;
    final rawDisplayName = json['display_name'] ??
        userNode?['display_name'] ??
        userNode?['displayName'];
    final rawUsername = json['username'] ?? userNode?['username'];

    return LeaderboardEntry(
      displayName: _resolveDisplayName(rawDisplayName, rawUsername),
      scoreValue: (json['score_value'] as num?)?.toDouble() ?? 0.0,
      username: rawUsername is String ? rawUsername.trim() : '',
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

final scenarioDetailsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, scenarioId) async {
    final client = ref.watch(privateHttpClientProvider);
    final response = await client.get('/scenarios/$scenarioId/details');
    if (response.statusCode == 200) {
      return (response.data as Map).cast<String, dynamic>();
    }
    throw Exception('Failed to load scenario details.');
  },
);

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
    ref.listen<int>(scoreEventsProvider, (previous, next) {
      if (previous == null || previous == next) {
        return;
      }
      ref.invalidate(leaderboardProvider(scenarioId));
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
        ref.invalidate(leaderboardProvider(scenarioId));
      }
    });

    final leaderboardDataAsync = ref.watch(leaderboardProvider(scenarioId));
    final scenarioAsync = ref.watch(scenarioDetailsProvider(scenarioId));
    final authState =
        ref.watch(authProvider.select((s) => s.valueOrNull?.user));
    final weightMultiplier = (authState?.weightMultiplier ?? 1.0).toDouble();
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
          return scenarioAsync.when(
            loading: () => const Center(child: LoadingSpinner()),
            error: (err, _) => Center(
              child: ErrorDisplay(
                message: err.toString(),
                onRetry: () => ref.refresh(scenarioDetailsProvider(scenarioId)),
              ),
            ),
            data: (scenario) {
              final isBodyweight =
                  (scenario['is_bodyweight'] as bool?) ?? false;
              final displayUnit = isBodyweight ? 'reps' : unit;
              final multiplier = isBodyweight ? 1.0 : weightMultiplier;

              if (scores.isEmpty) {
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const SizedBox(
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
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Text(
                            'User',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          isBodyweight ? 'Reps' : 'Score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: scores.length,
                      itemBuilder: (_, index) {
                        final entry = scores[index];
                        final adjustedScore = entry.scoreValue * multiplier;
                        final displayScore = adjustedScore % 1 == 0
                            ? adjustedScore.toInt().toString()
                            : adjustedScore.toStringAsFixed(1);

                        final rowColor = index.isEven
                            ? const Color(0xFF101218)
                            : const Color(0xFF0B0D13);

                        final username = entry.username;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: username.isEmpty
                                ? null
                                : () => context.pushNamed(
                                      'rankedPublicProfile',
                                      pathParameters: {'username': username},
                                    ),
                            child: Container(
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
                                  Text(
                                    '$displayScore $displayUnit',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
