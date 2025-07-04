import 'package:flutter/material.dart';
import '../../../widgets/main_bottom_nav_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture and Name
            Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(8), // square with soft corners
                  child: Image.asset(
                    'assets/images/profile_placeholder.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Roy Wang',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Friends List Title
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Friends',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Friends List (horizontal scroll)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5, // Replace with actual friends.length
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/profile_placeholder.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Friend $index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          // TODO: Implement navigation
        },
      ),
    );
  }
}
