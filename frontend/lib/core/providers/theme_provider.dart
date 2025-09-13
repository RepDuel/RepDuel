// frontend/lib/core/providers/theme_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../themes/app_themes.dart';

class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(appThemes.first) {
    _loadTheme();
  }

  static const String _themeIdKey = 'selected_theme_id';

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId = prefs.getString(_themeIdKey) ?? appThemes.first.id;
    final theme = appThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => appThemes.first,
    );
    state = theme;
  }

  Future<void> setTheme(String themeId) async {
    final theme = appThemes.firstWhere(
      (t) => t.id == themeId,
      orElse: () => appThemes.first,
    );
    state = theme;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, themeId);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppTheme>((ref) {
  return ThemeNotifier();
});
