import 'package:flutter/material.dart';

import 'theme_constants.dart';
import 'app_design_system.dart';

/// Naham app theme — all values from TC (theme_constants.dart).
class NahamTheme {
  NahamTheme._();

  static const Color primary = ThemeConstants.primary;
  static const Color secondary = ThemeConstants.secondary;
  static const Color headerBackground = ThemeConstants.headerBackground;
  static const Color cardBackground = ThemeConstants.cardBackground;
  static const Color bottomNavBackground = ThemeConstants.bottomNavBackground;
  static const Color textOnPurple = ThemeConstants.textOnPurple;
  static const Color textOnLight = ThemeConstants.textOnLight;
  static const Color textSecondary = ThemeConstants.textSecondary;
  static const String logoAsset = AppDesignSystem.logoAsset;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        primaryContainer: primary.withOpacity(ThemeConstants.opacityPrimaryContainer),
        secondary: secondary,
        surface: cardBackground,
        background: ThemeConstants.scaffoldBackground,
        error: ThemeConstants.errorRed,
        onPrimary: textOnPurple,
        onSecondary: textOnPurple,
        onSurface: textOnLight,
        onBackground: textOnLight,
        onError: ThemeConstants.textOnPurple,
      ),
      scaffoldBackgroundColor: ThemeConstants.scaffoldBackground,
      cardTheme: CardThemeData(
        elevation: ThemeConstants.elevationCard,
        shadowColor: Colors.black.withOpacity(ThemeConstants.opacityShadow),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusCard),
        ),
        color: cardBackground,
      ),
      appBarTheme: AppBarTheme(
        elevation: ThemeConstants.elevationAppBar,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: headerBackground,
        foregroundColor: textOnPurple,
        titleTextStyle: TextStyle(
          color: textOnPurple,
          fontSize: ThemeConstants.fontSizeAppBarTitle,
          fontWeight: ThemeConstants.fontWeightBold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: ThemeConstants.elevationNone,
          backgroundColor: primary,
          foregroundColor: textOnPurple,
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeConstants.buttonPaddingHorizontal,
            vertical: ThemeConstants.buttonPaddingVertical,
          ),
          minimumSize: const Size(double.infinity, ThemeConstants.buttonMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConstants.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeConstants.buttonPaddingHorizontal,
            vertical: ThemeConstants.buttonPaddingVertical,
          ),
          minimumSize: const Size(double.infinity, ThemeConstants.buttonMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConstants.radiusButton),
          ),
          side: BorderSide(color: primary.withOpacity(ThemeConstants.opacityOutlinedBorder)),
          foregroundColor: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ThemeConstants.cardWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(ThemeConstants.opacityBorder)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: primary, width: ThemeConstants.inputFocusedBorderWidth),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.inputContentPaddingHorizontal,
          vertical: ThemeConstants.inputContentPaddingVertical,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBackground,
        selectedItemColor: secondary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: ThemeConstants.elevationNone,
      ),
    );
  }
}
