// ============================================================
// ACCOUNT BLOCKED — Full screen; cook cannot use the app.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  static const _bg = Color(0xFF121212);
  static const _text = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, size: 48, color: AppDesignSystem.errorRed),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Account Blocked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your cook account has been blocked. Please contact support if you believe this is a mistake.',
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.72), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) context.go(RouteNames.login);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppDesignSystem.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
