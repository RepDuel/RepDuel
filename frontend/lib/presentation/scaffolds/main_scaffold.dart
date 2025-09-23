// frontend/lib/presentation/scaffolds/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/navigation_provider.dart';
import '../../widgets/main_bottom_nav_bar.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const List<String> titles = [
      'Normal',
      'Ranked',
      'Routines',
      'Profile',
    ];

    final int currentIndex = navigationShell.currentIndex;
    final Uri uri = GoRouterState.of(context).uri;
    final String location = uri.toString();
    final String path = uri.path;

    final bool hideTitleBar = path.startsWith('/routines/play') ||
        path.startsWith('/routines/exercise-list') ||
        path.startsWith('/routines/free-workout') ||
        path.startsWith('/routines/custom');

    final showBottomNav = ref.watch(bottomNavVisibilityProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: hideTitleBar
          ? null
          : AppBar(
              title: Text(titles[currentIndex]),
              centerTitle: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (currentIndex == 3 &&
                    !location.contains('/profile/settings'))
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => context.go('/profile/settings'),
                  ),
              ],
            ),
      body: navigationShell,
      bottomNavigationBar: showBottomNav
          ? MainBottomNavBar(navigationShell: navigationShell)
          : null,
    );
  }
}
