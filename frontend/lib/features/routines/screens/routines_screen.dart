// frontend/lib/features/routines/screens/routines_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/routine_card.dart';
import '../widgets/add_routine_card.dart';
import 'routine_play_screen.dart';
import 'custom_routine_screen.dart';
import '../../../core/models/routine.dart';
import '../../../core/services/secure_storage_service.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late Future<List<Routine>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchRoutines();
  }

  // Custom error type so we can render a login button on 401s.
  static const _unauthorizedMessage = 'Unauthorized (401). Please log in.';
  static const _genericFailMessage = 'Failed to load routines';

  Future<List<Routine>> _fetchRoutines() async {
    final storage = SecureStorageService();
    final token = await storage.readToken(); // Must be set after login

    final response = await http.get(
      Uri.parse('http://localhost:8000/api/v1/routines/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => Routine.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception(_unauthorizedMessage);
    } else {
      throw Exception('$_genericFailMessage (HTTP ${response.statusCode})');
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetchRoutines();
    });
    await _future;
  }

  void _onAddRoutinePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomRoutineScreen()),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create routine',
            onPressed: _onAddRoutinePressed,
          ),
        ],
      ),
      body: FutureBuilder<List<Routine>>(
        future: _future,
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (snapshot.hasError) {
            final message = snapshot.error?.toString() ?? _genericFailMessage;
            final isUnauthorized = message.contains('401');

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (isUnauthorized)
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Login'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            );
          }

          // Data
          final routines = snapshot.data ?? <Routine>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: routines.length + 1, // +1 for the Add tile
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return AddRoutineCard(onPressed: _onAddRoutinePressed);
                }
                final routine = routines[index - 1];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutinePlayScreen(routine: routine),
                      ),
                    );
                    // Optional: refresh on return
                    // ignore: use_build_context_synchronously
                    _refresh();
                  },
                  child: RoutineCard(
                    name: routine.name,
                    imageUrl: routine.imageUrl,
                    duration: '${routine.totalDurationMinutes} min',
                    difficultyLevel: 2,
                  ),
                );
              },
            ),
          );
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
