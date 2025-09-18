// frontend/lib/features/ranked/widgets/benchmarks_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../utils/rank_utils.dart';
import '../../../core/providers/auth_provider.dart';

class BenchmarksTable extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsyncValue = ref.watch(authProvider);

    return authStateAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Text('Auth Error: $error',
              style: const TextStyle(color: Colors.red))),
      data: (authState) {
        final sortedRanks = standards.keys.toList()
          ..sort((a, b) => (standards[a]['total'] as num)
              .compareTo(standards[b]['total'] as num));

        return Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    final router = GoRouter.of(context);
                    if (router.canPop()) {
                      router.pop();
                    } else {
                      onViewRankings();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _BenchmarksTableHeader(showLifts: showLifts),
            const SizedBox(height: 8),
            ...sortedRanks.map((rank) => _BenchmarkRow(
                  rank: rank,
                  lifts: showLifts ? standards[rank]['lifts'] : null,
                  metadata: standards[rank]['metadata'],
                )),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onViewRankings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
          const Expanded(
            flex: 2,
            child: _HeaderText('Bench', center: true),
          ),
          const Expanded(
            flex: 2,
            child: _HeaderText('Squat', center: true),
          ),
          const Expanded(
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

  const _BenchmarkRow({
    required this.rank,
    this.lifts,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final color = metadata?['color'] != null
        ? Color(int.parse(metadata!['color'].substring(1, 7), radix: 16))
        : getRankColor(rank);

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
              child: _LiftValue(lifts!['bench']),
            ),
            Expanded(
              flex: 2,
              child: _LiftValue(lifts!['squat']),
            ),
            Expanded(
              flex: 2,
              child: _LiftValue(lifts!['deadlift']),
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

  const _LiftValue(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value != null ? _fmt(value) : '-',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
    );
  }

  String _fmt(dynamic v) {
    final n = (v as num).toDouble();
    // Values from backend are already rounded to nearest 5 in the chosen unit.
    // Display without decimals.
    return n.toStringAsFixed(0);
  }
}
