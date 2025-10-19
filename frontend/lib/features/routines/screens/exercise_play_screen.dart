// frontend/lib/features/routines/screens/exercise_play_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/api_providers.dart';

import '../../../core/providers/auth_provider.dart';
import '../providers/set_data_provider.dart';
import '../../ranked/screens/ranked_screen.dart' show liftStandardsProvider;
import '../../ranked/utils/bodyweight_benchmarks.dart';
import '../../ranked/utils/rank_utils.dart';

class ExercisePlayScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int reps;

  const ExercisePlayScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
  });

  @override
  ConsumerState<ExercisePlayScreen> createState() => _ExercisePlayScreenState();
}

class _ExercisePlayScreenState extends ConsumerState<ExercisePlayScreen> {
  // Cache for scenario details to avoid repeated requests within this screen
  final Map<String, Map<String, dynamic>> _scenarioDetailsCache = {};
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _repControllers;
  Timer? _ticker;
  late DateTime _timerStart;
  Duration _elapsed = Duration.zero;
  bool? _isBodyweight;
  double _volumeMultiplier = 1.0;

  @override
  void initState() {
    super.initState();
    // Pre-fill controllers based on the routine's plan and any previously entered data
    _initializeControllers();
    _startTimer();
    _loadScenarioMetadata();
  }

