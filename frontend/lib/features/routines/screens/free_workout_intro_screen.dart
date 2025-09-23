// frontend/lib/features/routines/screens/free_workout_intro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/navigation_provider.dart';

class FreeWorkoutIntroScreen extends ConsumerStatefulWidget {
  const FreeWorkoutIntroScreen({super.key});

  @override
  ConsumerState<FreeWorkoutIntroScreen> createState() =>
      _FreeWorkoutIntroScreenState();
}

class _FreeWorkoutIntroScreenState
    extends ConsumerState<FreeWorkoutIntroScreen> {
  late final StateController<bool> _bottomNavController;

  @override
  void initState() {
    super.initState();
    _bottomNavController = ref.read(bottomNavVisibilityProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bottomNavController.state = false;
    });
  }

  @override
  void dispose() {
    _bottomNavController.state = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        if (mounted) {
          _bottomNavController.state = true;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Quick Workout'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (mounted) {
                _bottomNavController.state = true;
              }
              context.pop();
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              SizedBox(height: 32),
              Icon(Icons.fitness_center, size: 72, color: Colors.greenAccent),
              SizedBox(height: 24),
              Text(
                'Start an empty routine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Log sets freely without using a saved routine. Add exercises as you go.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              context.pushNamed('freeWorkoutSession');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16),
            ),
            child: const Text('Start'),
          ),
        ),
      ),
    );
  }
}
