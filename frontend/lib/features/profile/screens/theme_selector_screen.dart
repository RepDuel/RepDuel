// frontend/lib/features/profile/screens/theme_selector_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/themes/app_themes.dart';

class ThemeSelectorScreen extends ConsumerWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    
    // --- FIX IS HERE ---
    // Safely access the user from the AsyncValue<AuthState>
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull?.user; 
    // --- END OF FIX ---
    
    // It's good practice to handle the case where the user might not be loaded yet.
    // However, since this screen is likely behind an auth wall, we can proceed.
    // If the user is null, isGoldSubscriber will be false, correctly locking themes.
    final isGoldSubscriber = user?.subscriptionLevel == 'gold' || user?.subscriptionLevel == 'platinum'; // Added platinum for completeness

    return Scaffold(
      backgroundColor: currentTheme.background,
      appBar: AppBar(
        title: Text('Select Theme', style: TextStyle(color: currentTheme.primary)),
        backgroundColor: currentTheme.background,
        iconTheme: IconThemeData(color: currentTheme.primary),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appThemes.length,
        itemBuilder: (context, index) {
          final theme = appThemes[index];
          final bool isSelected = theme.id == currentTheme.id;
          // isPremium themes are locked if the user is not a gold or platinum subscriber
          final bool isLocked = theme.isPremium && !isGoldSubscriber;

          return GestureDetector(
            onTap: () {
              if (isLocked) {
                // Optionally show a dialog before pushing
                context.push('/subscribe');
              } else if (!isSelected) {
                ref.read(themeProvider.notifier).setTheme(theme.id);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? Border.all(color: theme.accent, width: 2) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(theme.name, style: TextStyle(color: theme.primary, fontSize: 18)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ColorSwatch(color: theme.background),
                            _ColorSwatch(color: theme.card),
                            _ColorSwatch(color: theme.primary),
                            _ColorSwatch(color: theme.accent),
                          ],
                        )
                      ],
                    ),
                  ),
                  if (isLocked)
                    const Icon(Icons.lock, color: Colors.amber) // Use a solid amber color
                  else if (isSelected)
                    Icon(Icons.check_circle, color: theme.accent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  const _ColorSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24)
      ),
    );
  }
}