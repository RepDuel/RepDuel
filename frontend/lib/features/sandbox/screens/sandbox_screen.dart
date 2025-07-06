// frontend/lib/features/sandbox/screens/sandbox_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/widgets/main_bottom_nav_bar.dart';

class SandboxScreen extends StatelessWidget {
  const SandboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sandbox'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'This is the sandbox screen',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // Navigation is handled in MainBottomNavBar
        },
      ),
    );
  }
}
