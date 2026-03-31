import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import 'login_screen.dart';
import '../presentation/providers/auth_provider.dart';

/// Shown when chef application is rejected. Displays reason and option to go back.
class ChefRejectionScreen extends ConsumerWidget {
  const ChefRejectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final reason = user?.rejectionReason ?? 'Your application could not be approved at this time.';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 80,
                color: AppDesignSystem.errorRed.withOpacity(0.8),
              ),
              const SizedBox(height: AppDesignSystem.space24),
              Text(
                'Application not approved',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppDesignSystem.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignSystem.space16),
              Text(
                reason,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignSystem.space48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false,
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: NahamTheme.primary,
                    foregroundColor: NahamTheme.textOnPurple,
                  ),
                  child: const Text('Back to Cook Login'),
                ),
              ),
              const SizedBox(height: AppDesignSystem.space16),
              TextButton(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                    (r) => false,
                  );
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
