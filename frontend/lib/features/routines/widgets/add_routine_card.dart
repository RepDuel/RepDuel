// frontend/lib/features/routines/widgets/add_routine_card.dart
import 'package:flutter/material.dart';

class AddRoutineCard extends StatelessWidget {
  final VoidCallback onPressed;
  const AddRoutineCard({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Create Routine',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: theme.colorScheme.onTertiary.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // keep square thumbnail proportion like RoutineCard
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    color: theme.scaffoldBackgroundColor,
                    border: Border.all(
                        color: theme.colorScheme.onTertiary.withOpacity(0.1), style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Icon(Icons.add, size: 48, color: theme.colorScheme.onTertiary),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Routine',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build your own template',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
