// frontend/lib/widgets/main_bottom_nav_bar.dart

import 'package:flutter/material.dart';

class MainBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed, // Prevents items from shifting
      currentIndex: currentIndex,
      // The GoRouter switch statement has been removed.
      // This widget now delegates the tap event directly to its parent.
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'Normal',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Ranked',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Routines',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
