// frontend/lib/features/profile/widgets/workout_history_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Assuming this might be used elsewhere, though not in this snippet

import '../../../core/providers/workout_history_provider.dart';
import '../../../core/models/routine_submission_read.dart';
import '../../../core/providers/auth_provider.dart'; // Import auth provider

class WorkoutHistoryList extends ConsumerWidget { // Changed to ConsumerWidget
  final String userId;

  const WorkoutHistoryList({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Added WidgetRef ref
    // Watch the workout history provider.
    final historyAsyncValue = ref.watch(workoutHistoryProvider(userId));

    // --- Safely access user data for unit conversions ---
    // Watch authProvider to get the AsyncValue<AuthState>
    final authStateAsyncValue = ref.watch(authProvider);

    // Determine units based on user data. If auth state is loading, error, or user is null,
    // default to kg.
    final userMultiplier = authStateAsyncValue.valueOrNull?.user?.weightMultiplier ?? 1.0;
    final isLbs = userMultiplier > 1.5; // Heuristic for lbs
    const kgToLbs = 2.20462;
    final unit = isLbs ? 'lb' : 'kg';

    // Helper function to convert KG volume to user's unit.
    num toUserUnit(num kg) => isLbs ? (kg * kgToLbs) : kg;

    // Helper to format numbers (integer if whole, else fixed to 1 decimal).
    String formatNum(num n) =>
        (n % 1 == 0) ? n.toInt().toString() : n.toStringAsFixed(1);

    // Helper to format scenario IDs into displayable titles.
    String scenarioTitle(String id) {
      return id
          .split('_')
          .where((p) => p.isNotEmpty) // Filter out empty parts
          .map((p) => p[0].toUpperCase() + p.substring(1)) // Capitalize first letter
          .join(' '); // Join back with spaces
    }

    // Use .when() to handle the states of the workout history provider.
    return historyAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()), // Show loading indicator
      error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))), // Show error message
      data: (entries) { // Build UI when data is available
        // Handle the case where workout history is empty.
        if (entries.isEmpty) {
          return const Center( // Center the message
            child: Text(
              'No workouts logged yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        // Responsive layout logic
        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = screenWidth > 700;
        const minWidth = 300.0;
        const maxWidth = 600.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.map((entry) {
            // Calculate total volume in user's preferred unit.
            final totalVolumeUser = entry.scenarios.fold<double>(
              0.0,
              (sum, s) => sum + toUserUnit(s.totalVolume), // Convert each scenario's volume
            );

            // Group scenario submissions by scenarioId for display.
            final Map<String, List<RoutineScenarioSubmission>> grouped = {};
            for (final s in entry.scenarios) {
              grouped.putIfAbsent(s.scenarioId, () => []).add(s);
            }

            return Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isWide ? minWidth : double.infinity,
                  maxWidth: isWide ? maxWidth : double.infinity,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Time: ${formatNum(entry.duration)} minutes',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      // Display grouped scenario details
                      ...grouped.entries.expand((grp) {
                        final scenarioName = scenarioTitle(grp.key);
                        final items = <Widget>[
                          Text(
                            '$scenarioName:',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ];

                        for (final s in grp.value) {
                          final weightUser = toUserUnit(s.weight); // Convert weight
                          items.add(Text(
                            '${formatNum(weightUser)}$unit x ${s.reps}', // Display with unit
                            style: const TextStyle(color: Colors.white),
                          ));
                        }
                        items.add(const SizedBox(height: 8)); // Add spacing after each scenario group
                        return items;
                      }),
                      Text(
                        'Total Volume: ${formatNum(totalVolumeUser)} $unit', // Display total volume with unit
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(), // Convert the mapped widgets to a list
        );
      },
    );
  }
}