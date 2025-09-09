// frontend/lib/features/normal/screens/normal_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../widgets/search_bar.dart'; // ExerciseSearchField

class NormalScreen extends StatefulWidget {
  const NormalScreen({super.key});

  @override
  State<NormalScreen> createState() => _NormalScreenState();
}

class _NormalScreenState extends State<NormalScreen> {
  List<dynamic> _allScenarios = [];
  List<dynamic> _filteredScenarios = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  Timer? _debounce;

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
    // Debounce for snappy UX without jank
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
    // Use named route for consistency with your router
    context.pushNamed(
      'scenario',
      pathParameters: {'scenarioId': id},
      extra: name, // builder reads liftName from state.extra
    );
  }

  void _goToLeaderboard(String scenarioId, String liftName) {
    context.pushNamed(
      'liftLeaderboard',
      pathParameters: {'scenarioId': scenarioId},
      queryParameters: {'liftName': liftName},
    );
  }

  @override
  Widget build(BuildContext context) {
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
        // Elon move: fast access search, always visible
        ExerciseSearchField(
          onChanged: _onSearchChanged,
          hintText: 'Search exercises',
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),

        // Sticky header
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
              Text('Leaderboard', style: _headerStyle),
            ],
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchScenarios,
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
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (id != null) _goToScenario(id, name);
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
                            IconButton(
                              icon: const Icon(Icons.leaderboard,
                                  color: Colors.blue),
                              onPressed: () {
                                if (id != null) _goToLeaderboard(id, name);
                              },
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
