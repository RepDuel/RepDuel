// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[100],
      primaryColor: Colors.blueAccent,
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.indigoAccent,
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
        bodyLarge: TextStyle(fontSize: 16.0),
        bodyMedium: TextStyle(fontSize: 14.0),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
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
        bodyLarge: TextStyle(fontSize: 16.0),
        bodyMedium: TextStyle(fontSize: 14.0),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
