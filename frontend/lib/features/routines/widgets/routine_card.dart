import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class RoutineCard extends StatelessWidget {
  final String name;
  final String? imageUrl; // nullable now
  final String duration;
  final int difficultyLevel; // 1..4

  const RoutineCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.duration,
    required this.difficultyLevel,
  });

  Color _getBarColor(int barIndex, BuildContext context) {
    final theme = Theme.of(context);
    if (difficultyLevel >= barIndex + 1) {
      switch (difficultyLevel) {
        case 1:
          return AppTheme.successColor;
        case 2:
          return AppTheme.inProgressColor;
        case 3:
          return AppTheme.warningColor;
        case 4:
          return AppTheme.errorColor;
        default:
          return AppTheme.pendingColor;
      }
    }
    return theme.colorScheme.tertiary;
  }

  Widget _buildThumb() {
    const placeholder = 'assets/images/placeholder.png';

    // If it's a network URL, try it and fall back to asset on error.
    if (imageUrl != null &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'))) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset(
          placeholder,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }

    // Default to local asset
    return Image.asset(
      placeholder,
      fit: BoxFit.cover,
      width: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: _buildThumb(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      height: 8,
                      width: 20,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _getBarColor(index, context),
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
