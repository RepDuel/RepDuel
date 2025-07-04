import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      currentIndex: currentIndex,
      onTap: (index) {
        onTap(index); // Call the parent function (passed in)

        // Handle navigation with GoRouter
        if (index == 0) {
          context.go('/ranked'); // Navigate to Ranked Screen
        } else if (index == 1) {
          context.go('/routines'); // Navigate to Routines Screen
        } else if (index == 2) {
          context.go('/profile'); // Navigate to Profile Screen
        }
      },
      items: const [
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
