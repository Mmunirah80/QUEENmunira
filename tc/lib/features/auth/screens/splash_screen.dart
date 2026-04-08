import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/naham_theme.dart';
import '../presentation/providers/auth_provider.dart';

/// Splash: purple background, logo + "Naham".
/// Navigation is delegated to GoRouter redirect logic in app_router.dart.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minSplashDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minSplashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final session = Supabase.instance.client.auth.currentSession;

    // Never send the user to Login while auth is still resolving (e.g. restored Supabase session + profile fetch).
    if (_minSplashDone && !auth.isLoading && !_navigated) {
      final user = auth.valueOrNull;
      final failed = auth.hasError;
      final sessionInvalid = session == null || session.isExpired;
      final unauthenticated = failed ||
          sessionInvalid ||
          user == null ||
          user.role == null;
      if (unauthenticated) {
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint(
              '[ROUTER] SplashScreen -> login unauthenticated failed=$failed '
              'sessionInvalid=$sessionInvalid userNull=${user == null} roleNull=${user?.role == null}',
            );
            context.go(RouteNames.login);
          }
        });
      }
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: NahamTheme.primary,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    NahamTheme.logoAsset,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, size: 64, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Naham',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Home food, made with love',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (auth.isLoading) ...[
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
