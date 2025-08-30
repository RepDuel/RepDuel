// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/routine_details.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../providers/set_data_provider.dart';

final routineDetailsProvider = FutureProvider.autoDispose
    .family<RoutineDetails, String>((ref, routineId) async {
  final client = ref.watch(privateHttpClientProvider);
  final response = await client.get('/routines/$routineId');
  return RoutineDetails.fromJson(response.data);
});

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String routineId;
  const ExerciseListScreen({super.key, required this.routineId});
  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  double _totalVolumeKg = 0;
  late DateTime _startTime;
  bool _isFinishing = false;
  final List<Map<String, dynamic>> _localAddedExercises = [];

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  void _updateVolume(List<Map<String, dynamic>> setData) {
    double newVolume = 0;
    for (final set in setData) {
      newVolume += (set['weight'] as num? ?? 0) * (set['reps'] as num? ?? 0);
    }
    setState(() => _totalVolumeKg += newVolume);
  }

  double _calc1RM(double weightKg, int reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  void _navigateToAddExercise() async {
    final newExercise =
        await context.push<Map<String, dynamic>>('/add-exercise');
    if (newExercise != null) {
      setState(() => _localAddedExercises.add(newExercise));
    }
  }

  Future<void> _finishRoutine() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Authentication error.")));
      }
      setState(() => _isFinishing = false);
      return;
    }

    try {
      final client = ref.read(privateHttpClientProvider);
      final allPerformedSets = ref.read(routineSetProvider);

      // --- THIS IS THE FIX ---
      // Create the flat list of scenarios (sets) that the backend expects.
      final scenariosPayload = allPerformedSets.map((set) {
        return {
          "scenario_id": set.scenarioId,
          "sets": 1, // Each object represents one set.
          "reps": set.reps,
          "weight": set.weight,
          "total_volume": set.reps *
              set.weight, // Calculate total volume for this single set.
        };
      }).toList();

      // Create the main submission body with the correct field name 'scenario_submissions'.
      final submissionBody = {
        'routine_id': widget.routineId,
        'user_id': user.id,
        'duration': DateTime.now().difference(_startTime).inSeconds / 60.0,
        'completion_timestamp': DateTime.now().toIso8601String(),
        'status': 'completed',
        'scenario_submissions': scenariosPayload, // Use the correct alias
      };

      await client.post('/routine_submission/', data: submissionBody);
      // --- END OF FIX ---

      // The logic for submitting best scores is separate and likely correct.
      final Map<String, List<PerformedSet>> groupedSetsForBestScores = {};
      for (final s in allPerformedSets) {
        groupedSetsForBestScores.putIfAbsent(s.scenarioId, () => []).add(s);
      }
      for (final entry in groupedSetsForBestScores.entries) {
        PerformedSet? bestSet;
        double best1RM = -1;
        for (final set in entry.value) {
          final oneRm = _calc1RM(set.weight, set.reps);
          if (oneRm > best1RM) {
            best1RM = oneRm;
            bestSet = set;
          }
        }
        if (bestSet != null) {
          await client.post('/scores/scenario/${entry.key}/', data: {
            'user_id': user.id,
            'weight_lifted': bestSet.weight,
            'reps': bestSet.reps,
            'sets': 1
          });
        }
      }

      final isLbs = (user.weightMultiplier) > 1.5;
      final displayVolume = isLbs ? _totalVolumeKg * 2.20462 : _totalVolumeKg;

      ref.read(routineSetProvider.notifier).clear();
      if (mounted) {
        context.pushReplacement('/summary', extra: displayVolume.round());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to finish routine: $e")));
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routineDetailsAsync =
        ref.watch(routineDetailsProvider(widget.routineId));
    final isLbs =
        (ref.watch(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0) >
            1.5;
    final displayVolume = isLbs ? _totalVolumeKg * 2.20462 : _totalVolumeKg;

    return Scaffold(
      appBar: AppBar(
        title: routineDetailsAsync.when(
          data: (details) => Text(details.name),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: routineDetailsAsync.when(
        loading: () => const Center(child: LoadingSpinner()),
        error: (err, stack) => Center(
            child: ErrorDisplay(
                message: err.toString(),
                onRetry: () =>
                    ref.refresh(routineDetailsProvider(widget.routineId)))),
        data: (details) {
          final allExercises = [
            ...details.scenarios,
            ..._localAddedExercises.map((e) => Scenario.fromJson(e))
          ];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                      'Total Volume: ${displayVolume.round()} ${isLbs ? 'lbs' : 'kg'}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    itemCount: allExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = allExercises[index];
                      final completedSetsCount = ref.watch(
                          routineSetProvider.select((sets) => sets
                              .where((s) => s.scenarioId == exercise.id)
                              .length));
                      final isCompleted = completedSetsCount >= exercise.sets;
                      return Card(
                        color: isCompleted
                            ? Colors.green.withAlpha(51)
                            : Colors.white12,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(exercise.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18)),
                          subtitle: Text(
                              'Sets: ${exercise.sets} | Reps: ${exercise.reps}',
                              style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.play_arrow,
                              color: Colors.greenAccent, size: 28),
                          onTap: () async {
                            final setData =
                                await context.push<List<Map<String, dynamic>>>(
                              '/exercise-play',
                              extra: exercise,
                            );
                            if (setData != null) {
                              _updateVolume(setData);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _navigateToAddExercise,
                        child: const Text('Add Exercise'))),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _isFinishing ? null : _finishRoutine,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: _isFinishing
                            ? const LoadingSpinner(size: 20)
                            : const Text('Finish Routine'))),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: TextButton(
                        onPressed: () {
                          ref.read(routineSetProvider.notifier).clear();
                          context.pop();
                        },
                        child: const Text('Quit Routine',
                            style: TextStyle(color: Colors.red)))),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }
}
