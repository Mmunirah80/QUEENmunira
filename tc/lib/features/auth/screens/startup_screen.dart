import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/app_logo.dart';
import '../presentation/providers/auth_provider.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // Navigate based on auth state
    authState.whenData((user) {
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(RouteNames.home);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(RouteNames.login);
        });
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppDesignSystem.primaryGreen,
              AppDesignSystem.primaryGreenDark,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 120, color: Colors.white),
              const SizedBox(height: AppDesignSystem.space32),
              Text(
                'NAHAM',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppDesignSystem.space8),
              Text(
                'Cook App',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: AppDesignSystem.space48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
