import 'package:flutter/material.dart';

/// Paleta de cores premium do CineMax
/// Inspirada no TLN+ com melhorias visuais
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════
  // BACKGROUNDS
  // ═══════════════════════════════════════════
  static const Color background = Color(0xFF0A0A1A);
  static const Color backgroundLight = Color(0xFF101028);
  static const Color surface = Color(0xFF151530);
  static const Color surfaceLight = Color(0xFF1C1C3A);
  static const Color surfaceVariant = Color(0xFF252548);

  // ═══════════════════════════════════════════
  // PRIMARY (Laranja — estilo TLN+)
  // ═══════════════════════════════════════════
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF9500);
  static const Color primaryDark = Color(0xFFE55A00);
  static const Color primarySurface = Color(0x1AFF6B00); // 10% opacity

  // ═══════════════════════════════════════════
  // ACCENT (Roxo Neon)
  // ═══════════════════════════════════════════
  static const Color accent = Color(0xFF7B2FF7);
  static const Color accentLight = Color(0xFF9D5CFF);
  static const Color accentDark = Color(0xFF5A1FBF);

  // ═══════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Colors.transparent, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFF1A1A3E),
      Color(0xFF0F0F25),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════
  // TEXT
  // ═══════════════════════════════════════════
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E9A);
  static const Color textTertiary = Color(0xFF5A5A6E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ═══════════════════════════════════════════
  // SEMANTIC
  // ═══════════════════════════════════════════
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF448AFF);

  // ═══════════════════════════════════════════
  // RATING (Dourado)
  // ═══════════════════════════════════════════
  static const Color ratingGold = Color(0xFFFFD700);
  static const Color ratingGoldDark = Color(0xFFB8960F);

  // ═══════════════════════════════════════════
  // GLASSMORPHISM
  // ═══════════════════════════════════════════
  static const Color glassBorder = Color(0x14FFFFFF); // 8% white
  static const Color glassBackground = Color(0x1AFFFFFF); // 10% white
  static const Color glassShadow = Color(0x33000000); // 20% black

  // ═══════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════
  static const Color navBackground = Color(0xFF0D0D22);
  static const Color navActive = primary;
  static const Color navInactive = textTertiary;

  // ═══════════════════════════════════════════
  // SHIMMER
  // ═══════════════════════════════════════════
  static const Color shimmerBase = Color(0xFF1A1A35);
  static const Color shimmerHighlight = Color(0xFF2A2A50);

  // ═══════════════════════════════════════════
  // PLUGIN CATEGORIES
  // ═══════════════════════════════════════════
  static const Color categoryMovies = Color(0xFFFF6B00);
  static const Color categorySeries = Color(0xFF7B2FF7);
  static const Color categoryAnime = Color(0xFFE91E63);
  static const Color categoryDoramas = Color(0xFF00BCD4);
}
