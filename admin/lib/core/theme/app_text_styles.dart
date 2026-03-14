import 'package:flutter/material.dart';

import 'theme_constants.dart';

/// Text styles — only TC-extracted values (theme_constants.dart).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get titleLarge => TextStyle(
        fontSize: ThemeConstants.fontSizeTitleLarge,
        fontWeight: ThemeConstants.fontWeightSemiBold,
        color: ThemeConstants.textPrimary,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: ThemeConstants.fontSizeBodyMedium,
        color: ThemeConstants.textPrimary,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: ThemeConstants.fontSizeBodySmall,
        color: ThemeConstants.textSecondary,
      );
}
