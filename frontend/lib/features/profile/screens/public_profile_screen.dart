// frontend/lib/features/profile/screens/public_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_by_username_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../../widgets/loading_spinner.dart';
import '../providers/level_progress_provider.dart';
import '../widgets/energy_graph.dart' show energyGraphProvider;
import 'profile_screen.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String username;

  const PublicProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userByUsernameProvider(username));
    final title = userAsync.maybeWhen(
      data: (user) {
        final display = user.displayName?.trim();
        if (display != null && display.isNotEmpty) {
          return display;
        }
        return '@${user.username}';
      },
      orElse: () => '@$username',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: userAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (error, _) {
          final message = error.toString();
          final display = message.contains('User not found')
              ? 'That athlete could not be found.'
              : 'Something went wrong while loading this profile.';
          return Center(
            child: Text(
              display,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (user) {
          final levelProgressAsync =
              ref.watch(levelProgressByUserProvider(user.id));

          Future<void> refresh() async {
            try {
              final refreshed =
                  await ref.refresh(userByUsernameProvider(username).future);
              ref.invalidate(workoutHistoryProvider(refreshed.id));
              ref.invalidate(levelProgressByUserProvider(refreshed.id));
              ref.invalidate(energyGraphProvider(refreshed.id));
              await ref.read(levelProgressByUserProvider(refreshed.id).future);
            } catch (_) {
              ref.invalidate(userByUsernameProvider(username));
            }
          }

          return ProfileContent(
            user: user,
            levelProgressAsync: levelProgressAsync,
            onRefresh: refresh,
            onRetryLevelProgress: () {
              ref.invalidate(levelProgressByUserProvider(user.id));
            },
          );
        },
      ),
    );
  }
}
