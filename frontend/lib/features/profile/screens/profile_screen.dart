// frontend/lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/energy_providers.dart';
import '../widgets/energy_graph.dart';
import '../widgets/workout_history_list.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showGraph = false;

  String getRank(int energy) {
    if (energy >= 1200) return 'Celestial';
    if (energy >= 1100) return 'Astra';
    if (energy >= 1000) return 'Nova';
    if (energy >= 900) return 'Grandmaster';
    if (energy >= 800) return 'Master';
    if (energy >= 700) return 'Jade';
    if (energy >= 600) return 'Diamond';
    if (energy >= 500) return 'Platinum';
    if (energy >= 400) return 'Gold';
    if (energy >= 300) return 'Silver';
    if (energy >= 200) return 'Bronze';
    return 'Iron';
  }

  Color getRankColor(String rank) {
    switch (rank) {
      case 'Iron':
        return Colors.grey;
      case 'Bronze':
        return const Color(0xFFcd7f32);
      case 'Silver':
        return const Color(0xFFc0c0c0);
      case 'Gold':
        return const Color(0xFFefbf04);
      case 'Platinum':
        return const Color(0xFF00ced1);
      case 'Diamond':
        return const Color(0xFFb9f2ff);
      case 'Jade':
        return const Color(0xFF62f40c);
      case 'Master':
        return const Color(0xFFff00ff);
      case 'Grandmaster':
        return const Color(0xFFffde21);
      case 'Nova':
        return const Color(0xFFa45ee5);
      case 'Astra':
        return const Color(0xFFff4040);
      case 'Celestial':
        return const Color(0xFF00ffff);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    // **THIS IS THE CRITICAL FIX**
    // This guard clause is the very first thing in the build method.
    // It prevents the rest of the widget from trying to build with a null user
    // during the logout transition, showing a safe loading screen instead.
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      );
    }

    // Now that we know the user is not null, it's safe to proceed.
    // We fetch the energy data within a FutureBuilder for safety.
    final energyFuture = ref.read(energyApiProvider).getLatestEnergy(user.id);

    return SingleChildScrollView(
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
                        ? Image.network(user.avatarUrl!,
                            width: 80, height: 80, fit: BoxFit.cover)
                        : Image.asset(
                            'assets/images/profile_placeholder.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(user.username,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FutureBuilder<int>(
            future: energyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text('Could not load energy score.', style: TextStyle(color: Colors.red));
              }

              final energy = snapshot.data ?? 0;
              final rank = getRank(energy);
              final color = getRankColor(rank);
              final iconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Energy: ',
                            style: TextStyle(
                                color: Colors.white, fontSize: 18)),
                        Text('$energy ',
                            style: TextStyle(
                                color: color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        SvgPicture.asset(iconPath,
                            height: 24, width: 24),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _showGraph = !_showGraph);
                          },
                          child: Text(
                              _showGraph
                                  ? 'Hide Graph'
                                  : 'View Graph',
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  if (_showGraph) const SizedBox(height: 8),
                  if (_showGraph)
                    SizedBox(
                        height: 200,
                        child: EnergyGraph(userId: user.id)),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Text('Workout History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          WorkoutHistoryList(userId: user.id),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}