// frontend/lib/features/ranked/widgets/benchmarks_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/rank_utils.dart'; // <-- IMPORTED UTILITY FILE
import '../../../core/providers/auth_provider.dart'; // Import the auth provider

class BenchmarksTable extends ConsumerWidget { // Changed to ConsumerWidget
  final Map<String, dynamic> standards;
  final Function() onViewRankings;
  final bool showLifts;

  const BenchmarksTable({
    super.key,
    required this.standards,
    required this.onViewRankings,
    this.showLifts = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef ref
    // Safely watch the authProvider to get AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states for auth.
    return authStateAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()), // Show loading while auth state is loading
      error: (error, stackTrace) => Center(child: Text('Auth Error: $error', style: const TextStyle(color: Colors.red))), // Show error if auth fails
      data: (authState) { // authState is the actual AuthState object here
        // Safely access user and its properties from the loaded AuthState.
        final user = authState.user;
        final weightMultiplier = user?.weightMultiplier ?? 1.0; // Default to 1.0 if user or multiplier is null

        // Rank data processing remains the same, using the fetched standards.
        final sortedRanks = standards.keys.toList()
          ..sort((a, b) => (standards[a]['total'] as num)
              .compareTo(standards[b]['total'] as num));

        // Build the UI with the fetched user data and standards.
        return Column(
          children: [
            const SizedBox(height: 16),
            _BenchmarksTableHeader(showLifts: showLifts),
            const SizedBox(height: 8),
            // Map through sorted ranks to build rows.
            ...sortedRanks.map((rank) => _BenchmarkRow(
                  rank: rank,
                  lifts: showLifts ? standards[rank]['lifts'] : null,
                  metadata: standards[rank]['metadata'],
                  weightMultiplier: weightMultiplier, // Pass the correctly determined multiplier
                )),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onViewRankings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('View My Rankings'),
            ),
          ],
        );
      },
    );
  }
}

class _BenchmarksTableHeader extends StatelessWidget {
  final bool showLifts;
  const _BenchmarksTableHeader({this.showLifts = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 5,
          child: _HeaderText('Rank'),
        ),
        if (showLifts) ...[
          Expanded(
            flex: 2,
            child: _HeaderText('Bench', center: true),
          ),
          Expanded(
            flex: 2,
            child: _HeaderText('Squat', center: true),
          ),
          Expanded(
            flex: 2,
            child: _HeaderText('Deadlift', center: true),
          ),
        ],
      ],
    );
  }
}

class _BenchmarkRow extends StatelessWidget {
  final String rank;
  final Map<String, dynamic>? lifts;
  final Map<String, dynamic>? metadata;
  final double weightMultiplier; // This is correctly received

  const _BenchmarkRow({
    required this.rank,
    this.lifts,
    this.metadata,
    required this.weightMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    // Get rank color using the global helper function.
    final color = metadata?['color'] != null
        ? Color(int.parse(metadata!['color'].substring(1, 7), radix: 16))
        : getRankColor(rank); // Use the global function

    final iconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
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
          if (lifts != null) ...[
            Expanded(
              flex: 2,
              child: _LiftValue(lifts!['bench'], weightMultiplier),
            ),
            Expanded(
              flex: 2,
              child: _LiftValue(lifts!['squat'], weightMultiplier),
            ),
            Expanded(
              flex: 2,
              child: _LiftValue(lifts!['deadlift'], weightMultiplier),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  final bool center;
  const _HeaderText(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _LiftValue extends StatelessWidget {
  final dynamic value;
  final double weightMultiplier;

  const _LiftValue(this.value, this.weightMultiplier);

  @override
  Widget build(BuildContext context) {
    return Text(
      value != null ? _roundToNearest5(value * weightMultiplier) : '-', // Apply multiplier here
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
    );
  }

  String _roundToNearest5(double value) {
    final roundedValue = (value / 5).round() * 5;
    return roundedValue.toString();
  }
}