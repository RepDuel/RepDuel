// frontend/lib/features/ranked/widgets/benchmarks_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import '../utils/rank_utils.dart';
import '../../../core/providers/auth_provider.dart';
import 'ranking_table.dart' show LiftSpec;

class BenchmarksTable extends ConsumerWidget {
  final Map<String, dynamic> standards;
  final Function() onViewRankings;
  final bool showLifts;
  final List<LiftSpec> lifts;
  final Widget? header;

  const BenchmarksTable({
    super.key,
    required this.standards,
    required this.onViewRankings,
    required this.lifts,
    this.showLifts = true,
    this.header,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsyncValue = ref.watch(authProvider);

    return authStateAsyncValue.when(
      loading: () => const Center(child: LoadingSpinner()),
      error: (error, stackTrace) => Center(
          child: Text('Auth Error: $error',
              style: const TextStyle(color: Colors.red))),
      data: (authState) {
        final sortedRanks = standards.keys.toList()
          ..sort((a, b) => (standards[a]['total'] as num)
              .compareTo(standards[b]['total'] as num));

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
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
              ),
            ),
            if (header != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(child: header),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: const SizedBox(height: 16),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _BenchmarksTableHeaderDelegate(
                  showLifts: showLifts,
                  lifts: lifts,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: const SizedBox(height: 8),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final rank = sortedRanks[index];
                    return _BenchmarkRow(
                      rank: rank,
                      lifts: showLifts ? standards[rank]['lifts'] : null,
                      metadata: standards[rank]['metadata'],
                      liftSpecs: lifts,
                    );
                  },
                  childCount: sortedRanks.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: const SizedBox(height: 20),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ElevatedButton(
                    onPressed: onViewRankings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    child: const Text('View My Rankings'),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: const SizedBox(height: 16),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BenchmarksTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool showLifts;
  final List<LiftSpec> lifts;

  _BenchmarksTableHeaderDelegate({
    required this.showLifts,
    required this.lifts,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.centerLeft,
      child: _BenchmarksTableHeader(
        showLifts: showLifts,
        lifts: lifts,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BenchmarksTableHeaderDelegate oldDelegate) {
    return oldDelegate.showLifts != showLifts || oldDelegate.lifts != lifts;
  }
}

class _BenchmarksTableHeader extends StatelessWidget {
  final bool showLifts;
  final List<LiftSpec> lifts;
  const _BenchmarksTableHeader({
    this.showLifts = true,
    required this.lifts,
  });

  String _titleize(String key) {
    final withSpaces = key.replaceAll('_', ' ');
    return withSpaces
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            part[0].toUpperCase() + (part.length > 1 ? part.substring(1) : ''))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          flex: 5,
          child: Padding(
            padding: EdgeInsets.only(left: 36), // adjust as needed
            child: _HeaderText('Rank'),
          ),
        ),
        if (showLifts) ...[
          for (final spec in lifts)
            Expanded(
              flex: 2,
              child: _HeaderText(
                spec.shortLabel ?? spec.name ?? _titleize(spec.key),
                center: true,
              ),
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
  final List<LiftSpec> liftSpecs;

  const _BenchmarkRow({
    required this.rank,
    this.lifts,
    this.metadata,
    required this.liftSpecs,
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
            for (final spec in liftSpecs)
              Expanded(
                flex: 2,
                child: _LiftValue(lifts![spec.key]),
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
