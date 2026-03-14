import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import '../theme/naham_theme.dart';

/// Reusable empty state content: logo, title, subtitle, button. Naham purple theme.
class NahamEmptyStateContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final IconData? fallbackIcon;

  const NahamEmptyStateContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    this.onPressed,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            NahamTheme.logoAsset,
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              fallbackIcon ?? Icons.inbox_rounded,
              size: 80,
              color: NahamTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NahamTheme.textOnLight,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: NahamTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed ?? () {},
              style: FilledButton.styleFrom(
                backgroundColor: NahamTheme.primary,
                foregroundColor: NahamTheme.textOnPurple,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusButton),
                ),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorStateContent extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateContent({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return NahamEmptyStateContent(
      title: 'Oops',
      subtitle: message,
      buttonLabel: 'Retry',
      onPressed: onRetry,
      fallbackIcon: Icons.error_outline_rounded,
    );
  }
}
