import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_constants.dart';

/// Admin design system — values from TC theme only (see theme_constants.dart).
class AppDesignSystem {
  AppDesignSystem._();

  // Colors (from ThemeConstants — TC app_theme / naham_theme / app_design_system)
  static const Color primary = ThemeConstants.primary;
  static const Color primaryDark = ThemeConstants.secondary;
  static const Color primaryLight = ThemeConstants.bottomNavBackground;
  static const Color primaryMid = ThemeConstants.primary;
  static const Color headerBackground = ThemeConstants.headerBackground;
  static const Color bottomNavBackground = ThemeConstants.bottomNavBackground;
  static const Color cardBackgroundLavender = ThemeConstants.cardBackground;
  static const Color backgroundWhite = ThemeConstants.cardWhite;
  static const Color backgroundOffWhite = ThemeConstants.backgroundOffWhite;
  static const Color cardWhite = ThemeConstants.cardWhite;
  static const Color surfaceLight = ThemeConstants.surfaceLight;
  static const Color textPrimary = ThemeConstants.textPrimary;
  static const Color textSecondary = ThemeConstants.textSecondary;
  static const Color successGreen = ThemeConstants.successGreen;
  static const Color errorRed = ThemeConstants.errorRed;
  static const Color warningOrange = ThemeConstants.warningOrange;
  static const String logoAsset = 'assets/images/logo.png';

  // Spacing (from ThemeConstants)
  static const double space4 = ThemeConstants.space4;
  static const double space8 = ThemeConstants.space8;
  static const double space12 = ThemeConstants.space12;
  static const double space16 = ThemeConstants.space16;
  static const double space20 = ThemeConstants.space20;
  static const double space24 = ThemeConstants.space24;
  static const double space32 = ThemeConstants.space32;
  static const double space40 = ThemeConstants.space40;
  static const double space48 = ThemeConstants.space48;
  static const double space56 = ThemeConstants.space56;
  static const double space64 = ThemeConstants.space64;
  static const double space72 = ThemeConstants.space72;
  static const double space80 = ThemeConstants.space80;
  static const double defaultPadding = ThemeConstants.defaultPadding;
  static const double screenHorizontalPadding = ThemeConstants.screenHorizontalPadding;

  // Border radius (from ThemeConstants)
  static const double radiusSmall = ThemeConstants.radiusSmall;
  static const double radiusMedium = ThemeConstants.radiusMedium;
  static const double radiusLarge = ThemeConstants.radiusLarge;
  static const double radiusCard = ThemeConstants.radiusCard;
  static const double radiusButton = ThemeConstants.radiusButton;

  // Elevation (from ThemeConstants)
  static const double elevationNone = ThemeConstants.elevationNone;
  static const double elevationCard = ThemeConstants.elevationCard;
  static const double elevationCardHover = ThemeConstants.elevationCardHover;
  static const double elevationModal = ThemeConstants.elevationModal;

  // Typography (from ThemeConstants — font family and sizes/weights)
  static String get fontFamily => ThemeConstants.fontFamily;

  static TextTheme textTheme(Color primaryColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeDisplayLarge,
        fontWeight: ThemeConstants.fontWeightBold,
        letterSpacing: ThemeConstants.letterSpacingDisplayLarge,
        color: primaryColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeDisplayMedium,
        fontWeight: ThemeConstants.fontWeightBold,
        letterSpacing: ThemeConstants.letterSpacingDisplayMedium,
        color: primaryColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeDisplaySmall,
        fontWeight: ThemeConstants.fontWeightBold,
        color: primaryColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeHeadlineLarge,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeHeadlineMedium,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeHeadlineSmall,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeTitleLarge,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeTitleMedium,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeTitleSmall,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeBodyLarge,
        fontWeight: ThemeConstants.fontWeightNormal,
        height: ThemeConstants.lineHeightBodyLarge,
        color: primaryColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeBodyMedium,
        fontWeight: ThemeConstants.fontWeightNormal,
        height: ThemeConstants.lineHeightBodyMedium,
        color: primaryColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeBodySmall,
        fontWeight: ThemeConstants.fontWeightNormal,
        color: ThemeConstants.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: ThemeConstants.fontSizeLabelLarge,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: primaryColor,
      ),
    );
  }
}
