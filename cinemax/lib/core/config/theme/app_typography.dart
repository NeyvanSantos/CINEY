import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia premium do CineMax
/// Fonte: Outfit (Google Fonts) - moderna e elegante
class AppTypography {
  AppTypography._();

  // ═══════════════════════════════════════════
  // DISPLAY (Títulos grandes, hero banners)
  // ═══════════════════════════════════════════
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
    color: Colors.white,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    color: Colors.white,
  );

  static TextStyle displaySmall = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.2,
    color: Colors.white,
  );

  // ═══════════════════════════════════════════
  // HEADLINE (Títulos de seções)
  // ═══════════════════════════════════════════
  static TextStyle headlineLarge = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.3,
    color: Colors.white,
  );

  static TextStyle headlineMedium = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: Colors.white,
  );

  static TextStyle headlineSmall = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: Colors.white,
  );

  // ═══════════════════════════════════════════
  // BODY (Texto geral, sinopses)
  // ═══════════════════════════════════════════
  static TextStyle bodyLarge = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    color: Colors.white,
  );

  static TextStyle bodyMedium = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
    color: Colors.white,
  );

  static TextStyle bodySmall = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.4,
    color: Colors.white70,
  );

  // ═══════════════════════════════════════════
  // LABEL (Botões, chips, badges)
  // ═══════════════════════════════════════════
  static TextStyle labelLarge = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: Colors.white,
  );

  static TextStyle labelMedium = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.2,
    color: Colors.white,
  );

  static TextStyle labelSmall = GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.2,
    color: Colors.white70,
  );

  // ═══════════════════════════════════════════
  // SPECIAL
  // ═══════════════════════════════════════════
  static TextStyle rating = GoogleFonts.outfit(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: const Color(0xFFFFD700),
  );

  static TextStyle pluginName = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: Colors.white,
  );

  static TextStyle pluginDescription = GoogleFonts.outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: Colors.white54,
  );
}
