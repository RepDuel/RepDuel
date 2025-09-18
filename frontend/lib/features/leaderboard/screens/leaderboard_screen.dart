// frontend/lib/features/leaderboard/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

              const double avatarSize = 48;

              return ListView.builder(
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

                  return Container(
                    color: rowColor,
                    child: ListTile(
                      leading: _SquareAvatar(
                        size: avatarSize,
                        backgroundColor: Colors.black,
                        avatarUrl: entry.avatarUrl,
                        placeholderBuilder: () => SvgPicture.asset(
                          'assets/images/profile_placeholder.svg',
                          width: avatarSize * 0.8,
                          height: avatarSize * 0.8,
                          fit: BoxFit.contain,
                        ),
                      ),
                      title: Text(
                        '${index + 1}. ${entry.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        '$displayScore $displayUnit',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// A sharp-edged square avatar (no rounding) that shows either a network image
/// or a provided placeholder widget (e.g., an SVG).
class _SquareAvatar extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final String? avatarUrl;
  final Widget Function() placeholderBuilder;

  const _SquareAvatar({
    required this.size,
    required this.backgroundColor,
    required this.avatarUrl,
    required this.placeholderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          // Square edges: no borderRadius
          borderRadius: BorderRadius.zero,
        ),
        child: avatarUrl != null
            ? ClipRRect(
                // keep edges perfectly square
                borderRadius: BorderRadius.zero,
                child: Image.network(
                  avatarUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Center(child: placeholderBuilder()),
                ),
              )
            : Center(child: placeholderBuilder()),
      ),
    );
  }
}
