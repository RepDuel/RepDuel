// frontend/lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/workout_history_provider.dart';
import '../../ranked/utils/rank_utils.dart';
import '../widgets/energy_graph.dart';
import '../widgets/workout_history_list.dart';

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
                        child:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? Image.network(
                                    user.avatarUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) =>
                                        _buildPlaceholderAvatar(),
                                  )
                                : _buildPlaceholderAvatar(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          user.username,
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
                            '$energy ',
                            style: TextStyle(
                              color: rankColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    'Workout History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  WorkoutHistoryList(userId: user.id),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Image.asset(
      'assets/images/profile_placeholder.png',
      width: 80,
      height: 80,
      fit: BoxFit.cover,
    );
  }
}
