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

/// No internet connection — retry button.
class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: NahamEmptyStateContent(
          title: 'No internet connection',
          subtitle: 'Check your connection and try again.',
          buttonLabel: 'Retry',
          onPressed: onRetry,
          fallbackIcon: Icons.wifi_off_rounded,
        ),
      ),
    );
  }
}

/// Empty search results.
class EmptySearchResultsScreen extends StatelessWidget {
  final VoidCallback? onBack;

  const EmptySearchResultsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: NahamEmptyStateContent(
          title: 'No results found',
          subtitle: 'Try different keywords or browse categories.',
          buttonLabel: 'Go back',
          onPressed: onBack ?? () => Navigator.of(context).pop(),
          fallbackIcon: Icons.search_off_rounded,
        ),
      ),
    );
  }
}

/// Empty orders list (full screen or embeddable content).
class EmptyOrdersScreen extends StatelessWidget {
  final VoidCallback? onExplore;
  final bool fullScreen;
  final String? title;
  final String? subtitle;
  final IconData? fallbackIcon;

  const EmptyOrdersScreen({
    super.key,
    this.onExplore,
    this.fullScreen = true,
    this.title,
    this.subtitle,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final content = NahamEmptyStateContent(
      title: title ?? 'No orders yet',
      subtitle: subtitle ?? 'When you place orders, they\'ll show up here.',
      buttonLabel: 'Explore dishes',
      onPressed: onExplore,
      fallbackIcon: fallbackIcon ?? Icons.shopping_bag_rounded,
    );
    if (!fullScreen) return content;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: content),
    );
  }
}

/// Empty chat list — embeddable content.
class EmptyChatContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String actionLabel;

  const EmptyChatContent({
    super.key,
    this.title = 'No conversations yet',
    this.subtitle = 'When customers message you, they\'ll appear here.',
    this.actionLabel = 'OK',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (onAction == null) {
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
                Icons.chat_bubble_outline_rounded,
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
          ],
        ),
      );
    }
    return NahamEmptyStateContent(
      title: title,
      subtitle: subtitle,
      buttonLabel: actionLabel,
      onPressed: onAction,
      fallbackIcon: Icons.chat_bubble_outline_rounded,
    );
  }
}

/// Empty reels / content feed — embeddable content.
class EmptyReelsContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String actionLabel;

  const EmptyReelsContent({
    super.key,
    this.title = 'No reels yet',
    this.subtitle = 'Add a reel to showcase your dishes.',
    this.actionLabel = 'Add reel',
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return NahamEmptyStateContent(
      title: title,
      subtitle: subtitle,
      buttonLabel: actionLabel,
      onPressed: onAction,
      fallbackIcon: Icons.play_circle_outline_rounded,
    );
  }
}

/// Generic error view with retry — for async failure states.
class ErrorStateContent extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? fallbackIcon;
  final String actionLabel;

  const ErrorStateContent({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
    this.fallbackIcon,
    this.actionLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return NahamEmptyStateContent(
      title: 'Oops',
      subtitle: message,
      buttonLabel: actionLabel,
      onPressed: onRetry,
      fallbackIcon: fallbackIcon ?? Icons.error_outline_rounded,
    );
  }
}
