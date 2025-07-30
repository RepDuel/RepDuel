// frontend/lib/features/routines/screens/custom_routine_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/add_exercise_screen.dart';
import '../../../core/services/secure_storage_service.dart'; // adjust if your path differs

class CustomRoutineScreen extends StatefulWidget {
  const CustomRoutineScreen({super.key});

  @override
  State<CustomRoutineScreen> createState() => _CustomRoutineScreenState();
}

class _CustomRoutineScreenState extends State<CustomRoutineScreen> {
  // Local list of selected exercises
  final List<_CustomExercise> _items = [];
  bool _saving = false;

  Future<void> _addExercise() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _items.add(
          _CustomExercise(
            scenarioId: result['scenario_id'] as String,
            name: (result['name'] as String?) ?? 'Unnamed Exercise',
            sets: (result['sets'] as int?) ?? 1,
            reps: (result['reps'] as int?) ?? 5,
          ),
        );
      });
    }
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
  }

  void _incSets(int index) {
    setState(() =>
        _items[index] = _items[index].copyWith(sets: _items[index].sets + 1));
  }

  void _decSets(int index) {
    if (_items[index].sets <= 0) return;
    setState(() =>
        _items[index] = _items[index].copyWith(sets: _items[index].sets - 1));
  }

  void _incReps(int index) {
    setState(() =>
        _items[index] = _items[index].copyWith(reps: _items[index].reps + 1));
  }

  void _decReps(int index) {
    if (_items[index].reps <= 0) return;
    setState(() =>
        _items[index] = _items[index].copyWith(reps: _items[index].reps - 1));
  }

  Future<String?> _promptForName() async {
    final ctrl = TextEditingController(text: 'Custom Routine');
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Name your routine',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g., Push Day',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final name = ctrl.text.trim();
                Navigator.pop(ctx, name.isEmpty ? null : name);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRoutine() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise first.')),
      );
      return;
    }

    final name = await _promptForName();
    if (!mounted || name == null) return;

    setState(() => _saving = true);

    final payload = {
      "name": name,
      "scenarios": _items
          .map((e) => {
                "scenario_id": e.scenarioId,
                "name": e.name,
                "sets": e.sets,
                "reps": e.reps,
              })
          .toList(),
    };

    final storage = SecureStorageService();
    final token = await storage.readToken();

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8000/api/v1/routines/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Routine saved.')),
        );
        Navigator.of(context).pop(true); // let caller refresh
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save routines.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save (HTTP ${res.statusCode}).')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save routine: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: make this const (satisfies prefer_const_declarations)
    const headerStyle = TextStyle(color: Colors.white70, fontSize: 16);
    const cellStyle = TextStyle(color: Colors.white, fontSize: 16);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Custom Routine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : () => Navigator.pop(context),
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
                  // Table headers
                  Row(
                    children: [
                      Expanded(
                          flex: 2, child: Text('Name', style: headerStyle)),
                      // FIX: remove const because headerStyle is a variable (even if const)
                      Expanded(child: Text('Sets', style: headerStyle)),
                      Expanded(child: Text('Reps', style: headerStyle)),
                      const SizedBox(width: 40),
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
                            // Name
                            Expanded(
                              flex: 2,
                              child: Text(e.name, style: cellStyle),
                            ),
                            // Sets controls
                            Expanded(
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed:
                                        _saving ? null : () => _decSets(index),
                                    icon: const Icon(Icons.remove,
                                        color: Colors.white70),
                                    tooltip: 'Decrease sets',
                                  ),
                                  Text('${e.sets}', style: cellStyle),
                                  IconButton(
                                    onPressed:
                                        _saving ? null : () => _incSets(index),
                                    icon: const Icon(Icons.add,
                                        color: Colors.white70),
                                    tooltip: 'Increase sets',
                                  ),
                                ],
                              ),
                            ),
                            // Reps controls
                            Expanded(
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed:
                                        _saving ? null : () => _decReps(index),
                                    icon: const Icon(Icons.remove,
                                        color: Colors.white70),
                                    tooltip: 'Decrease reps',
                                  ),
                                  Text('${e.reps}', style: cellStyle),
                                  IconButton(
                                    onPressed:
                                        _saving ? null : () => _incReps(index),
                                    icon: const Icon(Icons.add,
                                        color: Colors.white70),
                                    tooltip: 'Increase reps',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: 'Remove',
                              onPressed:
                                  _saving ? null : () => _removeAt(index),
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
                  onPressed: _saving ? null : _addExercise,
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
                  onPressed: _items.isEmpty || _saving ? null : _saveRoutine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Routine'),
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
  final int reps;

  _CustomExercise({
    required this.scenarioId,
    required this.name,
    required this.sets,
    required this.reps,
  });

  _CustomExercise copyWith({int? sets, int? reps}) => _CustomExercise(
        scenarioId: scenarioId,
        name: name,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
      );
}