  void _initializeControllers() {
    final previousSets = ref
        .read(routineSetProvider)
        .where((set) => set.scenarioId == widget.exerciseId)
        .toList();

    final isLbs = _isLbs(ref);

    _weightControllers = List.generate(widget.sets, (index) {
      String text = '';
      if (index < previousSets.length) {
        final kg = previousSets[index].weight;
        if (kg > 0) {
          final displayWeight = _toDisplayUnit(isLbs, kg);
          text = (displayWeight % 1 == 0)
              ? displayWeight.toInt().toString()
              : displayWeight.toStringAsFixed(1);
        }
      }
      return TextEditingController(text: text);
    });

    _repControllers = List.generate(widget.sets, (index) {
      String text = widget.reps.toString();
      if (index < previousSets.length) {
        final repsVal = previousSets[index].reps;
        if (repsVal > 0) text = repsVal.toString();
      }
      return TextEditingController(text: text);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (var controller in _weightControllers) {
      controller.dispose();
    }
    for (var controller in _repControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- Unit Conversion Helpers ---
  bool _isLbs(WidgetRef ref) {
    final wm =
        ref.read(authProvider).valueOrNull?.user?.weightMultiplier ?? 1.0;
    return wm > 1.5;
  }

  double _toDisplayUnit(bool isLbs, double kg) {
    return isLbs ? kg * 2.20462 : kg;
  }

  double _toKg(bool isLbs, double valueInUserUnit) {
    return isLbs ? valueInUserUnit / 2.20462 : valueInUserUnit;
  }

  void _submitAndReturnData() {
    final setDataForProvider = <Map<String, dynamic>>[];
    final setDataToReturn = <Map<String, dynamic>>[];
    final isBodyweight = _isBodyweight == true;
    final isLbs = _isLbs(ref);
    final user = ref.read(authProvider).valueOrNull?.user;
    final bodyweightKg = _bodyweightWeightKg(user);

    for (int i = 0; i < widget.sets; i++) {
      final repsText = _repControllers[i].text.trim();
      final reps = int.tryParse(repsText) ?? 0;

      if (isBodyweight) {
        if (reps > 0) {
          setDataForProvider.add({
            'scenario_id': widget.exerciseId,
            'weight': bodyweightKg,
            'reps': reps,
          });
          setDataToReturn.add({'weight': bodyweightKg, 'reps': reps});
        }
        continue;
      }

      final weightText = _weightControllers[i].text.trim();

      if (weightText.isEmpty && repsText.isEmpty) continue;

      final weightUserUnit = double.tryParse(weightText) ?? 0.0;
      final weightInKg = _toKg(isLbs, weightUserUnit);

      // Skip submitting sets whose total volume is 0
      // - For weighted lifts: require weightInKg > 0 and reps > 0
      // - For bodyweight-style entry: allow weight==0 but require reps > 0 (volume defined elsewhere)
      final isWeighted = weightInKg > 0;
      if ((isWeighted && reps > 0) || (!isWeighted && reps > 0)) {
        setDataForProvider.add({
          'scenario_id': widget.exerciseId,
          'weight': weightInKg,
          'reps': reps
        });
        setDataToReturn.add({'weight': weightInKg, 'reps': reps});
      }
    }

    ref
        .read(routineSetProvider.notifier)
        .addSets(widget.exerciseId, setDataForProvider);
    _ticker?.cancel();
    context.pop(setDataToReturn);
  }

  Future<Map<String, dynamic>?> _getScenarioDetails(String id) async {
    if (_scenarioDetailsCache.containsKey(id)) return _scenarioDetailsCache[id];
    try {
      final client = ref.read(publicHttpClientProvider);
      final res = await client.get('/scenarios/$id/details');
      final data = (res.data as Map).cast<String, dynamic>();
      _scenarioDetailsCache[id] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showScenarioInfo() async {
    final id = widget.exerciseId;
    final fallbackName = widget.exerciseName;
    final details = await _getScenarioDetails(id);
    final name = details?['name'] as String? ?? fallbackName;
    final desc =
        details?['description'] as String? ?? 'No description available.';
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Text(
                      desc,
                      style:
                          const TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    final isLbs = (user?.weightMultiplier ?? 1.0) > 1.5;
    final unitLabel = isLbs ? 'lbs' : 'kg';
    final weightLabel = isLbs ? 'Lbs' : 'Kg';
    final isBodyweight = _isBodyweight == true;
    final bodyweightKg = _bodyweightWeightKg(user);
    final bodyweightDisplay = _toDisplayUnit(isLbs, bodyweightKg);
    final hasBodyweight = isBodyweight && bodyweightKg > 0;
    final timerText = _formatDuration(_elapsed);
    final liftStandards = ref
        .watch(liftStandardsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final scenarioDetails = _scenarioDetailsCache[widget.exerciseId];
    final scenarioName =
        (scenarioDetails?['name'] as String?) ?? widget.exerciseName;
    final isBodyweightScenario =
        scenarioDetails?['is_bodyweight'] as bool? ?? isBodyweight;
    final thresholds = _buildScenarioThresholds(
      details: scenarioDetails,
      user: user,
      liftStandards: liftStandards,
    );

    return GestureDetector(
      onTap: () => _dismissKeyboard(context),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exerciseName),
            const SizedBox(height: 2),
            Text(
              timerText,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'View benchmarks',
            onPressed: thresholds == null || thresholds.isEmpty
                ? null
                : () => _showThresholdsSheet(
                      scenarioName: scenarioName,
                      thresholds: thresholds,
                      isBodyweight: isBodyweightScenario,
                    ),
          ),
          IconButton(
            tooltip: 'Exercise info',
            icon: const Icon(Icons.info_outline),
            onPressed: _showScenarioInfo,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          Widget listView = ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: widget.sets,
            itemBuilder: (context, index) {
              final repsInput = _buildInputField(
                context: context,
                controller: _repControllers[index],
                label: 'Reps',
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 40,
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    const SizedBox(width: 8),
                    if (isBodyweight)
                      Expanded(
                        flex: 5,
                        child: repsInput,
                      )
                    else ...[
                      Expanded(
                        flex: 3,
                        child: _buildWeightField(
                          context: context,
                          controller: _weightControllers[index],
                          unitLabel: weightLabel,
                        ),
                      ),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('x',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 20))),
                      Expanded(
                        flex: 2,
                        child: repsInput,
                      ),
                    ],
                  ],
                ),
              );
            },
          );

          if (!isBodyweight) return listView;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  hasBodyweight
                      ? 'Volume uses your bodyweight (${bodyweightDisplay.toStringAsFixed(bodyweightDisplay >= 100 ? 0 : 1)} $unitLabel) x ${_volumeMultiplier.toStringAsFixed(2)}.'
                      : 'Set your profile weight to calculate bodyweight volume.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Expanded(child: listView),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: ElevatedButton.icon(
          onPressed: _submitAndReturnData,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm Sets'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50)),
        ),
      ),
    ),
  );
  }

