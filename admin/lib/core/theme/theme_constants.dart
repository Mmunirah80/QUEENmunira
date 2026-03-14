import 'package:flutter/material.dart';

/// Extracted from TC lib/core/theme/ (app_theme.dart, naham_theme.dart, app_design_system.dart, app_text_styles.dart).
/// Admin app MUST use only these values — no other colors, fonts, or style constants.
class ThemeConstants {
  ThemeConstants._();

  // ─── Colors (from NahamTheme + AppDesignSystem) ─────────────────────────
  static const Color primary = Color(0xFF9B7EC8);
  static const Color secondary = Color(0xFF7B5EA7);
  static const Color headerBackground = Color(0xFF9B7EC8);
  static const Color cardBackground = Color(0xFFE8E4F0);
  static const Color bottomNavBackground = Color(0xFFC4B0E8);
  static const Color textOnPurple = Colors.white;
  static const Color textOnLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color scaffoldBackground = Color(0xFFF5F0FF);

  static const Color textPrimary = Color(0xFF1A1D1E);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color backgroundOffWhite = Color(0xFFFAFBFC);
  static const Color surfaceLight = Color(0xFFF1F3F4);

  static const Color successGreen = Color(0xFF00B894);
  static const Color errorRed = Color(0xFFD63031);
  static const Color warningOrange = Color(0xFFFDCB6E);

  // Opacity values used in TC theme (use with Color.withOpacity)
  static const double opacityShadow = 0.08;
  static const double opacityPrimaryContainer = 0.2;
  static const double opacityOutlinedBorder = 0.5;
  static const double opacityNavIndicator = 0.25;
  static const double opacityHint = 0.7;
  static const double opacityDivider = 0.06;
  static const double opacityBorder = 0.08;

  // ─── Spacing (8pt grid, from AppDesignSystem) ──────────────────────────
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space72 = 72.0;
  static const double space80 = 80.0;
  static const double defaultPadding = 24.0;
  static const double screenHorizontalPadding = 24.0;

  // ─── Border radius (from AppDesignSystem) ──────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusCard = 20.0;
  static const double radiusButton = 14.0;
  static const double radiusBottomSheetTop = 20.0;

  // ─── Elevation (from AppDesignSystem) ─────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationCard = 4.0;
  static const double elevationCardHover = 8.0;
  static const double elevationModal = 12.0;
  static const double elevationAppBar = 0.0;
  static const double elevationNavBar = 8.0;
  static const double navBarHeight = 72.0;
  // Bottom nav container (from TC ChefShell)
  static const double navBarBorderRadiusTop = 20.0;
  static const double navBarShadowOpacity = 0.1;
  static const double navBarShadowBlur = 16.0;
  static const double navBarShadowOffsetY = -4.0;

  // ─── Typography: font family (from AppDesignSystem) ────────────────────
  static const String fontFamily = 'Inter';

  // Font sizes
  static const double fontSizeDisplayLarge = 34.0;
  static const double fontSizeDisplayMedium = 28.0;
  static const double fontSizeDisplaySmall = 24.0;
  static const double fontSizeHeadlineLarge = 22.0;
  static const double fontSizeHeadlineMedium = 20.0;
  static const double fontSizeHeadlineSmall = 18.0;
  static const double fontSizeTitleLarge = 18.0;
  static const double fontSizeTitleMedium = 16.0;
  static const double fontSizeTitleSmall = 14.0;
  static const double fontSizeBodyLarge = 16.0;
  static const double fontSizeBodyMedium = 15.0;
  static const double fontSizeBodySmall = 14.0;
  static const double fontSizeLabelLarge = 15.0;
  static const double fontSizeAppBarTitle = 20.0;
  static const double fontSizeNavLabel = 12.0;

  // Font weights
  static const FontWeight fontWeightBold = FontWeight.w700;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightNormal = FontWeight.normal;

  // Letter spacing
  static const double letterSpacingDisplayLarge = -0.5;
  static const double letterSpacingDisplayMedium = -0.3;

  // Line height
  static const double lineHeightBodyLarge = 1.5;
  static const double lineHeightBodyMedium = 1.45;

  // ─── Button / input dimensions (from app_theme) ────────────────────────
  static const double buttonMinHeight = 56.0;
  static const double buttonPaddingHorizontal = 24.0;
  static const double buttonPaddingVertical = 16.0;
  static const double textButtonPaddingHorizontal = 16.0;
  static const double textButtonPaddingVertical = 8.0;
  static const double inputContentPaddingHorizontal = 24.0;
  static const double inputContentPaddingVertical = 20.0;
  static const double inputFocusedBorderWidth = 2.0;
  static const double inputErrorBorderWidth = 2.0;
  static const double listTilePaddingHorizontal = 24.0;
  static const double listTilePaddingVertical = 8.0;
  static const double dividerThickness = 1.0;
  static const double dividerSpace = 1.0;
}
