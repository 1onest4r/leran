import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  //color palette
  static const Color primary = Color(0xFF50C878);
  static const Color secondary = Color(0xFF56815E);
  static const Color tertiary = Color(0xFFFF9587);
  static const Color neutral = Color(0xFF121212);

  //surface colors for cards and fiels?
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: neutral,

      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: darkSurface,
        onSurface: Colors.white,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(color: Colors.white70),
        labelMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: Colors.white60,
        ),
      ),

      //input decor (the search bar look)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF242424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
      ),

      //button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),

      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: lightSurface,
        onSurface: neutral,
      ),

      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          color: neutral,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          color: neutral,
        ),
        bodyLarge: GoogleFonts.inter(color: Colors.black87),
        labelMedium: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );
  }
}
