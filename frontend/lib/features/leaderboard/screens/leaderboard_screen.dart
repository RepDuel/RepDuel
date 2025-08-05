import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/providers/auth_provider.dart';
import 'package:frontend/core/config/env.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  final String liftName;

  const LeaderboardScreen({
    super.key,
    required this.scenarioId,
    required this.liftName,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<dynamic> scores = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    // ignore: prefer_const_declarations
    final url =
        '${Env.baseUrl}/api/v1/scores/scenario/${widget.scenarioId}/leaderboard';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          scores = data.where((entry) => entry['user'] != null).toList();
        } else {
          error = 'Invalid response format';
        }
      } else {
        error = 'Error: ${res.statusCode}';
      }
    } catch (e) {
      error = 'Failed to load leaderboard';
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isKg = user?.weightMultiplier == 1.0;
    final multiplier = user?.weightMultiplier ?? 1.0;
    final unit = isKg ? 'kg' : 'lbs';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${widget.liftName} Leaderboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)),
                )
              : Column(
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              'Rank',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'User',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Score',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: scores.length,
                        itemBuilder: (_, index) {
                          final score = scores[index];
                          final user = score['user'];
                          final username = user?['username'] ?? 'Anonymous';
                          final rawScore = (score['weight_lifted'] ?? 0) as num;
                          final adjusted = rawScore * multiplier;
                          final display = adjusted % 1 == 0
                              ? adjusted.toInt().toString()
                              : adjusted.toStringAsFixed(1);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$display $unit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
