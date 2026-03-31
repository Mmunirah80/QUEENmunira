import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../domain/entities/user_entity.dart';
import '../presentation/providers/auth_provider.dart';
import 'signup_screen.dart';

/// Role selection: "Who are you?" — Customer → Sign Up; Chef → GoRouter chef registration (account + docs + Supabase).
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NahamTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.screenHorizontalPadding,
            vertical: AppDesignSystem.space48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    NahamTheme.logoAsset,
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      color: Colors.white24,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, size: 40, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Who are you?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),
              _RoleCard(
                icon: Icons.restaurant,
                title: "I'm a Cook",
                subtitle: 'Share your homemade food',
                color: NahamTheme.primary,
                onTap: () {
                  ref.read(selectedRoleProvider.notifier).state = AppRole.chef;
                  context.go(RouteNames.chefRegAccount);
                },
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.shopping_bag,
                title: "I'm a Customer",
                subtitle: 'Order homemade food',
                color: NahamTheme.primary,
                onTap: () {
                  ref.read(selectedRoleProvider.notifier).state = AppRole.customer;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignupScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  static const Color _iconBackground = Color(0xFF9B7EC8);

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: NahamTheme.primary.withOpacity(0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: NahamTheme.primary.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: Colors.white),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: NahamTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
