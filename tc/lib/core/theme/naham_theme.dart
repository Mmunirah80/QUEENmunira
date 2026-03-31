import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_design_system.dart';

/// Naham app theme — Customer purple reference.
/// Primary #9B7EC8, secondary #7B5EA7, cards #E8E4F0, bottom nav light purple.
class NahamTheme {
  NahamTheme._();

  // ─── Colors (match REFERENCE Customer screens) ─────────────────────────
  static const Color primary = Color(0xFF9B7EC8);
  static const Color secondary = Color(0xFF7B5EA7);
  static const Color headerBackground = Color(0xFF9B7EC8);
  static const Color cardBackground = Color(0xFFE8E4F0);
  static const Color bottomNavBackground = Color(0xFFC4B0E8);
  static const Color textOnPurple = Colors.white;
  static const Color textOnLight = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const String logoAsset = AppDesignSystem.logoAsset;

  /// On web, avoid downloading Roboto from fonts.gstatic.com (often fails offline / blocked CDN).
  static const String _webFontStack =
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif';

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primary,
      primaryContainer: primary.withOpacity(0.2),
      secondary: secondary,
      surface: cardBackground,
      background: const Color(0xFFF5F0FF),
      error: AppDesignSystem.errorRed,
      onPrimary: textOnPurple,
      onSecondary: textOnPurple,
      onSurface: textOnLight,
      onBackground: textOnLight,
      onError: Colors.white,
    );

    final textTheme = kIsWeb
        ? Typography.material2021(colorScheme: colorScheme).black.apply(
              fontFamily: _webFontStack,
              bodyColor: textOnLight,
              displayColor: textOnLight,
            )
        : AppDesignSystem.textTheme(textOnLight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: kIsWeb ? _webFontStack : null,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF5F0FF),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
        ),
        color: cardBackground,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: headerBackground,
        foregroundColor: textOnPurple,
        titleTextStyle: const TextStyle(
          color: textOnPurple,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: textOnPurple,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.space24,
            vertical: AppDesignSystem.space16,
          ),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusButton),
          ),
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
          side: BorderSide(color: primary.withOpacity(0.6)),
          foregroundColor: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.space24,
          vertical: AppDesignSystem.space20,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bottomNavBackground,
        selectedItemColor: secondary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
