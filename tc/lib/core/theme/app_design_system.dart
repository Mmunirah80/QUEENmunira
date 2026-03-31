import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium design system — Uber Eats / Airbnb tier.
/// Ultra clean, confident typography, 8pt grid, elevation depth.
class AppDesignSystem {
  AppDesignSystem._();

  // ─── Color System ─────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  static const Color primaryGreenLight = Color(0xFF4CAF50);

  static const Color secondaryPurple = Color(0xFF6C5CE7);
  static const Color secondaryPurpleLight = Color(0xFF8B7FE8);

  static const Color backgroundOffWhite = Color(0xFFFAFBFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF1F3F4);

  static const Color textPrimary = Color(0xFF1A1D1E);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color successGreen = Color(0xFF00B894);
  static const Color errorRed = Color(0xFFD63031);
  static const Color warningOrange = Color(0xFFFDCB6E);

  static const Color splashGradientStart = Color(0xFF6C3FC5);
  static const Color splashGradientEnd = Color(0xFF2A5A2A);

  /// Cook / chef flow primary.
  static const Color cookPrimary = Color(0xFF6C3FC5);
  /// Customer flow primary.
  static const Color customerPrimary = Color(0xFFD4541A);

  // ─── Naham app theme (reference: Customer purple) ─────────────────────
  static const Color primary = Color(0xFF9B7EC8);
  static const Color primaryDark = Color(0xFF7B5EA7);
  static const Color primaryLight = Color(0xFFC4B0E8);
  static const Color primaryMid = Color(0xFF9B7EC8);
  static const Color headerBackground = Color(0xFF9B7EC8);
  static const Color bottomNavBackground = Color(0xFFC4B0E8);
  static const Color cardBackgroundLavender = Color(0xFFE8E4F0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const String logoAsset = 'assets/images/logo.png';

  // ─── Spacing (8pt grid strictly) ──────────────────────────────────────
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space72 = 72.0;
  static const double space80 = 80.0;

  static const double space20 = 20.0;
  static const double defaultPadding = 24.0;
  static const double screenHorizontalPadding = 24.0;

  // ─── Border Radius ────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusCard = 20.0;
  static const double radiusButton = 14.0;

  // ─── Elevation (depth layers) ─────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationCard = 4.0;
  static const double elevationCardHover = 8.0;
  static const double elevationModal = 12.0;

  // ─── Typography (confident, strong hierarchy) ──────────────────────────
  static String get fontFamily => 'Inter';

  static TextTheme textTheme(Color primaryColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primaryColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primaryColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: primaryColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        height: 1.45,
        color: primaryColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    );
  }
}
