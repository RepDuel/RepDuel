// frontend/lib/features/leaderboard/screens/energy_leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EnergyLeaderboardScreen extends StatefulWidget {
  const EnergyLeaderboardScreen({super.key});

  @override
  State<EnergyLeaderboardScreen> createState() =>
      _EnergyLeaderboardScreenState();
}

class _EnergyLeaderboardScreenState extends State<EnergyLeaderboardScreen> {
  List<dynamic> entries = [];
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

    const url = 'http://localhost:8000/api/v1/energy/leaderboard';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          entries = data;
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
        title: const Text('Energy Leaderboard'),
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
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final username = entry['username'] ?? 'Anonymous';
                    final energy =
                        entry['total_energy']?.toStringAsFixed(1) ?? '0.0';

                    return ListTile(
                      leading: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Text(
                        '$energy ⚡',
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    );
                  },
                ),
    );
  }
}
