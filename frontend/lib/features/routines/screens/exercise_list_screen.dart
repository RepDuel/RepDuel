// frontend/lib/features/routines/screens/exercise_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/routine_details.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_spinner.dart';
import '../providers/set_data_provider.dart';
import '../models/summary_personal_best.dart';
import '../models/summary_screen_args.dart';

final routineDetailsProvider = FutureProvider.autoDispose
    .family<RoutineDetails, String>((ref, routineId) async {
  final client = ref.watch(privateHttpClientProvider);
  final response = await client.get('/routines/$routineId');
  return RoutineDetails.fromJson(response.data);
});

class ExerciseListScreen extends ConsumerStatefulWidget {
  final String? routineId;
  const ExerciseListScreen({super.key, this.routineId});
  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  double _totalVolumeKg = 0;
  late DateTime _startTime;
  bool _isFinishing = false;
  Timer? _sessionTicker;
  Duration _sessionElapsed = Duration.zero;
  late final StateController<bool> _bottomNavController;

  /// Locally added exercises via /add-exercise (maps convertible to Scenario)
  final List<Map<String, dynamic>> _localAddedExercises = [];

  /// Per-exercise overrides for planned sets/reps (keyed by scenarioId)
  final Map<String, Map<String, int>> _planOverrides =
      {}; // { id: {sets: x, reps: y} }

