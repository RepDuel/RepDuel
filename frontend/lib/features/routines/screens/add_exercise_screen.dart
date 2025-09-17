// frontend/lib/features/routines/screens/add_exercise_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/search_bar.dart';

import '../../../core/providers/api_providers.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';

final allScenariosProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/scenarios/');
  final data = response.data as List;
  data.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
  return data;
});

class AddExerciseScreen extends ConsumerStatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  ConsumerState<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends ConsumerState<AddExerciseScreen> {
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _selectScenario(BuildContext context, Map<String, dynamic> scenario) {
    context.pop({
      'scenario_id': scenario['id'],
      'name': scenario['name'] ?? 'Unnamed Exercise',
      'sets': 1,
      'reps': 5,
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenariosAsync = ref.watch(allScenariosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercise'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: scenariosAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(
          child: ErrorDisplay(
            message: err.toString(),
            onRetry: () => ref.refresh(allScenariosProvider),
          ),
        ),
        data: (scenarios) {
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? scenarios
              : scenarios.where((s) {
                  final name = (s['name'] ?? '').toString().toLowerCase();
                  return name.contains(q);
                }).toList();

          return Column(
            children: [
              ExerciseSearchField(
                onChanged: _onSearchChanged,
                hintText: 'Search exercises',
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allScenariosProvider);
                    await ref.read(allScenariosProvider.future);
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'No results',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final scenario = filtered[index];
                            final name =
                                (scenario['name'] ?? 'Unnamed Scenario')
                                    .toString();
                            return ListTile(
                              title: Text(name,
                                  style: const TextStyle(color: Colors.white)),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.greenAccent,
                              ),
                              onTap: () => _selectScenario(context, scenario),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