  void _dismissKeyboard(BuildContext context) {
    final focusScope = FocusScope.of(context);
    if (!focusScope.hasPrimaryFocus && focusScope.focusedChild != null) {
      focusScope.unfocus();
    }
  }

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onEditingComplete: () => _dismissKeyboard(context),
      onSubmitted: (_) => _dismissKeyboard(context),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildWeightField({
    required BuildContext context,
    required TextEditingController controller,
    required String unitLabel,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onEditingComplete: () => _dismissKeyboard(context),
      onSubmitted: (_) => _dismissKeyboard(context),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(
        labelText: unitLabel,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  void _startTimer() {
    _timerStart = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_timerStart);
      });
    });
  }

  Future<void> _loadScenarioMetadata() async {
    try {
      final details = await _getScenarioDetails(widget.exerciseId);
      if (!mounted) return;
      setState(() {
        _isBodyweight = details?['is_bodyweight'] == true;
        _volumeMultiplier =
            (details?['volume_multiplier'] as num?)?.toDouble() ??
                (details?['multiplier'] as num?)?.toDouble() ??
                _volumeMultiplier;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBodyweight = _isBodyweight ?? false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  double _bodyweightWeightKg(User? user) {
    if (_isBodyweight != true) return 0;
    final weightKg = user?.weight ?? 0;
    if (weightKg <= 0) return 0;
    return weightKg * _volumeMultiplier;
  }

  Map<String, double>? _buildScenarioThresholds({
    Map<String, dynamic>? details,
    User? user,
    Map<String, dynamic>? liftStandards,
  }) {
    if (details == null || user == null) return null;

    final isBodyweight = details['is_bodyweight'] as bool? ?? false;

    if (isBodyweight) {
      final calibrationRaw = details['calibration'];
      if (calibrationRaw is! Map<String, dynamic>) return null;
      final weightKg = (user.weight ?? 90.7).toDouble();
      if (weightKg <= 0) return null;
      try {
        final thresholds = generateBodyweightBenchmarks(
          calibrationRaw,
          weightKg,
          isFemale: user.gender?.toLowerCase() == 'female',
        );
        if (thresholds.isEmpty) return null;
        return {
          for (final entry in thresholds.entries)
            entry.key: _round1(entry.value),
        };
      } catch (_) {
        return null;
      }
    }

    final multiplier = (details['multiplier'] as num?)?.toDouble();
    if (multiplier == null || multiplier <= 0) return null;
    if (liftStandards == null || liftStandards.isEmpty) return null;

    final thresholds = <String, double>{};
    liftStandards.forEach((rank, raw) {
      if (raw is Map<String, dynamic>) {
        final total = (raw['total'] as num?)?.toDouble();
        if (total != null) {
          thresholds[rank] = _round5(total * multiplier);
        }
      }
    });

    return thresholds.isEmpty ? null : thresholds;
  }

  double _round5(double value) => (value / 5).round() * 5.0;

  double _round1(double value) => value.roundToDouble();

  Future<void> _showThresholdsSheet({
    required String scenarioName,
    required Map<String, double> thresholds,
    required bool isBodyweight,
  }) async {
    final sorted = thresholds.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rank thresholds',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ThresholdHeader(scenarioName: scenarioName),
                  const SizedBox(height: 12),
                  for (final entry in sorted)
                    _ThresholdRow(
                      rank: entry.key,
                      value: entry.value,
                      isBodyweight: isBodyweight,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThresholdHeader extends StatelessWidget {
  final String scenarioName;
  const _ThresholdHeader({required this.scenarioName});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Rank',
              style: headerStyle,
            ),
          ),
          Expanded(
            child: Text(
              scenarioName,
              textAlign: TextAlign.right,
              style: headerStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  final String rank;
  final double value;
  final bool isBodyweight;

  const _ThresholdRow({
    required this.rank,
    required this.value,
    required this.isBodyweight,
  });

  String _formatThreshold(double v) {
    if (isBodyweight) {
      if ((v - v.roundToDouble()).abs() < 1e-6) {
        return v.round().toString();
      }
      return v.toStringAsFixed(1);
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final color = getRankColor(rank);
    final iconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                SvgPicture.asset(
                  iconPath,
                  height: 20,
                  width: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  rank,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              _formatThreshold(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
