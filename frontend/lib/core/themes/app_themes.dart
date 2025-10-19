// frontend/lib/core/themes/app_themes.dart

import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String name;
  final bool isPremium;
  final Color primary;
  final Color accent;
  final Color background;
  final Color card;

  const AppTheme({
    required this.id,
    required this.name,
    this.isPremium = false,
    required this.primary,
    required this.accent,
    required this.background,
    required this.card,
  });
}

const List<AppTheme> appThemes = [
  AppTheme(
    id: 'default_white',
    name: 'Default',
    isPremium: false,
    primary: Colors.white,
    accent: Colors.white,
    background: Colors.black,
    card: Color(0xFF1A1A1A),
  ),
  AppTheme(
    id: 'repduel_gold',
    name: 'RepDuel Gold',
    isPremium: true,
    primary: Colors.white,
    accent: Color(0xFFefbf04),
    background: Colors.black,
    card: Color(0xFF1C1A00),
  ),
  AppTheme(
    id: 'celestial_blue',
    name: 'Celestial',
    isPremium: true,
    primary: Colors.white,
    accent: Color(0xFF00ffff),
    background: Color(0xFF010A13),
    card: Color(0xFF0B1927),
  ),
];
