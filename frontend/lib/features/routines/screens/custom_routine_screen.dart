// frontend/lib/features/routines/screens/custom_routine_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/add_exercise_screen.dart';
import '../../../core/models/routine.dart';
import '../../../core/services/secure_storage_service.dart';

enum RoutineEditorMode { create, edit }

class CustomRoutineScreen extends StatefulWidget {
  /// Create mode
  const CustomRoutineScreen({super.key})
      : mode = RoutineEditorMode.create,
        initial = null;

  /// Edit mode convenience constructor
  const CustomRoutineScreen.edit({super.key, required this.initial})
      : mode = RoutineEditorMode.edit;

  final RoutineEditorMode mode;
  final Routine? initial;

  @override
  State<CustomRoutineScreen> createState() => _CustomRoutineScreenState();
}

class _CustomRoutineScreenState extends State<CustomRoutineScreen> {
  // Local list of selected exercises
  final List<_CustomExercise> _items = [];
  bool _saving = false;

  // Details fields
  late final TextEditingController _nameCtrl;
  late final TextEditingController _imgCtrl;

  @override
  void initState() {
    super.initState();
    // Prefill from initial when editing
    if (widget.mode == RoutineEditorMode.edit && widget.initial != null) {
      final r = widget.initial!;
      _nameCtrl = TextEditingController(text: r.name);
      _imgCtrl = TextEditingController(text: r.imageUrl ?? '');
      _items.addAll(
        r.scenarios.map((s) => _CustomExercise(
              scenarioId: s.scenarioId,
              name: s.scenarioId,
              sets: s.sets,
              reps: s.reps,
            )),
      );
    } else {
      _nameCtrl = TextEditingController(text: 'Custom Routine');
      _imgCtrl = TextEditingController(text: '');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _saveRoutine() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise first.')),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a routine name.')),
      );
      return;
    }

    setState(() => _saving = true);

    final payload = {
      "name": name,
      "image_url": _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
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
      late final http.Response res;

      if (widget.mode == RoutineEditorMode.edit && widget.initial != null) {
        // PUT /routines/{id}
        final id = widget.initial!.id;
        res = await http.put(
          Uri.parse('http://localhost:8000/api/v1/routines/$id'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );
      } else {
        // POST /routines/
        res = await http.post(
          Uri.parse('http://localhost:8000/api/v1/routines/'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mode == RoutineEditorMode.edit
                ? 'Routine updated.'
                : 'Routine saved.'),
          ),
        );
        Navigator.of(context).pop(true); // let caller refresh
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in.')),
        );
      } else if (res.statusCode == 403) {
        if (!mounted) return;
        final errorMsg = jsonDecode(res.body)['detail'] ?? 'Forbidden.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed (HTTP ${res.statusCode}).')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(color: Colors.white70, fontSize: 16);
    const cellStyle = TextStyle(color: Colors.white, fontSize: 16);
    final isEdit = widget.mode == RoutineEditorMode.edit;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Routine' : 'Custom Routine'),
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
        child: Column(
          children: [
            // Name + Image URL inputs (always visible)
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Routine name',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'e.g., Push Day',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imgCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54)),
              ),
            ),
            const SizedBox(height: 16),

            // List of exercises
            Expanded(
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
                        const Row(
                          children: [
                            Expanded(
                                flex: 2,
                                child: Text('Name', style: headerStyle)),
                            Expanded(child: Text('Sets', style: headerStyle)),
                            Expanded(child: Text('Reps', style: headerStyle)),
                            SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
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
                                          onPressed: _saving
                                              ? null
                                              : () => _decSets(index),
                                          icon: const Icon(Icons.remove,
                                              color: Colors.white70),
                                          tooltip: 'Decrease sets',
                                        ),
                                        Text('${e.sets}', style: cellStyle),
                                        IconButton(
                                          onPressed: _saving
                                              ? null
                                              : () => _incSets(index),
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
                                          onPressed: _saving
                                              ? null
                                              : () => _decReps(index),
                                          icon: const Icon(Icons.remove,
                                              color: Colors.white70),
                                          tooltip: 'Decrease reps',
                                        ),
                                        Text('${e.reps}', style: cellStyle),
                                        IconButton(
                                          onPressed: _saving
                                              ? null
                                              : () => _incReps(index),
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
          ],
        ),
      ),

      // Bottom CTAs: Add Exercise | Save
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
                      : Text(isEdit ? 'Save Changes' : 'Save Routine'),
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
