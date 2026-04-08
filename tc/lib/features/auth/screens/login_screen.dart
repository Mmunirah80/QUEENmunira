import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/entities/user_entity.dart';
import '../presentation/providers/auth_provider.dart';
import 'role_selection_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await ref.read(authStateProvider.notifier).login(
            _emailController.text.trim(),
            _passwordController.text,
            ref.read(selectedRoleProvider),
          );

      if (!mounted) return;
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        debugPrint('[AUTH] login UI: user null after successful login call');
        SnackbarHelper.error(
          context,
          'Could not load your account after sign-in. Try again.',
        );
        return;
      }
      if (user.role == null) {
        debugPrint('[AUTH] login UI: role null uid=${user.id}');
        SnackbarHelper.error(
          context,
          'Your profile has no role. Contact support or try signing in again.',
        );
        return;
      }

      // Stabilizes role-scoped providers if profile.role lags after auth refresh.
      if (user.isChef) {
        ref.read(selectedRoleProvider.notifier).state = AppRole.chef;
      } else if (user.isCustomer) {
        ref.read(selectedRoleProvider.notifier).state = AppRole.customer;
      } else if (user.isAdmin) {
        ref.read(selectedRoleProvider.notifier).state = AppRole.admin;
      }

      debugPrint('[ROUTER] login ok role=${user.role} -> splash');
      // Route through splash so GoRouter redirect remains the single source of truth.
      context.go(RouteNames.splash);
    } catch (e, st) {
      debugPrint('[Login] RAW ERROR TYPE: ${e.runtimeType}');
      debugPrint('[Login] RAW ERROR MESSAGE: ${_loginDebugErrorLine(e)}');
      debugPrint('[Login] STACK: $st');
      if (mounted) {
        final msg = kDebugMode
            ? _loginDebugSnackBarText(e)
            : userFriendlyErrorMessage(e, fallback: 'Sign in failed.');
        SnackbarHelper.error(context, msg);
      }
    }
  }

  /// Debug-only: full server fields, not a wrapped [Exception] string.
  String _loginDebugErrorLine(Object e) {
    if (e is AuthException) {
      return 'AuthException statusCode=${e.statusCode} message=${e.message}';
    }
    if (e is PostgrestException) {
      return 'PostgrestException code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}';
    }
    return e.toString();
  }

  String _loginDebugSnackBarText(Object e) {
    final line = _loginDebugErrorLine(e);
    return '$line\n(Full stack in console.)';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.screenHorizontalPadding,
            vertical: AppDesignSystem.space48,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
                    child: Image.asset(
                      NahamTheme.logoAsset,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
                        ),
                        child: Icon(
                          Icons.restaurant_rounded,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.space40),
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesignSystem.space8),
                Text(
                  'Welcome back. Enter your details to continue.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppDesignSystem.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesignSystem.space40),
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.isValidEmail) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space24),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ForgotPasswordScreen()),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.space32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.space24),
                // Sign up link → Role Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
