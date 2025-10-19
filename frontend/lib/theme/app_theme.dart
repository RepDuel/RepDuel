// frontend/lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme =
        GoogleFonts.robotoTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey[100],
      primaryColor: Colors.blueAccent,
      colorScheme: const ColorScheme.light(
        primary: Colors.blueAccent,
        secondary: Colors.indigoAccent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.roboto(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        toolbarTextStyle: GoogleFonts.roboto(
          color: Colors.black87,
          fontSize: 16,
        ),
      ),
      textTheme: baseTextTheme,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      fontFamily: GoogleFonts.roboto().fontFamily,
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme =
        GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      primaryColor: Colors.tealAccent,
      colorScheme: const ColorScheme.dark(
        primary: Colors.tealAccent,
        secondary: Colors.cyanAccent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        toolbarTextStyle: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      textTheme: baseTextTheme,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      fontFamily: GoogleFonts.roboto().fontFamily,
    );
  }
}
