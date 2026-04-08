import 'package:flutter/material.dart';

import '../../../../core/theme/app_design_system.dart';

/// Shared chat UI tokens — one visual system for customer, chef, and admin.
abstract final class ChatDesignTokens {
  ChatDesignTokens._();

  static const double listHorizontalPadding = 16;
  static const double listVerticalPadding = 16;
  static const double messageSpacing = 10;
  static const double bubbleRadius = 14;
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 10);

  /// Muted label above each bubble (role / name).
  static const TextStyle roleLabelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppDesignSystem.textSecondary,
    height: 1.2,
  );

  static const TextStyle timeStyle = TextStyle(
    fontSize: 11,
    color: AppDesignSystem.textSecondary,
  );

  /// Current user — soft primary wash (not full-strength [AppDesignSystem.primary]).
  static Color get bubbleOutgoingBg =>
      AppDesignSystem.primaryLight.withValues(alpha: 0.42);

  static const Color bubbleOutgoingFg = AppDesignSystem.textPrimary;

  /// Other party in a normal thread (customer ↔ chef).
  static const Color bubbleIncomingBg = Color(0xFFF3F4F6);
  static const Color bubbleIncomingFg = AppDesignSystem.textPrimary;

  /// Admin / support staff messages (distinct from peer).
  static const Color bubbleSupportBg = Color(0xFFE8EAF6);
  static const Color bubbleSupportFg = Color(0xFF283593);
}
