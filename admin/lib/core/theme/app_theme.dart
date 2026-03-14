import 'package:flutter/material.dart';

import 'theme_constants.dart';
import 'app_design_system.dart';

/// Naham app light theme — every value from TC (theme_constants.dart).
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: ThemeConstants.primary,
        secondary: ThemeConstants.secondary,
        surface: ThemeConstants.cardBackground,
        background: ThemeConstants.scaffoldBackground,
        error: ThemeConstants.errorRed,
        onPrimary: ThemeConstants.textOnPurple,
        onSecondary: ThemeConstants.textOnPurple,
        onSurface: ThemeConstants.textPrimary,
        onBackground: ThemeConstants.textPrimary,
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
        color: ThemeConstants.cardBackground,
      ),
      appBarTheme: AppBarTheme(
        elevation: ThemeConstants.elevationAppBar,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: ThemeConstants.headerBackground,
        foregroundColor: ThemeConstants.textOnPurple,
        titleTextStyle: AppDesignSystem.textTheme(ThemeConstants.textOnPurple).titleLarge?.copyWith(
              fontWeight: ThemeConstants.fontWeightBold,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: ThemeConstants.elevationNone,
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeConstants.buttonPaddingHorizontal,
            vertical: ThemeConstants.buttonPaddingVertical,
          ),
          minimumSize: const Size(double.infinity, ThemeConstants.buttonMinHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConstants.radiusButton),
          ),
          textStyle: AppDesignSystem.textTheme(ThemeConstants.textOnPurple).titleMedium,
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
          side: BorderSide(color: ThemeConstants.primary.withOpacity(ThemeConstants.opacityOutlinedBorder)),
          foregroundColor: ThemeConstants.primary,
          textStyle: AppDesignSystem.textTheme(ThemeConstants.primary).titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ThemeConstants.textButtonPaddingHorizontal,
            vertical: ThemeConstants.textButtonPaddingVertical,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          ),
          foregroundColor: ThemeConstants.textSecondary,
          textStyle: AppDesignSystem.textTheme(ThemeConstants.textSecondary).titleSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ThemeConstants.cardWhite,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(ThemeConstants.opacityBorder)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(ThemeConstants.opacityBorder)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: ThemeConstants.primary, width: ThemeConstants.inputFocusedBorderWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
          borderSide: BorderSide(color: ThemeConstants.errorRed, width: ThemeConstants.inputErrorBorderWidth),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.inputContentPaddingHorizontal,
          vertical: ThemeConstants.inputContentPaddingVertical,
        ),
        labelStyle: AppDesignSystem.textTheme(ThemeConstants.textSecondary).bodyLarge,
        hintStyle: AppDesignSystem.textTheme(ThemeConstants.textSecondary).bodyLarge?.copyWith(
              color: ThemeConstants.textSecondary.withOpacity(ThemeConstants.opacityHint),
            ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: ThemeConstants.elevationNavBar,
        height: ThemeConstants.navBarHeight,
        backgroundColor: ThemeConstants.bottomNavBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ThemeConstants.secondary.withOpacity(ThemeConstants.opacityNavIndicator),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: ThemeConstants.fontSizeNavLabel,
              fontWeight: ThemeConstants.fontWeightSemiBold,
              color: ThemeConstants.secondary,
            );
          }
          return TextStyle(
            fontSize: ThemeConstants.fontSizeNavLabel,
            fontWeight: ThemeConstants.fontWeightMedium,
            color: ThemeConstants.textSecondary,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ThemeConstants.listTilePaddingHorizontal,
          vertical: ThemeConstants.listTilePaddingVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusMedium),
        ),
        titleTextStyle: AppDesignSystem.textTheme(ThemeConstants.textPrimary).titleMedium,
        subtitleTextStyle: AppDesignSystem.textTheme(ThemeConstants.textSecondary).bodyMedium,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(ThemeConstants.opacityDivider),
        thickness: ThemeConstants.dividerThickness,
        space: ThemeConstants.dividerSpace,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ThemeConstants.cardWhite,
        elevation: ThemeConstants.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConstants.radiusCard),
        ),
        titleTextStyle: AppDesignSystem.textTheme(ThemeConstants.textPrimary).headlineSmall,
        contentTextStyle: AppDesignSystem.textTheme(ThemeConstants.textPrimary).bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ThemeConstants.cardWhite,
        elevation: ThemeConstants.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeConstants.radiusBottomSheetTop)),
        ),
      ),
      textTheme: AppDesignSystem.textTheme(ThemeConstants.textPrimary),
    );
  }

  // Re-export only TC-extracted colors
  static const Color primaryPurple = ThemeConstants.primary;
  static const Color primaryPurpleDark = ThemeConstants.secondary;
  static const Color primaryPurpleLight = ThemeConstants.bottomNavBackground;
  static const Color successGreen = ThemeConstants.successGreen;
  static const Color errorRed = ThemeConstants.errorRed;
  static const Color warningOrange = ThemeConstants.warningOrange;
  static const Color lightBackground = ThemeConstants.backgroundOffWhite;
  static const Color lightSurface = ThemeConstants.surfaceLight;
  static const Color lightTextPrimary = ThemeConstants.textPrimary;
  static const Color lightTextSecondary = ThemeConstants.textSecondary;
}
