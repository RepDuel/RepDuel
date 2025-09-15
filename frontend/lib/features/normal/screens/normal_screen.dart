// frontend/lib/features/normal/screens/normal_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/search_bar.dart'; // ExerciseSearchField
import '../../ranked/utils/rank_utils.dart'; // formatKg, getRankColor, getInterpolatedEnergy
import '../../ranked/utils/lift_progress.dart';
import '../../ranked/screens/ranked_screen.dart' show liftStandardsProvider;
import '../../ranked/screens/result_screen.dart' show standardsPackProvider;

class NormalScreen extends ConsumerStatefulWidget {
  const NormalScreen({super.key});

  @override
  ConsumerState<NormalScreen> createState() => _NormalScreenState();
}

class _NormalScreenState extends ConsumerState<NormalScreen> {
  List<dynamic> _allScenarios = [];
  List<dynamic> _filteredScenarios = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  Timer? _debounce;

  // Per-scenario cache of raw score_value (1RM calc) from backend (always kg)
  final Map<String, double> _highScoreByScenario = {};
  // In-flight request guards
  final Set<String> _pending = {};

  // Per-scenario metadata caches and guards
  final Map<String, double> _scenarioMultiplier = {};
  final Map<String, bool> _scenarioIsBodyweight = {};
  final Set<String> _pendingScenarioDetails = {};

  // Rank thresholds now come from liftStandardsProvider (reactive)

  static const _headerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchScenarios() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(publicHttpClientProvider);
      final response = await client.get('/scenarios/');
      // Response is a JSON array
      final data = (response.data is List)
          ? (response.data as List)
          : json.decode(json.encode(response.data)) as List;

