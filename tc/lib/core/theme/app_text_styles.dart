import 'package:flutter/material.dart';

import 'app_design_system.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get titleLarge => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppDesignSystem.textPrimary,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontSize: 15,
        color: AppDesignSystem.textPrimary,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontSize: 14,
        color: AppDesignSystem.textSecondary,
      );
}
