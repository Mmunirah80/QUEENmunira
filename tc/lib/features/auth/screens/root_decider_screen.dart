import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../domain/entities/user_entity.dart';
import '../presentation/providers/auth_provider.dart';

/// Role-based navigation (legacy entry). Prefer GoRouter redirects from [app_router.dart].
class RootDeciderScreen extends ConsumerStatefulWidget {
  const RootDeciderScreen({super.key});

  @override
  ConsumerState<RootDeciderScreen> createState() => _RootDeciderScreenState();
}

class _RootDeciderScreenState extends ConsumerState<RootDeciderScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _redirect(user));
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RouteNames.login);
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  void _redirect(UserEntity? user) {
    if (!mounted) return;
    if (user == null || user.role == null) {
      context.go(RouteNames.login);
      return;
    }

    if (user.isBlocked) {
      context.go(RouteNames.accountSuspended);
      return;
    }
    if (user.isAdmin) {
      context.go(RouteNames.adminHome);
      return;
    }
    if (user.isCustomer) {
      context.go(RouteNames.customerRoot);
      return;
    }
    if (user.isChef) {
      context.go(RouteNames.chefHome);
      return;
    }
    context.go(RouteNames.login);
  }
}
