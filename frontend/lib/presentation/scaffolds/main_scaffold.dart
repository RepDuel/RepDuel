// frontend/lib/presentation/scaffolds/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/main_bottom_nav_bar.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    const List<String> titles = [
      'Normal',
      'Ranked',
      'Routines',
      'Profile',
    ];

    final int currentIndex = navigationShell.currentIndex;

    // Grab current location from GoRouter
    final String location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (currentIndex == 3 && !location.contains('/profile/settings'))
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.go('/profile/settings'),
            ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: MainBottomNavBar(
        navigationShell: navigationShell,
      ),
    );
  }
}
