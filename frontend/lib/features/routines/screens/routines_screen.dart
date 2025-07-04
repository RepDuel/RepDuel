import 'package:flutter/material.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/routine_card.dart';
import 'routine_play_screen.dart';
import 'package:go_router/go_router.dart'; // For go() navigation

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Routines'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.7,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RoutinePlayScreen(routineName: 'Chest Blast'),
                  ),
                );
              },
              child: const RoutineCard(
                name: 'Chest Blast',
                imageUrl:
                    'https://i5.walmartimages.com/seo/Webkinz-Blue-Googles-Plush_7367aa52-ea06-4a5b-b942-fe76e5ac4677.6d3adc84ac039233aee92a9f8c5b2876.jpeg?odnHeight=768&odnWidth=768&odnBg=FFFFFF',
                duration: '3 min',
                difficultyLevel: 2,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const RoutinePlayScreen(routineName: 'Leg Day'),
                  ),
                );
              },
              child: const RoutineCard(
                name: 'Leg Day',
                imageUrl:
                    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ1HnmfvOFeauYDd6yX0QF7B-ztjhP5zoljCg&s',
                duration: '4 min',
                difficultyLevel: 3,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 1, // Routines tab
        onTap: (index) {
          if (index == 0) {
            context.go('/ranked');
          } else if (index == 1) {
            // Already on this screen
          } else if (index == 2) {
            context.go('/profile');
          }
        },
      ),
    );
  }
}
