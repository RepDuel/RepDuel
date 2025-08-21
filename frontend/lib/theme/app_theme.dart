// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  // Custom color definitions
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color infoColor = Colors.blue;
  
  // Status colors for routines
  static const Color completedColor = Colors.green;
  static const Color inProgressColor = Colors.yellow;
  static const Color pausedColor = Colors.orange;
  static const Color failedColor = Colors.red;
  static const Color pendingColor = Colors.grey;
  
  // Rank colors
  static const Map<String, Color> rankColors = {
    'Unranked': Color(0xFFFFFFFF),
    'Bronze': Color(0xFFcd7f32),
    'Silver': Color(0xFFc0c0c0),
    'Gold': Color(0xFFefbf04),
    'Platinum': Color(0xFF00ced1),
    'Diamond': Color(0xFFb9f2ff),
    'Master': Color(0xFF62f40c),
    'Grandmaster': Color(0xFFff00ff),
    'Champion': Color(0xFFffde21),
    'Legendary': Color(0xFFa45ee5),
    'Mythic': Color(0xFFff4040),
    'Immortal': Color(0xFF00ffff),
  };

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[100],
      primaryColor: Colors.blueAccent,
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.indigoAccent,
        surface: Colors.white,
        onSurface: Colors.black87,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16.0, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black87),
        headlineLarge: TextStyle(fontSize: 24.0, color: Colors.black87, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 20.0, color: Colors.black87, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 18.0, color: Colors.black87, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16.0, color: Colors.black87, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontSize: 14.0, color: Colors.black54),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        fillColor: Colors.grey[200],
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarTheme(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      primaryColor: Colors.tealAccent,
      colorScheme: const ColorScheme.dark(
        primary: Colors.tealAccent,
        secondary: Colors.cyanAccent,
        surface: Color(0xFF2C2C2C),
        onSurface: Colors.white,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        error: errorColor,
        tertiary: Color(0xFF3C3C3C),
        onTertiary: Colors.white70,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2C2C2C),
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16.0, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white),
        headlineLarge: TextStyle(fontSize: 24.0, color: Colors.white, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 20.0, color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 18.0, color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontSize: 14.0, color: Colors.white70),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        fillColor: Colors.grey[900],
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF2C2C2C),
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarTheme(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.grey,
      ),
    );
  }
}
