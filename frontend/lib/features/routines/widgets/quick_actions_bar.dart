// frontend/lib/features/routines/widgets/quick_actions_bar.dart

import 'package:flutter/material.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({
    super.key,
    required this.onQuickWorkout,
    required this.onCreateRoutine,
    required this.onImportRoutine,
  });

  final VoidCallback onQuickWorkout;
  final VoidCallback onCreateRoutine;
  final VoidCallback onImportRoutine;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _ActionChip(
        icon: Icons.flash_on,
        label: 'Quick Workout',
        onPressed: onQuickWorkout,
      ),
      _ActionChip(
        icon: Icons.add,
        label: 'Create Routine',
        onPressed: onCreateRoutine,
      ),
      _ActionChip(
        icon: Icons.download,
        label: 'Import',
        onPressed: onImportRoutine,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i != 0) const SizedBox(width: 8),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
