import 'package:flutter/material.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import 'scenario_screen.dart';

class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  // DOTS benchmarks (minimum score for each rank)
  final Map<String, int> dotsBenchmarks = {
    'Iron': 120,
    'Bronze': 150,
    'Silver': 180,
    'Gold': 210,
    'Platinum': 240,
    'Diamond': 270,
    'Jade': 300,
    'Master': 330,
    'Grandmaster': 360,
    'Nova': 400,
    'Astra': 450,
    'Celestial': 500,
  };

  // Energy values for each rank
  final Map<String, int> rankEnergy = {
    'Iron': 100,
    'Bronze': 200,
    'Silver': 300,
    'Gold': 400,
    'Platinum': 500,
    'Diamond': 600,
    'Jade': 700,
    'Master': 800,
    'Grandmaster': 900,
    'Nova': 1000,
    'Astra': 1100,
    'Celestial': 1200,
  };

  // User's current high scores (replace with actual data)
  final Map<String, double> userHighScores = {
    'Bench': 135.0,
    'Squat': 185.0,
    'Deadlift': 225.0,
  };

  // Calculate rank based on score
  String calculateRank(double score) {
    String currentRank = 'Iron';
    for (var entry in rankEnergy.entries) {
      if (score >= entry.value) {
        currentRank = entry.key;
      } else {
        break;
      }
    }
    return currentRank;
  }

  // Calculate progress text (current/next rank)
  String calculateProgress(double score, String currentRank) {
    final ranks = dotsBenchmarks.keys.toList();
    final currentIndex = ranks.indexOf(currentRank);

    if (currentIndex < ranks.length - 1) {
      final nextRank = ranks[currentIndex + 1];
      final nextBenchmark = dotsBenchmarks[nextRank]!;
      return '${score.toStringAsFixed(1)} / $nextBenchmark';
    }
    return '${score.toStringAsFixed(1)} (Max)';
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total raw ELO (sum of all energy values)
    int totalRawElo = 0;
    final liftRanks = <String, String>{};
    final liftEnergies = <String, int>{};

    userHighScores.forEach((lift, score) {
      final rank = calculateRank(score);
      liftRanks[lift] = rank;
      liftEnergies[lift] = rankEnergy[rank]!;
      totalRawElo += rankEnergy[rank]!;
    });

    // Calculate adjusted ELO (divided by 3)
    final adjustedElo = totalRawElo / 3;
    final overallRank = calculateRank(adjustedElo);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Energy: ${adjustedElo.toStringAsFixed(1)} $overallRank'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Table header
            const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Lift',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Score',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Energy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Table rows
            ...userHighScores.entries.map((entry) {
              final lift = entry.key;
              final score = entry.value;
              final rank = liftRanks[lift]!;
              final progress = calculateProgress(score, rank);
              final energy = liftEnergies[lift]!;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScenarioScreen(liftName: lift),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Lift Name
                      Expanded(
                        flex: 2,
                        child: Text(
                          lift,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Score
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            score.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // Progress
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: (score - dotsBenchmarks[rank]!) /
                                  (dotsBenchmarks[rank == 'Celestial'
                                          ? rank
                                          : dotsBenchmarks.keys.elementAt(
                                              dotsBenchmarks.keys
                                                      .toList()
                                                      .indexOf(rank) +
                                                  1)]! -
                                      dotsBenchmarks[rank]!),
                              backgroundColor: Colors.grey[800],
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rank
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            rank,
                            style: TextStyle(
                              fontSize: 16,
                              color: _getRankColor(rank),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Energy
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            energy.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // TODO: Navigation
        },
      ),
    );
  }

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'Iron':
        return Colors.grey;
      case 'Bronze':
        return const Color(0xFFcd7f32);
      case 'Silver':
        return const Color(0xFFc0c0c0);
      case 'Gold':
        return const Color(0xFFffd700);
      case 'Platinum':
        return const Color(0xFFe5e4e2);
      case 'Diamond':
        return const Color(0xFFb9f2ff);
      case 'Jade':
        return const Color(0xFF00a86b);
      case 'Master':
        return const Color(0xFF9b59b6);
      case 'Grandmaster':
        return const Color(0xFFe74c3c);
      case 'Nova':
        return const Color(0xFF3498db);
      case 'Astra':
        return const Color(0xFF2ecc71);
      case 'Celestial':
        return const Color(0xFFf1c40f);
      default:
        return Colors.white;
    }
  }
}
