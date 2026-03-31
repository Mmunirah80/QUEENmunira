import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../presentation/providers/auth_provider.dart';

/// Shown when cook has registered or logged in but application is still pending approval.
class CookPendingScreen extends ConsumerWidget {
  const CookPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDesignSystem.space32),
              Icon(
                Icons.hourglass_empty_rounded,
                size: 80,
                color: NahamTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Application submitted',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: NahamTheme.textOnLight,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'An admin must approve your account before you can use the cook app. '
                'You can renew documents from Profile after you are approved.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NahamTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Review usually takes 24–48 hours.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NahamTheme.textSecondary.withOpacity(0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).refreshUser();
                },
                child: const Text('Check approval status'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go(RouteNames.login);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