      data.sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));

      setState(() {
        _allScenarios = data;
        _applyFilter(); // apply current query (if any)
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load scenarios';
        _isLoading = false;
      });
    }
  }

  double _round5(num x) => ((x / 5).round() * 5).toDouble();
  double _round1(num x) => x.roundToDouble();

  Future<void> _ensureScenarioDetails(String scenarioId) async {
    if (_pendingScenarioDetails.contains(scenarioId)) return;
    if (_scenarioMultiplier.containsKey(scenarioId) &&
        _scenarioIsBodyweight.containsKey(scenarioId)) {
      return;
    }

    _pendingScenarioDetails.add(scenarioId);
    try {
      final client = ref.read(publicHttpClientProvider);
      final res = await client.get('/scenarios/$scenarioId/details');
      double mult = 0.0;
      bool isBw = false;
      if (res.statusCode == 200) {
        final body = res.data as Map<String, dynamic>;
        final m = body['multiplier'];
        if (m is num) mult = m.toDouble();
        final bw = body['is_bodyweight'];
        if (bw is bool) isBw = bw;
      }
      if (!mounted) return;
      setState(() {
        _scenarioMultiplier[scenarioId] = mult;
        _scenarioIsBodyweight[scenarioId] = isBw;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scenarioMultiplier[scenarioId] = 0.0;
        _scenarioIsBodyweight[scenarioId] = false;
      });
    } finally {
      _pendingScenarioDetails.remove(scenarioId);
    }
  }

  // Removed: standards are provided by liftStandardsProvider

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _applyFilter();
      });
    });
  }

  void _applyFilter() {
    if (_query.trim().isEmpty) {
      _filteredScenarios = List.of(_allScenarios);
      return;
    }
    final q = _query.toLowerCase();
    _filteredScenarios = _allScenarios.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Future<void> _goToScenario(String id, String name) async {
    final shouldRefresh = await context.pushNamed<bool>(
      'scenario',
      pathParameters: {'scenarioId': id},
      extra: name,
    );

    if (shouldRefresh == true) {
      // Drop the cached score first so UI won't show stale value
      setState(() {
        _highScoreByScenario.remove(id);
      });

      // Refetch the updated highscore from the SAME endpoint Ranked uses
      final userId =
          ref.read(authProvider).valueOrNull?.user?.id.toString() ?? '';
      if (userId.isNotEmpty) {
        await _ensureHighScore(scenarioId: id, userId: userId, force: true);
      }

      if (mounted) setState(() {});
    }
  }

  void _goToLeaderboard(String scenarioId, String liftName) {
    context.pushNamed(
      'liftLeaderboard',
      pathParameters: {'scenarioId': scenarioId},
      queryParameters: {'liftName': liftName},
    );
  }

  // _ensureMultiplier removed; replaced by _ensureScenarioDetails

  Future<void> _ensureHighScore({
    required String scenarioId,
    required String userId,
    bool force = false,
  }) async {
    if (!force && _highScoreByScenario.containsKey(scenarioId)) return;
    if (_pending.contains(scenarioId)) return;

    _pending.add(scenarioId);
    try {
      // Use private (authorized) Dio client and SAME endpoint as Ranked
      final client = ref.read(privateHttpClientProvider);
      final res = await client
          .get('/scores/user/$userId/scenario/$scenarioId/highscore');

      double value = 0.0;
      if (res.statusCode == 200) {
        final body = res.data as Map<String, dynamic>;
        final val = (body['score_value'] ?? 0) as num;
        value = val.toDouble(); // raw kg (1RM calc)
      } else if (res.statusCode == 404) {
        value = 0.0;
      } else {
        value = 0.0;
      }

      if (!mounted) return;
      setState(() {
        _highScoreByScenario[scenarioId] = value;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _highScoreByScenario[scenarioId] = 0.0;
      });
    } finally {
      _pending.remove(scenarioId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Listen for meaningful auth/user changes and clear the local cache.
    ref.listen(authProvider, (prev, next) {
      final prevUser = prev?.valueOrNull?.user;
      final nextUser = next.valueOrNull?.user;
      final changed = (prevUser?.id != nextUser?.id) ||
          (prevUser?.energy != nextUser?.energy) ||
          (prevUser?.rank != nextUser?.rank);

      if (changed) {
        _highScoreByScenario.clear();
        if (mounted) setState(() {});
      }
    });

    final user = ref.watch(authProvider).valueOrNull?.user;
    final userId = user?.id.toString() ?? '';
    final weightMultiplier = (user?.weightMultiplier ?? 1.0).toDouble();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchScenarios,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Watch standards reactively so gender/unit/weight changes update rows
    final liftStandards = ref
        .watch(liftStandardsProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    // KG-only pack for bodyweight scenarios
    final kgStandards = ref
        .watch(standardsPackProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);

    return Column(
      children: [
        // Search
        ExerciseSearchField(
          onChanged: _onSearchChanged,
          hintText: 'Search exercises',
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),

        // Header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(child: Text('Lift', style: _headerStyle)),
              Expanded(
                  child: Center(child: Text('Score', style: _headerStyle))),
              Expanded(
                flex: 2,
                child: Center(child: Text('Progress', style: _headerStyle)),
              ),
              Expanded(
                flex: 2,
                child: Center(child: Text('Rank', style: _headerStyle)),
              ),
              Expanded(
                child: Center(child: Text('Energy', style: _headerStyle)),
              ),
              SizedBox(width: 40), // leaderboard icon
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _highScoreByScenario.clear();
              await _fetchScenarios();
              // Optionally warm up highscores for visible items after refresh
              if (userId.isNotEmpty) {
                final futures = _filteredScenarios.map((s) {
                  final id = s['id']?.toString();
                  if (id == null) return Future.value();
                  return _ensureHighScore(scenarioId: id, userId: userId);
                }).toList();
                await Future.wait(futures);
              }
            },
            child: _filteredScenarios.isEmpty
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
                    itemCount: _filteredScenarios.length,
                    itemBuilder: (context, index) {
                      final scenario = _filteredScenarios[index];
                      final name =
                          (scenario['name'] ?? 'Unnamed Scenario').toString();
                      final id = scenario['id']?.toString();
                      if (id == null) {
                        return const SizedBox.shrink();
                      }

                      // Kick off fetch for this row if we have a logged-in user
                      if (userId.isNotEmpty) {
                        _ensureHighScore(scenarioId: id, userId: userId)
                            .then((_) {
                          if (mounted) setState(() {});
                        });
                      }

                      final rawScore = _highScoreByScenario[id] ?? 0.0;

                      // Rank/progress/energy for any scenario using its multiplier
                      // Ensure details (multiplier + is_bodyweight) are fetched
                      if (!_scenarioMultiplier.containsKey(id) ||
                          !_scenarioIsBodyweight.containsKey(id)) {
                        _ensureScenarioDetails(id).then((_) {
                          if (mounted) setState(() {});
                        });
                      }

                      String matchedRank = 'Unranked';
                      double nextThreshold = 0.0;
                      double progress = 0.0;
                      double energy = 0.0;

                      final mult = _scenarioMultiplier[id] ?? 0.0;
                      final isBw = _scenarioIsBodyweight[id] ?? false;

                      // For bodyweight exercises, do not scale score by unit
                      final displayScore = isBw
                          ? rawScore
                          : rawScore * weightMultiplier;
                      final scoreText =
                          rawScore > 0 ? formatKg(displayScore) : '—';

                      // Choose base pack: KG for bodyweight; user-unit pack otherwise
                      final basePack = isBw ? kgStandards : liftStandards;
                      if (basePack != null && mult > 0) {
                        // Build per-scenario standards by scaling total thresholds by the multiplier.
                        // Round to nearest 5 ONLY for non-bodyweight scenarios.
                        final Map<String, dynamic> scenarioStandards = {
                          for (final e in basePack.entries)
                            e.key: {
                              'lifts': {
                                'scenario': isBw
                                    ? _round1(((e.value['total'] ?? 0) as num)
                                            .toDouble() *
                                        mult)
                                    : _round5(((e.value['total'] ?? 0) as num)
                                            .toDouble() *
                                        mult),
                              }
                            }
                        };

                        final lp = computeLiftProgress(
                          liftStandards: scenarioStandards,
                          liftKey: 'scenario',
                          score: displayScore,
                        );
                        matchedRank = lp.matchedRank;
                        nextThreshold = lp.nextThreshold;
                        progress = lp.progress;
                        energy = getInterpolatedEnergy(
                          score: displayScore,
                          thresholds: scenarioStandards,
                          liftKey: 'scenario',
                          userMultiplier: 1.0,
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _goToScenario(id, name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // Lift
                                Expanded(
                                  child: Tooltip(
                                    message: name,
                                    waitDuration: Duration(milliseconds: 400),
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),

                                // Score
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      scoreText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),

                                // Progress (mirrors RankingTable)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 6,
                                        child: LinearProgressIndicator(
                                          value: (((_scenarioIsBodyweight[id] ?? false)
                                                          ? kgStandards
                                                          : liftStandards) !=
                                                      null &&
                                                      ((_scenarioMultiplier[id] ??
                                                              0) >
                                                          0))
                                              ? progress
                                              : 0.0,
                                          backgroundColor: Colors.grey[800],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            getRankColor(matchedRank),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (((_scenarioIsBodyweight[id] ?? false)
                                                    ? kgStandards
                                                    : liftStandards) !=
                                                null &&
                                                ((_scenarioMultiplier[id] ??
                                                        0) >
                                                    0))
                                            ? '${formatKg(displayScore)} / ${formatKg(nextThreshold)}'
                                            : '—',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Rank icon
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: (((_scenarioIsBodyweight[id] ?? false)
                                                ? kgStandards
                                                : liftStandards) !=
                                            null &&
                                            ((_scenarioMultiplier[id] ?? 0) >
                                                0))
                                        ? SvgPicture.asset(
                                            'assets/images/ranks/${matchedRank.toLowerCase()}.svg',
                                            height: 24,
                                            width: 24,
                                          )
                                        : const SizedBox(height: 24, width: 24),
                                  ),
                                ),

                                // Energy
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      (((_scenarioIsBodyweight[id] ?? false)
                                                  ? kgStandards
                                                  : liftStandards) !=
                                              null &&
                                              ((_scenarioMultiplier[id] ?? 0) >
                                                  0))
                                          ? NumberFormat("###0").format(energy)
                                          : '—',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),

                                // Leaderboard
                                IconButton(
                                  icon: const Icon(Icons.leaderboard,
                                      color: Colors.blue),
                                  onPressed: () => _goToLeaderboard(id, name),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
