import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'naham_theme.dart';

/// Naham app light theme — purple primary (#9B7EC8), same as Customer screens.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: NahamTheme.primary,
        secondary: NahamTheme.secondary,
        surface: NahamTheme.cardBackground,
        background: const Color(0xFFF5F0FF),
        error: AppDesignSystem.errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppDesignSystem.textPrimary,
        onBackground: AppDesignSystem.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F0FF),
      cardTheme: CardThemeData(
        elevation: AppDesignSystem.elevationCard,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
        ),
        color: NahamTheme.cardBackground,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: NahamTheme.headerBackground,
        foregroundColor: Colors.white,
        titleTextStyle: AppDesignSystem.textTheme(Colors.white).titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space24,
            vertical: AppDesignSystem.space16,
          ),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusButton),
          ),
          textStyle: AppDesignSystem.textTheme(Colors.white).titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space24,
            vertical: AppDesignSystem.space16,
          ),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusButton),
          ),
          side: BorderSide(color: NahamTheme.primary.withOpacity(0.5)),
          foregroundColor: NahamTheme.primary,
          textStyle: AppDesignSystem.textTheme(NahamTheme.primary).titleMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space16,
            vertical: AppDesignSystem.space8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          ),
          foregroundColor: AppDesignSystem.textSecondary,
          textStyle: AppDesignSystem.textTheme(AppDesignSystem.textSecondary).titleSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDesignSystem.cardWhite,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: const BorderSide(color: NahamTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: const BorderSide(color: AppDesignSystem.errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space24,
          vertical: AppDesignSystem.space20,
        ),
        labelStyle: AppDesignSystem.textTheme(AppDesignSystem.textSecondary).bodyLarge,
        hintStyle: AppDesignSystem.textTheme(AppDesignSystem.textSecondary).bodyLarge?.copyWith(
              color: AppDesignSystem.textSecondary.withOpacity(0.7),
            ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        height: 72,
        backgroundColor: NahamTheme.bottomNavBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: NahamTheme.secondary.withOpacity(0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: NahamTheme.secondary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppDesignSystem.textSecondary,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space24,
          vertical: AppDesignSystem.space8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
        ),
        titleTextStyle: AppDesignSystem.textTheme(AppDesignSystem.textPrimary).titleMedium,
        subtitleTextStyle: AppDesignSystem.textTheme(AppDesignSystem.textSecondary).bodyMedium,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.06),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppDesignSystem.cardWhite,
        elevation: AppDesignSystem.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
        ),
        titleTextStyle: AppDesignSystem.textTheme(AppDesignSystem.textPrimary).headlineSmall,
        contentTextStyle: AppDesignSystem.textTheme(AppDesignSystem.textPrimary).bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppDesignSystem.cardWhite,
        elevation: AppDesignSystem.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: AppDesignSystem.textTheme(AppDesignSystem.textPrimary),
    );
  }

  static const Color primaryPurple = NahamTheme.primary;
  static const Color primaryPurpleDark = NahamTheme.secondary;
  static const Color primaryPurpleLight = NahamTheme.bottomNavBackground;
  static const Color successGreen = AppDesignSystem.successGreen;
  static const Color errorRed = AppDesignSystem.errorRed;
  static const Color warningOrange = AppDesignSystem.warningOrange;
  static const Color lightBackground = AppDesignSystem.backgroundOffWhite;
  static const Color lightSurface = AppDesignSystem.surfaceLight;
  static const Color lightTextPrimary = AppDesignSystem.textPrimary;
  static const Color lightTextSecondary = AppDesignSystem.textSecondary;
}
