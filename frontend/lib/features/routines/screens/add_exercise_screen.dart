// frontend/lib/features/routines/screens/add_exercise_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  List<dynamic> scenarios = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchScenarios();
  }

  Future<void> _fetchScenarios() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/scenarios/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        data.sort(
            (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                  (b['name'] ?? '').toString().toLowerCase(),
                ));
        setState(() {
          scenarios = data;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load scenarios';
        isLoading = false;
      });
    }
  }

  void _selectScenario(Map<String, dynamic> scenario) {
    Navigator.pop(context, {
      'scenario_id': scenario['id'],
      'name': scenario['name'] ?? 'Unnamed Exercise',
      'sets': 1,
      'reps': 5,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercise'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : ListView.builder(
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    final name = scenario['name'] ?? 'Unnamed Scenario';

                    return ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(Icons.add, color: Colors.green),
                      onTap: () => _selectScenario(scenario),
                    );
                  },
                ),
    );
  }
}
