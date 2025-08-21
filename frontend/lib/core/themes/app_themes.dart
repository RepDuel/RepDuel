// frontend/lib/core/themes/app_themes.dart

import 'package:flutter/material.dart';

// 1. The Theme class
class AppTheme {
  final String id;
  final String name;
  final bool isPremium;
  final Color primary;    // Main text, titles
  final Color accent;     // Buttons, interactive elements
  final Color background; // Main scaffold background
  final Color card;       // Card backgrounds
  
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

// 2. The list of available themes
const List<AppTheme> appThemes = [
  AppTheme(
    id: 'default_teal',
    name: 'Default',
    isPremium: false,
    primary: Colors.white,
    accent: Color(0xFF64FFDA), // tealAccent[400]
    background: Colors.black,
    card: Color(0xFF1A1A1A), // grey[900]
  ),
  AppTheme(
    id: 'repduel_gold',
    name: 'RepDuel Gold',
    isPremium: true,
    primary: Colors.white,
    accent: Color(0xFFefbf04), // The Gold rank color
    background: Colors.black,
    card: Color(0xFF1C1A00),
  ),
  AppTheme(
    id: 'celestial_blue',
    name: 'Celestial',
    isPremium: true,
    primary: Colors.white,
    accent: Color(0xFF00ffff), // The Celestial rank color
    background: Color(0xFF010A13),
    card: Color(0xFF0B1927),
  ),
  // ... add more premium themes here
];