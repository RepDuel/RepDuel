// frontend/lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/models/level_progress.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../ranked/utils/rank_utils.dart';
import '../providers/level_progress_provider.dart';
import '../widgets/energy_graph.dart';
import '../widgets/activity_feed.dart';

final showGraphProvider = StateProvider.autoDispose<bool>((ref) => false);
final showProgressProvider = StateProvider.autoDispose<bool>((ref) => false);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: authStateAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (authState) {
          final user = authState.user;
          if (user == null) {
            return const Center(child: Text('Not logged in.'));
          }

          final levelProgressAsync = ref.watch(levelProgressProvider);

          Future<void> refresh() async {
            try {
              await ref.read(authProvider.notifier).refreshUserData();
            } catch (_) {}
            ref.invalidate(workoutHistoryProvider(user.id));
            ref.invalidate(levelProgressProvider);
            try {
              await ref.read(levelProgressProvider.future);
            } catch (_) {}
          }

          return ProfileContent(
            user: user,
            levelProgressAsync: levelProgressAsync,
            onRefresh: refresh,
            onRetryLevelProgress: () {
              ref.invalidate(levelProgressProvider);
            },
          );
        },
      ),
    );
  }
}

class ProfileContent extends ConsumerWidget {
  final User user;
  final AsyncValue<LevelProgress> levelProgressAsync;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryLevelProgress;

  const ProfileContent({
    super.key,
    required this.user,
    required this.levelProgressAsync,
    required this.onRefresh,
    required this.onRetryLevelProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final rank = user.rank ?? 'Unranked';
    final energy = user.energy.round();
    final rankColor = getRankColor(rank);
    final iconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';
    final showGraph = ref.watch(showGraphProvider);
    final showProgress = ref.watch(showProgressProvider);

    Future<void> refresh() async {
      ref.read(showGraphProvider.notifier).state = false;
      ref.read(showProgressProvider.notifier).state = false;
      await onRefresh();
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildAvatar(user.avatarUrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            levelProgressAsync.when(
              data: (progress) => _LevelProgressSection(
                progress: progress,
                showProgress: showProgress,
                primaryColor: primaryColor,
                onToggle: () => ref
                    .read(showProgressProvider.notifier)
                    .state = !showProgress,
              ),
              loading: () => _LevelProgressLoading(primaryColor: primaryColor),
              error: (error, _) => _LevelProgressError(
                primaryColor: primaryColor,
                onRetry: onRetryLevelProgress,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Energy: ',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      '$energy $rank',
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(iconPath, height: 24, width: 24),
                    const Spacer(),
                    TextButton(
                      onPressed: () => ref
                          .read(showGraphProvider.notifier)
                          .state = !showGraph,
                      child: Text(
                        showGraph ? 'Hide Graph' : 'View Graph',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
                if (showGraph) const SizedBox(height: 8),
                if (showGraph)
                  SizedBox(
                    height: 200,
                    child: EnergyGraph(userId: user.id),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ActivityFeed(userId: user.id),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

Widget _buildAvatar(String? avatarUrl, {double size = 80}) {
  if (_looksLikeRemoteImage(avatarUrl)) {
    return Image.network(
      avatarUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildDefaultAvatar(size),
    );
  }

  if (avatarUrl != null &&
      avatarUrl.isNotEmpty &&
      avatarUrl.startsWith('assets/')) {
    return Image.asset(
      avatarUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildDefaultAvatar(size),
    );
  }

  return _buildDefaultAvatar(size);
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

Widget _buildDefaultAvatar(double size) {
  return Image.asset(
    'assets/images/default_nonbinary.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
}

class _LevelProgressSection extends StatelessWidget {
  final LevelProgress progress;
  final bool showProgress;
  final VoidCallback onToggle;
  final Color primaryColor;

  const _LevelProgressSection({
    required this.progress,
    required this.showProgress,
    required this.onToggle,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Level: ',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              '${progress.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onToggle,
              child: Text(
                showProgress ? 'Hide Progress' : 'View Progress',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
        if (showProgress) const SizedBox(height: 8),
        if (showProgress)
          _LevelProgressDetails(
            progress: progress,
            primaryColor: primaryColor,
          ),
      ],
    );
  }
}

class _LevelProgressLoading extends StatelessWidget {
  final Color primaryColor;

  const _LevelProgressLoading({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Level: ',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryColor,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: null,
          style: TextButton.styleFrom(
            foregroundColor: primaryColor.withValues(alpha: 0.6),
          ),
          child: const Text('View Progress'),
        ),
      ],
    );
  }
}

class _LevelProgressError extends StatelessWidget {
  final VoidCallback onRetry;
  final Color primaryColor;

  const _LevelProgressError({
    required this.onRetry,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Level: ',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const Text(
              '--',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Unable to load level progress. Tap retry to try again.',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ],
    );
  }
}

class _LevelProgressDetails extends StatelessWidget {
  final LevelProgress progress;
  final Color primaryColor;

  const _LevelProgressDetails({
    required this.progress,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    final totalXp = formatter.format(progress.xp);
    final xpWeek = formatter.format(progress.xpGainedThisWeek);
    final xpToNext = formatter.format(progress.xpToNext);
    final percent = ((progress.progressPct * 100).clamp(0, 100)).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LevelProgressDetailRow(label: 'Total XP', value: totalXp),
          const SizedBox(height: 6),
          _LevelProgressDetailRow(
            label: 'XP gained this week',
            value: xpWeek,
          ),
          const SizedBox(height: 6),
          _LevelProgressDetailRow(
            label: 'XP to next level',
            value: xpToNext,
          ),
          const SizedBox(height: 12),
          Text(
            'Progress to next level: ${percent.toStringAsFixed(1)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progressPct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelProgressDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _LevelProgressDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
