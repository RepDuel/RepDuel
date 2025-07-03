import 'package:flutter/material.dart';
import '../../../widgets/main_bottom_nav_bar.dart';

class RankedScreen extends StatelessWidget {
  const RankedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lifts = [
      {
        'name': 'Bench',
        'score': '100',
        'progress': '100 / 135',
        'rank': '❓',
        'energy': '0',
      },
      {
        'name': 'Squat',
        'score': '100',
        'progress': '100 / 135',
        'rank': '❓',
        'energy': '0',
      },
      {
        'name': 'Deadlift',
        'score': '100',
        'progress': '100 / 135',
        'rank': '❓',
        'energy': '0',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ELO: 0 Unranked'),
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
                    'Name',
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
                  flex: 4,
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
                  flex: 1,
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
                  flex: 1,
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
                SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            // Table rows
            ...lifts.map((lift) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Name
                      Expanded(
                        flex: 2,
                        child: Text(
                          lift['name']!,
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
                            lift['score']!,
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
                        child: Stack(
                          children: [
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Center(
                              child: Text(
                                lift['progress']!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rank
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            lift['rank']!,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Energy
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            lift['energy']!,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Leaderboard button
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          icon: const Text('📊'),
                          onPressed: () {
                            // TODO: Implement leaderboard screen routing
                          },
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // TODO: Implement navigation based on index
        },
      ),
    );
  }
}
