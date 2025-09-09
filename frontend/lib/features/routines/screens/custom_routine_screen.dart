// frontend/lib/features/routines/screens/custom_routine_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/routine.dart';
import '../../../core/providers/api_providers.dart';
import 'add_exercise_screen.dart';

enum RoutineEditorMode { create, edit }

class CustomRoutineScreen extends ConsumerStatefulWidget {
  const CustomRoutineScreen({super.key})
      : mode = RoutineEditorMode.create,
        initial = null;

  const CustomRoutineScreen.edit({super.key, required this.initial})
      : mode = RoutineEditorMode.edit;

  final RoutineEditorMode mode;
  final Routine? initial;

  @override
  ConsumerState<CustomRoutineScreen> createState() =>
      _CustomRoutineScreenState();
}

class _CustomRoutineScreenState extends ConsumerState<CustomRoutineScreen> {
  final List<_CustomExercise> _items = [];
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _imgCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.mode == RoutineEditorMode.edit && widget.initial != null) {
      final r = widget.initial!;
      _nameCtrl = TextEditingController(text: r.name);
      _imgCtrl = TextEditingController(text: r.imageUrl ?? '');
      _items.addAll(
        r.scenarios.map((s) => _CustomExercise(
              scenarioId: s.scenarioId,
              // --- THIS IS THE FIX ---
              // The `ScenarioSet` object 's' does not have a `scenarioName` property.
              // Reverting to the original logic that uses `scenarioId` as a placeholder.
              name: s.scenarioId,
              // --- END OF FIX ---
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
    if (!mounted || result == null) return;

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

  void _removeAt(int index) => setState(() => _items.removeAt(index));
  void _incSets(int index) => setState(() =>
      _items[index] = _items[index].copyWith(sets: _items[index].sets + 1));
  void _decSets(int index) {
    if (_items[index].sets <= 1) return;
    setState(() =>
        _items[index] = _items[index].copyWith(sets: _items[index].sets - 1));
  }

  void _incReps(int index) => setState(() =>
      _items[index] = _items[index].copyWith(reps: _items[index].reps + 1));
  void _decReps(int index) {
    if (_items[index].reps <= 1) return;
    setState(() =>
        _items[index] = _items[index].copyWith(reps: _items[index].reps - 1));
  }

  Future<void> _saveRoutine() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one exercise first.')));
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a routine name.')));
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
                "reps": e.reps
              })
          .toList(),
    };

    try {
      final client = ref.read(privateHttpClientProvider);

      if (widget.mode == RoutineEditorMode.edit && widget.initial != null) {
        await client.dio.put('/routines/${widget.initial!.id}', data: payload);
      } else {
        await client.dio.post('/routines/', data: payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.mode == RoutineEditorMode.edit
                ? 'Routine updated.'
                : 'Routine saved.')),
      );
      context.pop(true); // Pop with 'true' to signal success
    } on DioException catch (e) {
      if (!mounted) return;
      final errorMsg = e.response?.data?['detail'] ??
          'Failed to save routine. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}')));
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
        title: Text(isEdit ? 'Edit Routine' : 'Create Routine'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Routine name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _imgCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Image URL (optional)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54))),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                          'No exercises yet.\nTap "Add Exercise" to start.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)))
                  : Column(
                      children: [
                        const Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('Name', style: headerStyle)),
                            Expanded(
                                flex: 2,
                                child: Center(
                                    child: Text('Sets', style: headerStyle))),
                            Expanded(
                                flex: 2,
                                child: Center(
                                    child: Text('Reps', style: headerStyle))),
                            SizedBox(width: 48),
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
                                  Expanded(
                                      flex: 3,
                                      child: Text(e.name,
                                          style: cellStyle,
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis)),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _decSets(index),
                                              icon: const Icon(Icons.remove,
                                                  color: Colors.white70)),
                                          Text('${e.sets}', style: cellStyle),
                                          IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _incSets(index),
                                              icon: const Icon(Icons.add,
                                                  color: Colors.white70)),
                                        ]),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _decReps(index),
                                              icon: const Icon(Icons.remove,
                                                  color: Colors.white70)),
                                          Text('${e.reps}', style: cellStyle),
                                          IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: _saving
                                                  ? null
                                                  : () => _incReps(index),
                                              icon: const Icon(Icons.add,
                                                  color: Colors.white70)),
                                        ]),
                                  ),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                      onPressed: _saving
                                          ? null
                                          : () => _removeAt(index)),
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
                      textStyle: const TextStyle(fontSize: 16)),
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
                      textStyle: const TextStyle(fontSize: 16)),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
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

  _CustomExercise(
      {required this.scenarioId,
      required this.name,
      required this.sets,
      required this.reps});

  _CustomExercise copyWith({int? sets, int? reps}) => _CustomExercise(
        scenarioId: scenarioId,
        name: name,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
      );
}
