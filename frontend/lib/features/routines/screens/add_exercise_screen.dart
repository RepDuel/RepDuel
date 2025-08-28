// frontend/lib/features/routines/screens/add_exercise_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_providers.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';

// Provider to fetch the list of all available scenarios (exercises)
final allScenariosProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/scenarios/');
  final data = response.data as List;
  // Sort alphabetically by name
  data.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
  return data;
});

class AddExerciseScreen extends ConsumerWidget {
  const AddExerciseScreen({super.key});

  void _selectScenario(BuildContext context, Map<String, dynamic> scenario) {
    // Pop the screen and return the selected exercise data
    context.pop({
      'scenario_id': scenario['id'],
      'name': scenario['name'] ?? 'Unnamed Exercise',
      'sets': 1, // Default to 1 set for an added exercise
      'reps': 5, // Default to 5 reps
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(allScenariosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercise'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: scenariosAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(child: ErrorDisplay(message: err.toString(), onRetry: () => ref.refresh(allScenariosProvider))),
        data: (scenarios) {
          return ListView.builder(
            itemCount: scenarios.length,
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              final name = scenario['name'] ?? 'Unnamed Scenario';
              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                onTap: () => _selectScenario(context, scenario),
              );
            },
          );
        },
      ),
    );
  }
}