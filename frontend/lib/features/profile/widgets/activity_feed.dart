// frontend/lib/features/profile/widgets/activity_feed.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../core/providers/user_by_id_provider.dart';
import '../../../core/models/user.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../ranked/utils/rank_utils.dart';

class ActivityFeed extends ConsumerWidget {
  final String userId;

  const ActivityFeed({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When scores change anywhere (finishing a routine or logging a score),
    // invalidate the history so this feed stays fresh.
    ref.listen<int>(scoreEventsProvider, (prev, next) {
      ref.invalidate(workoutHistoryProvider(userId));
    });

    final historyAsync = ref.watch(workoutHistoryProvider(userId));
    final authAsync = ref.watch(authProvider);

    final userMultiplier = authAsync.valueOrNull?.user?.weightMultiplier ?? 1.0;
    final isLbs = userMultiplier > 1.5;
    const kgToLbs = 2.20462;
    final unit = isLbs ? 'lb' : 'kg';

    num toUserUnit(num kg) => isLbs ? (kg * kgToLbs) : kg;

    String formatNum(num n) =>
        (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

    String scenarioTitle(String id) {
      return id
          .split('_')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }

    String timeAgo(DateTime dt) {
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return 'about ${diff.inMinutes} minutes ago';
      if (diff.inHours < 24) return 'about ${diff.inHours} hours ago';
      if (diff.inDays < 7) return 'about ${diff.inDays} days ago';
      // Beyond a week, show a short date
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$y-$m-$d';
    }

    double calcScoreValue({
      required bool isBodyweight,
      required double weight,
      required int reps,
    }) {
      if (isBodyweight) return reps.toDouble();
      if (reps <= 1) return weight;
      return weight * (1 + reps / 30.0);
    }

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No activity yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        // Build a combined list of compact feed events (workouts + inferred PBs),
        // then render in reverse chronological order.
        final asc = [...entries]
          ..sort((a, b) => DateTime.parse(a.completionTimestamp)
              .compareTo(DateTime.parse(b.completionTimestamp)));

        final bestByScenario = <String, double>{};
        final feed = <_FeedEvent>[];

        for (final entry in asc) {
          final when = DateTime.parse(entry.completionTimestamp).toLocal();

          // Workout summary event
          final totalVolumeUser = entry.scenarios.fold<double>(
            0.0,
            (sum, s) => sum + toUserUnit(s.totalVolume),
          );

          final durationLabel = _formatDuration(entry.duration);

          // Personal bests inferred for this single entry (one per exercise)
          final perEntryPBs = <_PersonalBestLine>[];
          final Map<String, _PBValue> entryMaxByScenario = {};
          for (final s in entry.scenarios) {
            if (s.reps <= 0) continue; // ignore empty sets
            final isBw = s.scenarioId.startsWith('bodyweight_');
            final score = calcScoreValue(
              isBodyweight: isBw,
              weight: s.weight,
              reps: s.reps,
            );
            final current = entryMaxByScenario[s.scenarioId];
            if (current == null || score > current.score) {
              entryMaxByScenario[s.scenarioId] = _PBValue(
                score: score,
                reps: s.reps,
                weightKg: s.weight,
                isBodyweight: isBw,
              );
            }
          }

          // After we know the best set per exercise for this entry,
          // compare once with all‑time best and add at most one PB line.
          entryMaxByScenario.forEach((scenarioId, val) {
            final prevBest = bestByScenario[scenarioId];
            if (prevBest == null || val.score > prevBest) {
              bestByScenario[scenarioId] = val.score;
              final exercise = scenarioTitle(scenarioId);
              final repsLabel = val.reps == 1 ? 'rep' : 'reps';
              final subtitle = val.isBodyweight
                  ? '${val.reps} $repsLabel'
                  : '${formatNum(toUserUnit(val.weightKg))} $unit × ${val.reps} $repsLabel';
              perEntryPBs.add(
                _PersonalBestLine(
                  exerciseName: exercise,
                  detail: subtitle,
                ),
              );
            }
          });

          // Single combined feed event per workout entry, with PBs listed below
          feed.add(
            _FeedEvent(
              when: when,
              kind: _FeedKind.workout,
              title: 'completed ${entry.title}',
              subtitle:
                  'Volume ${formatNum(totalVolumeUser)} $unit • Duration $durationLabel',
              icon: Icons.fitness_center,
              accent: Colors.blueAccent,
              userId: entry.userId,
              personalBests: perEntryPBs,
            ),
          );
        }

        // Newest first
        feed.sort((a, b) => b.when.compareTo(a.when));

        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = screenWidth > 700;
        const minWidth = 300.0;
        const maxWidth = 600.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: feed.map((e) {
            return Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isWide ? minWidth : double.infinity,
                  maxWidth: isWide ? maxWidth : double.infinity,
                ),
                child: _FeedTile(event: e, timeAgoText: timeAgo(e.when)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDuration(double minutes) {
    final totalSeconds = (minutes * 60).round();
    final hours = totalSeconds ~/ 3600;
    final minutesPart = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      final twoDigitMinutes = minutesPart.toString().padLeft(2, '0');
      final twoDigitSeconds = seconds.toString().padLeft(2, '0');
      return '$hours:$twoDigitMinutes:$twoDigitSeconds';
    }

    if (minutesPart > 0) {
      final twoDigitSeconds = seconds.toString().padLeft(2, '0');
      return '$minutesPart:$twoDigitSeconds';
    }

    return '${seconds}s';
  }
}

enum _FeedKind { workout }

class _FeedEvent {
  final DateTime when;
  final _FeedKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String userId;
  final List<_PersonalBestLine> personalBests;

  _FeedEvent({
    required this.when,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.userId,
    this.personalBests = const [],
  });
}

class _PersonalBestLine {
  final String exerciseName;
  final String detail;
  const _PersonalBestLine({required this.exerciseName, required this.detail});
}

class _PBValue {
  final double score;
  final int reps;
  final double weightKg;
  final bool isBodyweight;
  const _PBValue({
    required this.score,
    required this.reps,
    required this.weightKg,
    required this.isBodyweight,
  });
}

class _FeedTile extends ConsumerWidget {
  final _FeedEvent event;
  final String timeAgoText;

  const _FeedTile({required this.event, required this.timeAgoText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).valueOrNull?.user;
    if (me != null && me.id == event.userId) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: _rowWith(
          context,
          user: me,
          username: _displayName(me),
          avatarUrl: me.avatarUrl,
        ),
      );
    }

    final userAsync = ref.watch(userByIdProvider(event.userId));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: userAsync.when(
        loading: () => _rowSkeleton(),
        error: (e, s) => _rowWith(
          context,
          user: null,
          username: 'Unknown',
          avatarUrl: null,
        ),
        data: (user) => _rowWith(
          context,
          user: user,
          username: _displayName(user),
          avatarUrl: user.avatarUrl,
        ),
      ),
    );
  }

  String _displayName(User user) {
    final dn = user.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    return user.username;
  }

  Widget _rowSkeleton() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Shimmer(width: 36, height: 36),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top line: display name
              _Shimmer(width: 140, height: 12),
              SizedBox(height: 8),
              // title with leading icon
              Row(
                children: [
                  // icon placeholder
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  _Shimmer(width: 240, height: 12),
                ],
              ),
              SizedBox(height: 4),
              _Shimmer(width: 200, height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rowWith(BuildContext context, {required User? user, required String username, String? avatarUrl}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(avatarUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: Display Name
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      username,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _rankColor(user?.rank),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (user?.rank != null) ...[
                    const SizedBox(width: 6),
                    _rankBadge(user!.rank!),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: event.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(event.icon, size: 14, color: event.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _capitalize(event.title),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                event.subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (event.personalBests.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: event.personalBests.map((pb) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events, size: 12, color: Colors.amberAccent),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Personal best • ${pb.exerciseName}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pb.detail,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                timeAgoText,
                style: const TextStyle(
                  color: Colors.white60,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // header label removed from layout; using only leading icon next to title

  Widget _avatar(String? avatarUrl, {double size = 28}) {
    final borderRadius = BorderRadius.circular(size / 2);
    if (_looksLikeRemoteImage(avatarUrl)) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(size),
        ),
      );
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(size),
        ),
      );
    }
    return _defaultAvatar(size);
  }

  bool _looksLikeRemoteImage(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }
    return !uri.hasScheme && uri.hasAbsolutePath;
  }

  Widget _defaultAvatar(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.asset(
        'assets/images/default_nonbinary.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// Discord-style timestamp removed; relying on relative time below the content.

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

Color _rankColor(String? rank) {
  if (rank == null || rank.trim().isEmpty) return Colors.white;
  return getRankColor(rank);
}

Widget _rankBadge(String rank) {
  final path = 'assets/images/ranks/${rank.toLowerCase()}.svg';
  return SvgPicture.asset(
    path,
    width: 16,
    height: 16,
  );
}
