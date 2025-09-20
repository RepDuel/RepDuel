// frontend/lib/features/routines/screens/summary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // ← needed for context.go

import '../../../core/providers/auth_provider.dart';
import '../models/summary_personal_best.dart';

class SummaryScreen extends ConsumerWidget {
  final double totalVolumeKg;
  final List<SummaryPersonalBest> personalBests;

  const SummaryScreen({
    super.key,
    required this.totalVolumeKg,
    this.personalBests = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    final isLbs = (user?.weightMultiplier ?? 1.0) > 1.5;
    final displayVolume = isLbs ? totalVolumeKg * 2.20462 : totalVolumeKg;

    return PopScope(
      canPop: false, // block back navigation from returning to ExerciseList
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // user tried to go back → send them to the Routines tab instead
          GoRouter.of(context).go('/routines');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Routine Summary'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Routine Complete!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Total Volume Lifted:',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${displayVolume.round()} ${isLbs ? 'lbs' : 'kg'}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _PersonalBestsSection(
                          personalBests: personalBests,
                          isLbs: isLbs,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Done → take them to the Routines tab (not back to exercise list)
                    context.go('/routines');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 32,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonalBestsSection extends StatelessWidget {
  final List<SummaryPersonalBest> personalBests;
  final bool isLbs;

  const _PersonalBestsSection({
    required this.personalBests,
    required this.isLbs,
  });

  @override
  Widget build(BuildContext context) {
    if (personalBests.isEmpty) {
      return Column(
        children: const [
          Icon(Icons.insights, color: Colors.white24, size: 42),
          SizedBox(height: 12),
          Text(
            'No personal bests this time — keep pushing!',
            style: TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.emoji_events, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text(
              'New Personal Bests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...personalBests.map(
          (best) => _PersonalBestTile(best: best, isLbs: isLbs),
        ),
      ],
    );
  }
}

class _PersonalBestTile extends StatelessWidget {
  final SummaryPersonalBest best;
  final bool isLbs;

  const _PersonalBestTile({required this.best, required this.isLbs});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;
    const minWidth = 300.0;
    const maxWidth = 600.0;

    final displayUnit = isLbs ? 'lbs' : 'kg';
    final weightDisplay = _formatNumber(
      isLbs ? best.weightKg * 2.20462 : best.weightKg,
    );

    final subtitle = best.isBodyweight
        ? '${best.reps} reps logged'
        : '$weightDisplay $displayUnit × ${best.reps} reps';
    final scoreLabel = best.isBodyweight
        ? 'Best set: ${best.reps} reps'
        : '1RM: ${_formatNumber(
            isLbs ? best.scoreValue * 2.20462 : best.scoreValue,
            decimalForLarge: true,
          )} $displayUnit';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: isWide ? minWidth : double.infinity,
          maxWidth: isWide ? maxWidth : double.infinity,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                best.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                scoreLabel,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value, {bool decimalForLarge = true}) {
    final absValue = value.abs();
    final decimals = (absValue >= 100 && decimalForLarge) ? 0 : 1;
    final str = value.toStringAsFixed(decimals);
    if (decimals == 0) {
      return str;
    }
    return str.endsWith('.0') ? str.substring(0, str.length - 2) : str;
  }
}