  @override
  void initState() {
    super.initState();
    _bottomNavController = ref.read(bottomNavVisibilityProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bottomNavController.state = false;
    });
    _startTime = DateTime.now();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _stopSessionTimer();
    _bottomNavController.state = true;
    super.dispose();
  }

  void _updateVolume() {
    final allPerformedSets = ref.read(routineSetProvider);
    final updatedVolume = allPerformedSets.fold<double>(
      0,
      (sum, set) => sum + (set.weight * set.reps),
    );
    setState(() => _totalVolumeKg = updatedVolume);
  }

  double _calc1RM(double weightKg, int reps) {
    if (reps <= 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  Future<void> _navigateToAddExercise() async {
    final newExercise =
        await context.push<Map<String, dynamic>>('/add-exercise');
    if (!mounted) return;
    if (newExercise != null) {
      setState(() => _localAddedExercises.add(newExercise));
      _planOverrides[newExercise['scenario_id'] as String] = {
        'sets': newExercise['sets'] as int? ?? 1,
        'reps': newExercise['reps'] as int? ?? 5,
      };
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
      final totalVolume = allPerformedSets.fold<double>(
        0,
        (sum, set) => sum + (set.weight * set.reps),
      );
      if (totalVolume <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Log at least one set with volume before finishing.'),
            ),
          );
          setState(() => _isFinishing = false);
        } else {
          _isFinishing = false;
        }
        return;
      }
      final elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
      final durationMinutes = elapsedSeconds / 60.0;

      RoutineDetails? routineDetails;
      if (widget.routineId != null) {
        try {
          routineDetails =
              await ref.read(routineDetailsProvider(widget.routineId!).future);
        } catch (_) {
          routineDetails = null;
        }
      } else {
        routineDetails = null;
      }

      final Map<String, String> scenarioNames = {};
      if (routineDetails != null) {
        for (final scenario in routineDetails.scenarios) {
          scenarioNames[scenario.id] = scenario.name;
        }
      }
      for (final local in _localAddedExercises) {
        final scenarioId = local['scenario_id'] as String?;
        final name = local['name'] as String?;
        if (scenarioId != null && name != null) {
          scenarioNames[scenarioId] = name;
        }
      }

      final scenariosPayload = allPerformedSets.map((set) {
        return {
          "scenario_id": set.scenarioId,
          "sets": 1,
          "reps": set.reps,
          "weight": set.weight,
          "total_volume": set.reps * set.weight,
        };
      }).toList();

      final Map<String, dynamic> submissionBody = {
        'user_id': user.id,
        'duration': durationMinutes,
        'completion_timestamp': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
        'scenario_submissions': scenariosPayload,
      };

      if (widget.routineId != null) {
        submissionBody['routine_id'] = widget.routineId;
      }

      await client.post('/routine_submission/', data: submissionBody);

      // Post best score per scenario from this routine
      final Map<String, List<PerformedSet>> groupedSetsForBestScores = {};
      for (final s in allPerformedSets) {
        groupedSetsForBestScores.putIfAbsent(s.scenarioId, () => []).add(s);
      }
      final List<SummaryPersonalBest> personalBests = [];
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
          double finalScoreForRank = best1RM;
          bool isBodyweight = false;
          bool isPersonalBest = false;
          String rankName = 'Unranked';

          try {
            final response = await client.post(
              '/scores/scenario/${entry.key}/',
              data: {
                'user_id': user.id,
                'weight_lifted': bestSet.weight,
                'reps': bestSet.reps,
                'sets': 1
              },
            );

            final responseData = response.data;
            Map<String, dynamic> responseMap = {};
            if (responseData is Map) {
              responseMap = responseData.cast<String, dynamic>();
            }

            final scoreJson = responseMap['score'];
            Map<String, dynamic> scoreMap = {};
            if (scoreJson is Map) {
              scoreMap = scoreJson.cast<String, dynamic>();
            }

            isPersonalBest = responseMap['is_personal_best'] == true;
            isBodyweight = scoreMap['is_bodyweight'] == true;
            finalScoreForRank =
                (scoreMap['score_value'] as num?)?.toDouble() ?? best1RM;
          } catch (_) {
            finalScoreForRank = bestSet.reps > 0
                ? _calc1RM(bestSet.weight, bestSet.reps)
                : best1RM;
          }

          final userWeight = user.weight ?? 0;
          if (userWeight > 0) {
            final gender = (user.gender ?? 'male').toLowerCase();
            try {
              final rankResponse = await client.get(
                '/ranks/get_rank_progress',
                queryParameters: {
                  'scenario_id': entry.key,
                  'final_score': finalScoreForRank,
                  'user_weight': userWeight,
                  'user_gender': gender,
                },
              );
              final data = rankResponse.data;
              if (data is Map) {
                final currentRank = data['current_rank'];
                if (currentRank is String && currentRank.trim().isNotEmpty) {
                  rankName = currentRank;
                }
              }
            } catch (_) {
              rankName = 'Unranked';
            }
          }

          final scenarioName = scenarioNames[entry.key] ?? 'Session Highlight';
          personalBests.add(SummaryPersonalBest(
            scenarioId: entry.key,
            exerciseName: scenarioName,
            weightKg: bestSet.weight,
            reps: bestSet.reps,
            scoreValue: finalScoreForRank,
            isBodyweight: isBodyweight,
            isPersonalBest: isPersonalBest,
            rankName: rankName,
          ));
        }
      }

      // Notify rest of the app that scores changed
      ref.read(scoreEventsProvider.notifier).state++;

      // Clear local set cache
      ref.read(routineSetProvider.notifier).clear();

      if (!mounted) return;

      _stopSessionTimer();
      _bottomNavController.state = true;
      context.go(
        '/summary',
        extra: SummaryScreenArgs(
          totalVolumeKg: totalVolume,
          personalBests: personalBests,
          durationMinutes: durationMinutes,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to finish routine: $e")));
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  Scenario _applyOverrides(Scenario scenario) {
    final override = _planOverrides[scenario.id];
    if (override == null) return scenario;

    return Scenario(
      id: scenario.id,
      name: scenario.name,
      sets: override['sets'] ?? scenario.sets,
      reps: override['reps'] ?? scenario.reps,
    );
  }

  Future<void> _openEditSheet({
    required Scenario scenario,
    required bool isLocalAdded,
  }) async {
    final current = _applyOverrides(scenario);
    int tempSets = current.sets;
    int tempReps = current.reps;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Edit ${scenario.name}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumberPickerTile(
                      label: 'Sets',
                      value: tempSets,
                      onChanged: (v) => setState(() => tempSets = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberPickerTile(
                      label: 'Reps',
                      value: tempReps,
                      onChanged: (v) => setState(() => tempReps = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _planOverrides[scenario.id] = {
                            'sets': tempSets.clamp(1, 99),
                            'reps': tempReps.clamp(1, 999),
                          };
                          if (isLocalAdded) {
                            final idx = _localAddedExercises.indexWhere(
                                (m) => m['scenario_id'] == scenario.id);
                            if (idx != -1) {
                              _localAddedExercises[idx] = {
                                ..._localAddedExercises[idx],
                                'sets': tempSets,
                                'reps': tempReps,
                              };
                            }
                          }
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _maybeRemoveLocalExercise(String scenarioId) {
    final idx =
        _localAddedExercises.indexWhere((e) => e['scenario_id'] == scenarioId);
    if (idx == -1) return;

    setState(() {
      _localAddedExercises.removeAt(idx);
      _planOverrides.remove(scenarioId);

      final setsNotifier = ref.read(routineSetProvider.notifier);
      final currentSets = ref.read(routineSetProvider);

      final remaining =
          currentSets.where((s) => s.scenarioId != scenarioId).toList();

      setsNotifier.clear();

      final Map<String, List<Map<String, dynamic>>> byScenario = {};
      for (final s in remaining) {
        byScenario.putIfAbsent(s.scenarioId, () => []).add({
          'weight': s.weight,
          'reps': s.reps,
        });
      }
      byScenario.forEach((id, sets) {
        setsNotifier.addSets(id, sets);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RoutineDetails?> routineDetailsAsync;
    if (widget.routineId == null) {
      routineDetailsAsync = const AsyncValue<RoutineDetails?>.data(null);
    } else {
      routineDetailsAsync = ref
          .watch(routineDetailsProvider(widget.routineId!))
          .whenData((details) => details);
    }
    final routineDetails = routineDetailsAsync.valueOrNull;
    final appBarTitle = routineDetailsAsync.when(
      data: (details) => details?.name ?? 'Quick Workout',
      loading: () => 'Loading...',
      error: (_, __) => widget.routineId == null ? 'Quick Workout' : 'Routine',
    );
    final isBottomNavVisible = ref.watch(bottomNavVisibilityProvider);
    final isLbs =
        (ref.watch(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0) >
            1.5;
    final displayVolume = isLbs ? _totalVolumeKg * 2.20462 : _totalVolumeKg;
    final sessionTimerText = _formatDuration(_sessionElapsed);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            isBottomNavVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          tooltip: isBottomNavVisible ? 'Hide Menu' : 'Show Menu',
          onPressed: () {
            _bottomNavController.state = !isBottomNavVisible;
          },
        ),
        title: Text(appBarTitle),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: _isFinishing ? null : _finishRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.green.shade900,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isFinishing
                  ? const LoadingSpinner(size: 18)
                  : const Text('Finish'),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: () {
        if (routineDetailsAsync.isLoading) {
          return const Center(child: LoadingSpinner());
        }
        if (routineDetailsAsync.hasError) {
          final message = routineDetailsAsync.error?.toString() ??
              'Failed to load routine.';
          return Center(
            child: ErrorDisplay(
              message: message,
              onRetry: widget.routineId == null
                  ? null
                  : () => ref.refresh(
                        routineDetailsProvider(widget.routineId!),
                      ),
            ),
          );
        }

        final apiExercises = routineDetails?.scenarios ?? <Scenario>[];
        final localExercises =
            _localAddedExercises.map((e) => Scenario.fromJson(e)).toList();
        final allExercises =
            [...apiExercises, ...localExercises].map(_applyOverrides).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Volume: ${displayVolume.round()} ${isLbs ? 'lbs' : 'kg'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session Time: $sessionTimerText',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: allExercises.isEmpty
                    ? _EmptyExercisesPlaceholder(
                        onAddExercise: _navigateToAddExercise,
                      )
                    : ListView.builder(
                        itemCount: allExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = allExercises[index];
                          final isLocal = _localAddedExercises
                              .any((m) => m['scenario_id'] == exercise.id);

                          final completedSetsCount = ref.watch(
                            routineSetProvider.select((sets) => sets
                                .where((s) => s.scenarioId == exercise.id)
                                .length),
                          );

                          final isCompleted =
                              completedSetsCount >= exercise.sets;

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
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Start',
                                    icon: const Icon(Icons.play_arrow,
                                        color: Colors.greenAccent, size: 28),
                                    onPressed: () async {
                                      final setData = await context
                                          .push<List<Map<String, dynamic>>>(
                                        '/exercise-play',
                                        extra: exercise,
                                      );
                                      if (!mounted) return;
                                      if (setData != null) {
                                        _updateVolume();
                                      }
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.white70),
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        await _openEditSheet(
                                          scenario: exercise,
                                          isLocalAdded: isLocal,
                                        );
                                      } else if (value == 'remove' && isLocal) {
                                        _maybeRemoveLocalExercise(exercise.id);
                                      }
                                    },
                                    itemBuilder: (context) =>
                                        <PopupMenuEntry<String>>[
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit sets/reps'),
                                      ),
                                      if (isLocal)
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Remove'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () async {
                                final setData = await context
                                    .push<List<Map<String, dynamic>>>(
                                  '/exercise-play',
                                  extra: exercise,
                                );
                                if (!mounted) return;
                                if (setData != null) {
                                  _updateVolume();
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
                  child: const Text('Add Exercise'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final currentContext = context;
                    final router = GoRouter.of(currentContext);

                    final confirmed = await showDialog<bool>(
                      context: currentContext,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text(
                          'Quit Routine?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Are you sure you want to quit? Your progress will not be saved.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('Quit',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (!mounted || confirmed != true) return;

                    ref.read(routineSetProvider.notifier).clear();
                    _stopSessionTimer();
                    _bottomNavController.state = true;

                    if (router.canPop()) {
                      router.pop();

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (router.canPop()) {
                          router.pop();
                        } else {
                          router.go('/routines');
                        }
                      });
                    } else {
                      router.go('/routines');
                    }
                  },
                  child: const Text('Quit Routine',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      }(),
    );
  }

  void _startSessionTimer() {
    _sessionTicker?.cancel();
    _sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _sessionElapsed = DateTime.now().difference(_startTime);
      });
    });
  }

  void _stopSessionTimer() {
    _sessionTicker?.cancel();
    _sessionTicker = null;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _EmptyExercisesPlaceholder extends StatelessWidget {
  final Future<void> Function() onAddExercise;

  const _EmptyExercisesPlaceholder({
    required this.onAddExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No exercises logged yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                onAddExercise();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add your first exercise'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberPickerTile extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumberPickerTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_NumberPickerTile> createState() => _NumberPickerTileState();
}

class _NumberPickerTileState extends State<_NumberPickerTile> {
  late int _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  void _inc() {
    setState(() {
      _val = (_val + 1).clamp(1, 999);
      widget.onChanged(_val);
    });
  }

  void _dec() {
    setState(() {
      _val = (_val - 1).clamp(1, 999);
      widget.onChanged(_val);
    });
  }

  @override
  void didUpdateWidget(covariant _NumberPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _val = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Text(widget.label,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _dec,
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.white70),
              ),
              Text('$_val',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              IconButton(
                onPressed: _inc,
                icon:
                    const Icon(Icons.add_circle_outline, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
