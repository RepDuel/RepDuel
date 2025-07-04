import 'package:flutter/material.dart';

class RoutineCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String duration;
  final int difficultyLevel; // 1 to 4

  const RoutineCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.duration,
    required this.difficultyLevel,
  });

  Color _getBarColor(int barIndex) {
    if (difficultyLevel >= barIndex + 1) {
      switch (difficultyLevel) {
        case 1:
          return Colors.green;
        case 2:
          return Colors.yellow;
        case 3:
          return Colors.orange;
        case 4:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }
    return Colors.grey[800]!;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          AspectRatio(
            aspectRatio: 1, // Make it a square
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // Difficulty Bars
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      height: 8,
                      width: 20,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _getBarColor(index),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
