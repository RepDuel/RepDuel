// frontend/lib/features/normal/screens/normal_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/search_bar.dart'; // ExerciseSearchField
import '../../ranked/utils/rank_utils.dart'; // formatKg

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

  // Per-scenario cache of raw score_value (1RM calc) from backend
  final Map<String, double> _highScoreByScenario = {};
  // In-flight request guards
  final Set<String> _pending = {};

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
      final response =
          await http.get(Uri.parse('${Env.baseUrl}/api/v1/scenarios/'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        data.sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));

        setState(() {
          _allScenarios = data;
          _applyFilter(); // apply current query (if any)
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load scenarios';
        _isLoading = false;
      });
    }
  }

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

  void _goToScenario(String id, String name) {
    context.pushNamed(
      'scenario',
      pathParameters: {'scenarioId': id},
      extra: name,
    );
  }

  void _goToLeaderboard(String scenarioId, String liftName) {
    context.pushNamed(
      'liftLeaderboard',
      pathParameters: {'scenarioId': scenarioId},
      queryParameters: {'liftName': liftName},
    );
  }

  Future<void> _ensureHighScore({
    required String scenarioId,
    required String userId,
  }) async {
    if (_highScoreByScenario.containsKey(scenarioId)) return;
    if (_pending.contains(scenarioId)) return;

    _pending.add(scenarioId);
    try {
      final uri = Uri.parse(
        '${Env.baseUrl}/api/v1/ranks/user/$userId/scenario/$scenarioId/highscore_value',
      );
      final res = await http.get(uri);

      double value = 0;
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final val = (body['high_score'] ?? 0) as num;
        value = val.toDouble();
      } else if (res.statusCode == 404) {
        value = 0; // No score yet
      } else {
        value = 0; // Treat other failures as no score
      }

      if (!mounted) return;
      setState(() {
        _highScoreByScenario[scenarioId] = value;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _highScoreByScenario[scenarioId] = 0;
      });
    } finally {
      _pending.remove(scenarioId);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Column(
      children: [
        // Search
        ExerciseSearchField(
          onChanged: _onSearchChanged,
          hintText: 'Search exercises',
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),

        // Header (add simple Score column)
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
                child: Center(child: Text('Score', style: _headerStyle)),
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

                      final rawScore = _highScoreByScenario[id] ?? 0;
                      final adjustedScore = rawScore * weightMultiplier;
                      final scoreText =
                          rawScore > 0 ? formatKg(adjustedScore) : '—';

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            // Lift
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _goToScenario(id, name);
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Score (RankingTable style formatting)
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

                            // Leaderboard
                            IconButton(
                              icon: const Icon(Icons.leaderboard,
                                  color: Colors.blue),
                              onPressed: () => _goToLeaderboard(id, name),
                            ),
                          ],
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
