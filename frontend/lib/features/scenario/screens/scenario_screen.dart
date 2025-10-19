// frontend/lib/features/scenario/screens/scenario_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../widgets/error_display.dart';
import '../../../core/providers/personal_best_events_provider.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../core/models/user.dart';
import '../../ranked/screens/ranked_screen.dart' show liftStandardsProvider;
import '../../ranked/utils/bodyweight_benchmarks.dart';
import '../../ranked/utils/rank_utils.dart';

final scenarioDetailsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, scenarioId) async {
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/scenarios/$scenarioId/details');
  return (response.data as Map).cast<String, dynamic>();
});

class ScenarioScreen extends ConsumerStatefulWidget {
  final String liftName;
  final String scenarioId;
  const ScenarioScreen(
      {super.key, required this.liftName, required this.scenarioId});
  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  double _calculateOneRepMax(double weightInKg, int reps) {
    if (reps <= 0) return 0.0;
    if (reps == 1) return weightInKg;
    return weightInKg * (1 + reps / 30.0);
  }

  void _dismissKeyboard() {
    final focusScope = FocusScope.of(context);
    if (!focusScope.hasPrimaryFocus && focusScope.focusedChild != null) {
      focusScope.unfocus();
    }
  }

  Future<void> _handleSubmit(bool isBodyweight) async {
    _dismissKeyboard();
    final authState = ref.read(authProvider).valueOrNull;
    if (authState?.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication required.")));
      return;
    }
    final user = authState!.user!;

    final reps = int.tryParse(_repsController.text);
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter valid reps.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      double scoreForRankCalc;
      double weightInKg;

      if (isBodyweight) {
        scoreForRankCalc = reps.toDouble();
        weightInKg = 0.0;
      } else {
        final weightInput = double.tryParse(_weightController.text);
        if (weightInput == null || weightInput <= 0) {
          throw Exception("Please enter a valid weight.");
        }
        weightInKg = weightInput / user.weightMultiplier;
        scoreForRankCalc = _calculateOneRepMax(weightInKg, reps);
      }

      final client = ref.read(privateHttpClientProvider);

      final response = await client.post(
          '/scores/scenario/${widget.scenarioId}/',
          data: {
        'user_id': user.id,
        'weight_lifted': weightInKg,
        'reps': reps,
        'sets': 1,
      });

      double previousBest = 0.0;
      bool isPersonalBest = false;
      final responseData = response.data;
      if (responseData is Map) {
        final Map<String, dynamic> map = responseData.cast<String, dynamic>();
        previousBest =
            (map['previous_best_score_value'] as num?)?.toDouble() ?? 0.0;
        isPersonalBest = map['is_personal_best'] == true;
      }

      ref.read(scoreEventsProvider.notifier).state++;

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      // If this was a personal best, refresh the persisted feed events so the
      // profile activity list reflects it immediately when returning.
      if (isPersonalBest) {
        ref.invalidate(personalBestEventsProvider(user.id));
      }

      final shouldRefresh = (await context.pushNamed<bool>(
            'results',
            extra: {
              'scenarioId': widget.scenarioId,
              'finalScore': scoreForRankCalc,
              'previousBest': previousBest,
            },
          )) ??
          true;

      if (shouldRefresh && mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", ""))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final user = authAsync.valueOrNull?.user;
    final scenarioDetailsAsync =
        ref.watch(scenarioDetailsProvider(widget.scenarioId));
    final liftStandards = ref
        .watch(liftStandardsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final scenarioDetails = scenarioDetailsAsync.value;
    final scenarioName =
        (scenarioDetails?['name'] as String?) ?? _capitalize(widget.liftName);
    final isBodyweightScenario =
        scenarioDetails?['is_bodyweight'] as bool? ?? false;
    final thresholds = _buildScenarioThresholds(
      details: scenarioDetails,
      user: user,
      liftStandards: liftStandards,
    );
    final unitLabel = (user?.weightMultiplier ?? 1.0) > 1.5 ? 'lbs' : 'kg';
    final bodyContent = scenarioDetailsAsync.when(
      loading: () => const Center(child: LoadingSpinner()),
      error: (err, stack) => Center(
          child: ErrorDisplay(
              message: err.toString(),
              onRetry: () =>
                  ref.refresh(scenarioDetailsProvider(widget.scenarioId)))),
      data: (details) {
        final isBodyweight = details['is_bodyweight'] as bool? ?? false;
        final description = details['description'] as String?;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (description != null)
                  Text(description,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center),
                const SizedBox(height: 32),
                isBodyweight
                    ? _buildRepsOnlyInput()
                    : _buildWeightAndRepsInput(unitLabel),
              ],
            ),
          ),
        );
      },
    );

    final bottomBar = Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => _handleSubmit(
                  scenarioDetailsAsync.value?['is_bodyweight'] ?? false),
          icon: _isSubmitting
              ? const LoadingSpinner(size: 20)
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Submitting...' : 'Confirm'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
      ),
    );

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_capitalize(widget.liftName)),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'View thresholds',
              onPressed: thresholds == null || thresholds.isEmpty
                  ? null
                  : () => _showThresholdsSheet(
                        scenarioName: scenarioName,
                        thresholds: thresholds,
                        isBodyweight: isBodyweightScenario,
                      ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isSubmitting
              ? const Center(
                  key: ValueKey('scenario-submitting'),
                  child: LoadingSpinner(),
                )
              : KeyedSubtree(
                  key: const ValueKey('scenario-content'),
                  child: bodyContent,
                ),
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isSubmitting
              ? const SizedBox.shrink(key: ValueKey('scenario-bottom-hidden'))
              : KeyedSubtree(
                  key: const ValueKey('scenario-bottom-button'),
                  child: bottomBar,
                ),
        ),
      ),
    );
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
                  Text(
                    'Rank thresholds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Widget _buildRepsOnlyInput() {
    return Column(
      children: [
        const Text('Reps', style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onEditingComplete: _dismissKeyboard,
            onSubmitted: (_) => _dismissKeyboard(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none)),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightAndRepsInput(String unitLabel) {
    return SizedBox(
      width: 300,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: _buildInputFieldWithLabel(
                  controller: _weightController, label: 'Weight ($unitLabel)')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12)
                .copyWith(bottom: 8.0),
            child: const Text('x',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          Expanded(
              child: _buildInputFieldWithLabel(
                  controller: _repsController, label: 'Reps')),
        ],
      ),
    );
  }

  Widget _buildInputFieldWithLabel({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onEditingComplete: _dismissKeyboard,
          onSubmitted: (_) => _dismissKeyboard(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
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
