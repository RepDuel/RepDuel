// frontend/lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../ranked/utils/rank_utils.dart';
import '../widgets/energy_graph.dart';
import '../widgets/activity_feed.dart';

final showGraphProvider = StateProvider.autoDispose<bool>((ref) => false);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

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

          final rank = user.rank ?? 'Unranked';
          final energy = user.energy.round();
          final rankColor = getRankColor(rank);
          final iconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';
          final showGraph = ref.watch(showGraphProvider);

          Future<void> refresh() async {
            try {
              await ref.read(authProvider.notifier).refreshUserData();
            } catch (_) {}
            ref.invalidate(workoutHistoryProvider(user.id));
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
        },
      ),
    );
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
}
