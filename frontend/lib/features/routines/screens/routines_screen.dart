import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/routine_card.dart';
import 'routine_play_screen.dart';
import '../../../core/models/routine.dart'; // Make sure this file exists

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  Future<List<Routine>> fetchRoutines() async {
    final response =
        await http.get(Uri.parse('http://localhost:8000/api/v1/routines/'));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Routine.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load routines');
    }
  }

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
      body: FutureBuilder<List<Routine>>(
        future: fetchRoutines(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final routines = snapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: routines.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                final routine = routines[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutinePlayScreen(routine: routine),
                      ),
                    );
                  },
                  child: RoutineCard(
                    name: routine.name,
                    imageUrl: routine.imageUrl ??
                        'https://via.placeholder.com/150', // Fallback image
                    duration: '${routine.scenarios.length * 1} min',
                    difficultyLevel: routine.scenarios.length,
                  ),
                );
              },
            );
          }
        },
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 2,
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
