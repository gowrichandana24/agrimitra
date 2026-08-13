import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriMitraColors {
  static const primary = Color(0xFF3F6B4A); // rice-paddy green
  static const primaryLight = Color(0xFFE7EFE8);
  static const accent = Color(0xFFE8A33D); // turmeric amber
  static const water = Color(0xFF4C7EA8); // monsoon-sky blue
  static const waterLight = Color(0xFFE8F0F6);
  static const background = Color(0xFFF8FAF5); // off-white canvas
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2418); // warm soil-brown, not pure black
  static const inkMuted = Color(0xFF6B6154);
  static const critical = Color(0xFFB3413E);
  static const warning = Color(0xFFD98E2B);
  static const sidebar = Color(0xFF0B3D2E);
  static const sidebarMuted = Color(0xFFBFD8CC);
  static const lightGreenBorder = Color(0xFFDCEADA);
  static const softGreen = Color(0xFFEEF7EE);
}

class AgriMitraTheme {
  static ThemeData get theme {
    final textTheme = TextTheme(
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 26, fontWeight: FontWeight.w600, color: AgriMitraColors.ink,
      ),
      titleLarge: GoogleFonts.fraunces(
        fontSize: 20, fontWeight: FontWeight.w600, color: AgriMitraColors.ink,
      ),
      titleMedium: GoogleFonts.mulish(
        fontSize: 16, fontWeight: FontWeight.w700, color: AgriMitraColors.ink,
      ),
      bodyLarge: GoogleFonts.mulish(fontSize: 16, color: AgriMitraColors.ink),
      bodyMedium: GoogleFonts.mulish(fontSize: 14, color: AgriMitraColors.ink),
      bodySmall: GoogleFonts.mulish(fontSize: 12, color: AgriMitraColors.inkMuted),
      labelLarge: GoogleFonts.mulish(fontSize: 15, fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AgriMitraColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AgriMitraColors.primary,
        primary: AgriMitraColors.primary,
        secondary: AgriMitraColors.accent,
        surface: AgriMitraColors.surface,
        error: AgriMitraColors.critical,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AgriMitraColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AgriMitraColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE7E2D3), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgriMitraColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.mulish(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2D3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2D3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriMitraColors.primary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AgriMitraColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}