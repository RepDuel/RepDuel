// frontend/lib/features/ranked/screens/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeaderboardScreen extends StatefulWidget {
  final String scenarioId;
  final String liftName;

  const LeaderboardScreen({
    super.key,
    required this.scenarioId,
    required this.liftName,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
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

    final url =
        'http://localhost:8000/api/v1/scores/scenario/${widget.scenarioId}/leaderboard';

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
              : ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (_, index) {
                    final score = scores[index];
                    final user = score['user'];
                    final username = user?['username'] ?? 'Anonymous';
                    final weight = score['weight_lifted'] ?? 0;

                    return ListTile(
                      title: Text(
                        username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '$weight kg',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
    );
  }
}
