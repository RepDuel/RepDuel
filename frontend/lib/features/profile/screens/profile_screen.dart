// frontend/lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/models/level_progress.dart';
import '../../../core/models/quest.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/quests_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../ranked/utils/rank_utils.dart';
import '../providers/level_progress_provider.dart';
import '../widgets/energy_graph.dart';
import '../widgets/activity_feed.dart';

final showGraphProvider = StateProvider.autoDispose<bool>((ref) => false);
final showProgressProvider = StateProvider.autoDispose<bool>((ref) => false);
final _claimingQuestIdsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => <String>{});

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
            ref.invalidate(questsProvider);
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
  final bool showPersonalQuests;
  final Widget? headerAction;

  const ProfileContent({
    super.key,
    required this.user,
    required this.levelProgressAsync,
    required this.onRefresh,
    required this.onRetryLevelProgress,
    this.showPersonalQuests = true,
    this.headerAction,
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
    final questsAsync = showPersonalQuests ? ref.watch(questsProvider) : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;
    const minSectionWidth = 300.0;
    const maxSectionWidth = 600.0;
    final sectionConstraints = BoxConstraints(
      minWidth: isWide ? minSectionWidth : double.infinity,
      maxWidth: isWide ? maxSectionWidth : double.infinity,
    );

    Widget wrapSection(Widget child) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: sectionConstraints,
          child: child,
        ),
      );
    }

    if (showPersonalQuests) {
      ref.listen<int>(scoreEventsProvider, (previous, next) {
        if (previous != null && previous != next) {
          ref.invalidate(questsProvider);
        }
      });

      ref.listen<AsyncValue<List<QuestInstance>>>(questsProvider,
          (previous, next) {
        next.whenData((quests) {
          final claimingIds = ref.read(_claimingQuestIdsProvider);
          for (final quest in quests) {
            if (quest.status != QuestStatus.completed ||
                claimingIds.contains(quest.id)) {
              continue;
            }

            ref
                .read(_claimingQuestIdsProvider.notifier)
                .update((state) => {...state, quest.id});

            Future.microtask(() async {
              try {
                final client = ref.read(privateHttpClientProvider);
                final claimed = await claimQuest(client, quest.id);
                ref.invalidate(questsProvider);
                if (!context.mounted) {
                  return;
                }
                _showQuestClaimedSnackBar(context, claimed);
              } catch (error) {
                if (context.mounted) {
                  _showQuestClaimFailedSnackBar(context);
                }
              } finally {
                ref.read(_claimingQuestIdsProvider.notifier).update((state) {
                  final updated = {...state};
                  updated.remove(quest.id);
                  return updated;
                });
              }
            });
          }
        });
      });
    }

    Future<void> refresh() async {
      ref.read(showGraphProvider.notifier).state = false;
      ref.read(showProgressProvider.notifier).state = false;
      if (showPersonalQuests) {
        ref.invalidate(questsProvider);
      }
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
                if (headerAction != null) ...[
                  const SizedBox(width: 16),
                  headerAction!,
                ],
              ],
            ),
            const SizedBox(height: 32),
            levelProgressAsync.when(
              data: (progress) => wrapSection(
                _LevelProgressSection(
                  progress: progress,
                  showProgress: showProgress,
                  primaryColor: primaryColor,
                  onToggle: () => ref
                      .read(showProgressProvider.notifier)
                      .state = !showProgress,
                ),
              ),
              loading: () => wrapSection(
                  _LevelProgressLoading(primaryColor: primaryColor)),
              error: (error, _) => wrapSection(
                _LevelProgressError(
                  primaryColor: primaryColor,
                  onRetry: onRetryLevelProgress,
                ),
              ),
            ),
            const SizedBox(height: 24),
            wrapSection(
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
            ),
            const SizedBox(height: 32),
            if (showPersonalQuests)
              _RecurringQuestsSection(questsAsync: questsAsync!)
            else
              wrapSection(
                const Text(
                  'Quest progress is private.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
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

void _showQuestClaimedSnackBar(BuildContext context, QuestInstance quest) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
  final theme = Theme.of(context);
  final rewardXp = quest.rewardXp;
  final questTitle =
      quest.template.title.isNotEmpty ? quest.template.title : 'Quest';
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: Colors.green.shade600,
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$questTitle complete! Reward claimed (+$rewardXp XP).',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

void _showQuestClaimFailedSnackBar(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
  final theme = Theme.of(context);
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: theme.colorScheme.error,
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to claim quest reward. Please try again.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

class _RecurringQuestDefinition {
  final String code;
  final QuestCadence cadence;
  final String title;
  final String requirement;
  final int rewardXp;
  final String progressUnitSingular;
  final String progressUnitPlural;

  const _RecurringQuestDefinition({
    required this.code,
    required this.cadence,
    required this.title,
    required this.requirement,
    required this.rewardXp,
    required this.progressUnitSingular,
    required this.progressUnitPlural,
  });

  String get cadenceLabel {
    switch (cadence) {
      case QuestCadence.weekly:
        return 'Weekly quest';
      case QuestCadence.limited:
        return 'Limited quest';
      case QuestCadence.daily:
        return 'Daily quest';
    }
  }

  String formatProgress(int progress, int required) {
    final progressUnit =
        progress == 1 ? progressUnitSingular : progressUnitPlural;
    if (required <= 0) {
      return '$progress $progressUnit';
    }
    final requiredUnit =
        required == 1 ? progressUnitSingular : progressUnitPlural;
    if (progressUnit == requiredUnit) {
      return '$progress/$required $requiredUnit';
    }
    return '$progress $progressUnit / $required $requiredUnit';
  }
}

const _recurringQuestDefinitions = <_RecurringQuestDefinition>[
  _RecurringQuestDefinition(
    code: 'daily_30_min_workout',
    cadence: QuestCadence.daily,
    title: 'Daily 30-Minute Workout',
    requirement: 'Complete a 30+ minute workout.',
    rewardXp: 100,
    progressUnitSingular: 'min',
    progressUnitPlural: 'min',
  ),
  _RecurringQuestDefinition(
    code: 'weekly_30_min_workout_three_days',
    cadence: QuestCadence.weekly,
    title: 'Weekly Consistency Challenge',
    requirement:
        'Complete a 30+ minute workout on three separate days this week.',
    rewardXp: 300,
    progressUnitSingular: 'day',
    progressUnitPlural: 'days',
  ),
];

class _RecurringQuestsSection extends StatelessWidget {
  final AsyncValue<List<QuestInstance>> questsAsync;

  const _RecurringQuestsSection({required this.questsAsync});

  QuestInstance? _findQuest(List<QuestInstance> quests, String code) {
    for (final quest in quests) {
      if (quest.template.code == code) {
        return quest;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;
    const minWidth = 300.0;
    const maxWidth = 600.0;
    final boxConstraints = BoxConstraints(
      minWidth: isWide ? minWidth : double.infinity,
      maxWidth: isWide ? maxWidth : double.infinity,
    );

    Widget wrapWithWidth(Widget child, {bool addBottomMargin = false}) {
      return Container(
        alignment: Alignment.centerLeft,
        margin: addBottomMargin
            ? const EdgeInsets.only(bottom: 12)
            : EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: boxConstraints,
          child: child,
        ),
      );
    }

    final content = questsAsync.when<Widget>(
      data: (quests) {
        final children = <Widget>[];
        for (var i = 0; i < _recurringQuestDefinitions.length; i++) {
          final definition = _recurringQuestDefinitions[i];
          children.add(wrapWithWidth(
            _RecurringQuestCard(
              definition: definition,
              instance: _findQuest(quests, definition.code),
            ),
            addBottomMargin: true,
          ));
        }
        return Column(children: children);
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: wrapWithWidth(
          const Center(child: LoadingSpinner(size: 36)),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: wrapWithWidth(
          Text(
            'Unable to load quests: $error',
            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}

class _RecurringQuestCard extends StatelessWidget {
  final _RecurringQuestDefinition definition;
  final QuestInstance? instance;

  const _RecurringQuestCard({required this.definition, required this.instance});

  String _statusLabel(QuestStatus status) {
    switch (status) {
      case QuestStatus.completed:
        return 'Completed';
      case QuestStatus.claimed:
        return 'Claimed';
      case QuestStatus.expired:
        return 'Expired';
      case QuestStatus.active:
        return 'Active';
    }
  }

  Color _statusColor(QuestStatus status, ThemeData theme) {
    switch (status) {
      case QuestStatus.completed:
        return Colors.amberAccent;
      case QuestStatus.claimed:
        return Colors.lightGreenAccent;
      case QuestStatus.expired:
        return Colors.redAccent;
      case QuestStatus.active:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questStatus = instance?.status;
    final statusLabel =
        questStatus != null ? _statusLabel(questStatus) : 'Unavailable';
    final statusColor =
        questStatus != null ? _statusColor(questStatus, theme) : Colors.white54;
    final String? progressLabel = instance != null
        ? definition.formatProgress(instance!.progress, instance!.required)
        : null;
    final double progressValue = instance == null
        ? 0.0
        : instance!.progressPct.clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      definition.cadenceLabel,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _XpRewardPill(rewardXp: definition.rewardXp),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            definition.requirement,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (instance == null)
            const Text(
              'Log your workouts to start making progress on this quest.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressLabel!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _XpRewardPill extends StatelessWidget {
  final int rewardXp;

  const _XpRewardPill({required this.rewardXp});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '+$rewardXp XP',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
        const SizedBox(
          width: 24,
          height: 24,
          child: LoadingSpinner(size: 24),
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
