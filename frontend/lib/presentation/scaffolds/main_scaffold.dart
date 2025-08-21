// frontend/lib/presentation/scaffolds/main_scaffold.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/normal/screens/normal_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/ranked/screens/ranked_screen.dart';
import '../../features/routines/screens/routines_screen.dart';
import '../../widgets/main_bottom_nav_bar.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({
    super.key,
    required this.initialIndex,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;

  final List<Widget> _pages = [
    const NormalScreen(),
    const RankedScreen(),
    const RoutinesScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'Normal',
    'Ranked',
    'Routines',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentIndex == 3)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}