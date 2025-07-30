// frontend/lib/features/routines/screens/custom_routine_screen.dart

import 'package:flutter/material.dart';
import '../screens/add_exercise_screen.dart';

class CustomRoutineScreen extends StatefulWidget {
  const CustomRoutineScreen({super.key});

  @override
  State<CustomRoutineScreen> createState() => _CustomRoutineScreenState();
}

class _CustomRoutineScreenState extends State<CustomRoutineScreen> {
  // Local list of selected exercises (minimal shape for now)
  final List<_CustomExercise> _items = [];

  Future<void> _addExercise() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );
    if (result != null) {
      setState(() {
        _items.add(
          _CustomExercise(
            scenarioId: result['scenario_id'] as String,
            name: (result['name'] as String?) ?? 'Unnamed Exercise',
            sets: (result['sets'] as int?) ?? 1,
          ),
        );
      });
    }
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _saveRoutine() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise first.')),
      );
      return;
    }

    // TODO: Collect routine metadata (e.g., name, duration, difficulty) if desired.
    // TODO: POST to backend (e.g., /api/v1/users/me/routines) and send _items as steps.

    // For now, simulate success and pop to previous screen.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routine saved (local demo).')),
    );

    // If the caller awaits the result, it can refresh on `true`.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Custom Routine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _items.isEmpty
            ? const Center(
                child: Text(
                  'No exercises yet.\nTap "Add Exercise" to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              )
            : Column(
                children: [
                  // Table headers (match routine_play_screen style)
                  const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Name',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Sets',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                      SizedBox(width: 40), // space for delete icon
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rows
                  Expanded(
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final e = _items[index];
                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                e.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${e.sets}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Remove',
                              onPressed: () => _removeAt(index),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),

      // Bottom CTAs: Add Exercise | Save Routine
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _addExercise,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Add Exercise'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _items.isEmpty ? null : _saveRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Save Routine'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomExercise {
  final String scenarioId;
  final String name;
  final int sets;

  _CustomExercise({
    required this.scenarioId,
    required this.name,
    required this.sets,
  });
}
