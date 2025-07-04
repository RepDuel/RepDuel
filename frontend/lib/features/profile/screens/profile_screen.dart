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
      body: const Center(
        child: Text(
          'Welcome to the profile screen.',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 2, // Profile tab index
        onTap: (index) {
          // TODO: Implement navigation
        },
      ),
    );
  }
}
