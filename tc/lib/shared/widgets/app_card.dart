import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

/// Premium card with elevation depth and consistent radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppDesignSystem.space24),
      child: child,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
    );
    if (onTap != null) {
      return Material(
        color: AppDesignSystem.cardWhite,
        elevation: elevation ?? AppDesignSystem.elevationCard,
        shadowColor: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
          child: content,
        ),
      );
    }
    return Material(
      color: AppDesignSystem.cardWhite,
      elevation: elevation ?? AppDesignSystem.elevationCard,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: shape,
      child: content,
    );
  }
}
