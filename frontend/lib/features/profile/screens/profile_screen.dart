import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/energy_graph.dart';
import '../../../core/providers/energy_providers.dart'; // corrected import for energyApiProvider

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<int> _energyFuture;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _energyFuture =
          ref.read(energyApiProvider).getLatestEnergy(user.id); // API call
    }
  }

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
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      case 'Diamond':
        return const Color(0xFFB9F2FF);
      case 'Jade':
        return const Color(0xFF00A86B);
      case 'Master':
        return Colors.purple;
      case 'Grandmaster':
        return Colors.deepPurple;
      case 'Nova':
        return Colors.tealAccent;
      case 'Astra':
        return Colors.lightBlueAccent;
      case 'Celestial':
        return Colors.pinkAccent;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(
                child: Text(
                  'User not found.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : Column(
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
                                  )
                                : Image.asset(
                                    'assets/images/profile_placeholder.png',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FutureBuilder<int>(
                    future: _energyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const CircularProgressIndicator();
                      }
                      final energy = snapshot.data ?? 0;
                      final rank = getRank(energy);
                      final color = getRankColor(rank);
                      final iconPath =
                          'assets/images/ranks/${rank.toLowerCase()}.svg';

                      return Row(
                        children: [
                          const Text(
                            'Energy: ',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            '$energy ',
                            style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SvgPicture.asset(
                            iconPath,
                            height: 24,
                            width: 24,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  EnergyGraph(userId: user.id),
                ],
              ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 4,
        onTap: (index) {},
      ),
    );
  }
}
