import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/screens/admin_main_navigation_screen.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/chef_reg_account_screen.dart';
import '../../features/auth/screens/chef_reg_documents_screen.dart';
import '../../features/auth/screens/chef_reg_success_screen.dart';
import '../../features/auth/screens/root_decider_screen.dart';
import '../../features/auth/screens/chef_rejection_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/cook_pending_screen.dart';
import '../../features/cook/screens/home_screen.dart';
import '../../features/cook/screens/orders_screen.dart';
import '../../features/cook/screens/menu_screen.dart';
import '../../features/cook/screens/reels_screen.dart';
import '../../features/cook/screens/chat_screen.dart';
import '../../features/cook/screens/profile_screen.dart';
import '../../features/cook/screens/inspection_call_screen.dart';
import '../../features/cook/screens/frozen_screen.dart';
import '../../features/cook/screens/blocked_screen.dart';
import '../../features/cook/data/models/chef_doc_model.dart';
import '../../features/cook/presentation/providers/chef_providers.dart';
import '../../features/cook/presentation/widgets/chef_limited_mode_layer.dart';
import '../../features/cook/presentation/widgets/chef_presence_wrapper.dart';
import '../../features/cook/presentation/widgets/inspection_call_listener.dart';
import '../../features/customer/screens/customer_main_navigation_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../constants/route_names.dart';

/// Notifies [GoRouter] when [authStateProvider] changes so redirects re-run.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final goRouterRefreshProvider = Provider<GoRouterRefreshNotifier>((ref) {
  return GoRouterRefreshNotifier(ref);
});

String? _splashTarget(UserEntity? user) {
  final session = Supabase.instance.client.auth.currentSession;
  // Keep unauthenticated entry flow as Splash -> Login.
  // Splash screen handles the transition to login after its minimum display.
  if (session == null || session.isExpired || user == null || user.role == null) return null;
  if (user.isBlocked) return RouteNames.accountSuspended;
  // Rejected chefs stay in-app (Chat + Profile + Documents); do not isolate on chefRejection.
  if (user.isChefRejected) return RouteNames.chefHome;
  if (user.isChefPending) return RouteNames.chefHome;
  if (user.isAdmin) return RouteNames.adminHome;
  if (user.isCustomer) return RouteNames.customerRoot;
  if (user.isChefApproved) return RouteNames.chefHome;
  if (user.isChef) return RouteNames.chefHome;
  return RouteNames.login;
}

String _rejectionSubtitle(UserEntity user) {
  final r = user.rejectionReason?.trim();
  if (r != null && r.isNotEmpty) {
    return '$r\n\nYou can still use Chat, Notifications, and Profile. Open Profile → Documents to upload new files.';
  }
  return 'You can still use Chat, Notifications, and Profile. Open Profile → Documents to upload new files.';
}

/// Chef shell modes (minimal product contract):
/// - **Pending account** — new chef: `approval_status` not `approved`/`rejected`; main tabs locked; Chat, Profile,
///   Notifications, Documents allowed (documents via Profile).
/// - **Renewal in review** — approved account with a newer pending upload but still-compliant older docs: full app
///   until admin acts (see cook feature `chef_documents_compliance.dart`).
/// - **Doc rejected / suspended** — `approval_status` approved + `suspended`: main tabs locked; same escape hatches as pending.
/// - **Account rejected** — `approval_status` rejected: same shell lock; admin sets `rejection_reason`.
/// Approve/reject (admin): notifications + Support-thread chat; document reject requires reason (see admin UI).
bool _chefAwaitingAccountApproval(UserEntity? user, ChefDocModel? chefDoc) {
  if (user?.isChef != true || user!.isChefRejected) return false;
  if (chefDoc != null) {
    final s = chefDoc.approvalStatus?.toLowerCase() ?? '';
    if (s == 'approved' || s == 'rejected') return false;
    return true;
  }
  return user.isChefPending;
}

bool _isPublicPath(String path) {
  return path == RouteNames.splash ||
      path == RouteNames.onboarding ||
      path == RouteNames.roleSelection ||
      path == RouteNames.login ||
      path == RouteNames.signup ||
      path == RouteNames.forgotPassword ||
      path == RouteNames.rootDecider ||
      path.startsWith('/chef-registration') ||
      path == RouteNames.chefRejection;
}

String? _sessionAwareRedirect(String path) {
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null && session.isExpired && path != RouteNames.login && path != RouteNames.splash) {
    return RouteNames.login;
  }
  return null;
}

String? _authRedirect(UserEntity? user, String path) {
  final sessionRedirect = _sessionAwareRedirect(path);
  if (sessionRedirect != null) return sessionRedirect;

  if (user == null || user.role == null) {
    if (_isPublicPath(path)) return null;
    return RouteNames.login;
  }

  if (user.isBlocked) {
    if (path == RouteNames.accountSuspended || path == RouteNames.chefBlocked) return null;
    return RouteNames.accountSuspended;
  }

  // Legacy route: never trap cooks on the full-screen rejection page.
  if (path == RouteNames.chefRejection && user.isChef) {
    return RouteNames.chefHome;
  }

  if (user.isChefRejected) {
    // Same navigation freedom as pending: stay under /chef/* (shell locks main tabs in ChefShell).
    if (path.startsWith('/chef-registration')) return null;
    if (path == RouteNames.cookPending) return RouteNames.chefHome;
    if (path.startsWith('/chef/')) return null;
    if (path.startsWith('/customer') || path.startsWith(RouteNames.adminHome)) {
      return RouteNames.chefHome;
    }
    if (_isPublicPath(path) || path == RouteNames.splash) return RouteNames.chefHome;
    return RouteNames.chefHome;
  }

  if (user.isChefPending) {
    // In-app limited shell: stay on /chef/* (Home locked via ChefShell), Chat + Profile + Documents.
    if (path.startsWith('/chef-registration')) return null;
    if (path == RouteNames.cookPending) return RouteNames.chefHome;
    if (path.startsWith('/chef/')) return null;
    if (path.startsWith('/customer') || path.startsWith(RouteNames.adminHome)) {
      return RouteNames.chefHome;
    }
    if (_isPublicPath(path) || path == RouteNames.splash) return RouteNames.chefHome;
    return RouteNames.chefHome;
  }

  if (user.isAdmin) {
    if (path == RouteNames.adminHome || path.startsWith('${RouteNames.adminHome}/')) return null;
    if (_isPublicPath(path) || path == RouteNames.splash) return RouteNames.adminHome;
    if (path.startsWith('/customer') || path.startsWith('/chef')) return RouteNames.adminHome;
    return null;
  }

  if (user.isCustomer) {
    if (_isPublicPath(path) || path == RouteNames.splash) return RouteNames.customerRoot;
    if (path.startsWith('/chef') && !path.startsWith('/chef-registration')) {
      return RouteNames.customerRoot;
    }
    if (path.startsWith(RouteNames.adminHome)) return RouteNames.customerRoot;
    if (path.startsWith('/customer')) return null;
    return RouteNames.customerRoot;
  }

  if (user.isChefApproved) {
    if (_isPublicPath(path) || path == RouteNames.splash) return RouteNames.chefHome;
    if (path.startsWith('/customer')) return RouteNames.chefHome;
    if (path.startsWith(RouteNames.adminHome)) return RouteNames.chefHome;
    if (path.startsWith('/chef')) return null;
    return RouteNames.chefHome;
  }

  if (_isPublicPath(path)) return null;
  return RouteNames.login;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);
  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = ref.read(authStateProvider);
      return auth.when(
        data: (user) {
          if (path == RouteNames.splash) return _splashTarget(user);
          return _authRedirect(user, path);
        },
        loading: () => null,
        error: (_, __) => path == RouteNames.splash ? null : RouteNames.login,
      );
    },
    routes: [
      GoRoute(path: RouteNames.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: RouteNames.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: RouteNames.roleSelection, builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: RouteNames.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: RouteNames.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: RouteNames.chefRegAccount, builder: (_, __) => const ChefRegAccountScreen()),
      GoRoute(path: RouteNames.chefRegDocuments, builder: (_, __) => const ChefRegDocumentsScreen()),
      GoRoute(path: RouteNames.chefRegSuccess, builder: (_, __) => const ChefRegSuccessScreen()),
      GoRoute(path: RouteNames.rootDecider, builder: (_, __) => const RootDeciderScreen()),
      GoRoute(path: RouteNames.chefRejection, builder: (_, __) => const ChefRejectionScreen()),
      GoRoute(path: RouteNames.cookPending, builder: (_, __) => const CookPendingScreen()),
      GoRoute(path: RouteNames.accountSuspended, builder: (_, __) => const BlockedScreen()),
      GoRoute(path: RouteNames.chefBlocked, builder: (_, __) => const BlockedScreen()),
      GoRoute(path: RouteNames.adminHome, builder: (_, __) => const AdminMainNavigationScreen()),
      GoRoute(path: RouteNames.customerRoot, builder: (_, __) => const CustomerMainNavigationScreen()),
      ShellRoute(
        builder: (context, state, child) => ChefShell(
          child: child,
          currentLocation: state.uri.path,
        ),
        routes: [
          GoRoute(path: RouteNames.chefHome, builder: (_, __) => const HomeScreen()),
          GoRoute(path: RouteNames.chefOrders, builder: (_, __) => const OrdersScreen()),
          GoRoute(path: RouteNames.chefMenu, builder: (_, __) => const MenuScreen()),
          GoRoute(path: RouteNames.chefReels, builder: (_, __) => const ReelsScreen()),
          GoRoute(path: RouteNames.chefChat, builder: (_, __) => const ChatScreen()),
          GoRoute(path: RouteNames.chefProfile, builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: RouteNames.chefNotifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: RouteNames.chefInspectionCall,
        builder: (context, state) {
          final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
          final channelName = extra?['channelName'] as String? ?? '';
          return InspectionCallScreen(channelName: channelName);
        },
      ),
      GoRoute(path: RouteNames.chefFrozen, builder: (_, __) => const FrozenScreen()),
    ],
  );
});

class ChefShell extends ConsumerWidget {
  final Widget child;
  final String currentLocation;

  const ChefShell({super.key, required this.child, required this.currentLocation});

  static bool _isLockedMainTab(String path) {
    return path.startsWith(RouteNames.chefHome) ||
        path.startsWith(RouteNames.chefOrders) ||
        path.startsWith(RouteNames.chefMenu) ||
        path.startsWith(RouteNames.chefReels);
  }

  int _index(String path) {
    if (path.startsWith(RouteNames.chefHome)) return 0;
    if (path.startsWith(RouteNames.chefOrders)) return 1;
    if (path.startsWith(RouteNames.chefMenu)) return 2;
    if (path.startsWith(RouteNames.chefReels)) return 3;
    if (path.startsWith(RouteNames.chefChat)) return 4;
    if (path.startsWith(RouteNames.chefProfile)) return 5;
    return 0;
  }

  static const _selectedColor = Color(0xFF7B5EA7);
  static const _unselectedColor = Color(0xFF6B7280);
  static const _navBg = Color(0xFFC4B0E8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final chefDoc = ref.watch(chefDocStreamProvider).valueOrNull;
    final currentIndex = _index(currentLocation);

    final pendingApproval = _chefAwaitingAccountApproval(user, chefDoc);
    final accountRejected = user?.isChef == true && (user?.isChefRejected ?? false);
    final docSuspended =
        user?.isChef == true &&
            (chefDoc?.approvalStatus?.toLowerCase() == 'approved') &&
            (chefDoc?.suspended ?? false);
    final limitedShell = pendingApproval || docSuspended || accountRejected;

    Widget shellChild = child;
    if (user != null && user.isChef && limitedShell && _isLockedMainTab(currentLocation)) {
      final title = pendingApproval
          ? 'Waiting for admin approval'
          : accountRejected
              ? 'Application not approved'
              : 'Account paused';
      final subtitle = pendingApproval
          ? 'You are inside the app, but Home, Orders, Menu and Reels stay locked until an admin approves your documents. '
              'Open Profile → Notifications for updates.'
          : accountRejected
              ? _rejectionSubtitle(user)
              : (chefDoc?.suspensionReason?.trim().isNotEmpty == true
                  ? chefDoc!.suspensionReason!.trim()
                  : 'A document needs attention. Upload a corrected file from Profile → Documents.');
      shellChild = ChefLimitedModeLayer(
        title: title,
        subtitle: subtitle,
        child: child,
      );
    }

    final body = user != null && user.isChef
        ? ChefPresenceWrapper(
            chefId: user.id,
            name: user.name,
            child: InspectionCallListener(
              enabled: !limitedShell,
              chefId: user.id,
              child: shellChild,
            ),
          )
        : shellChild;

    return Scaffold(
      body: body,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            if (limitedShell && i >= 0 && i <= 3) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    pendingApproval
                        ? 'Available after an admin approves your application.'
                        : accountRejected
                            ? 'Chat, Notifications, and Profile stay open. Upload new documents from Profile → Documents.'
                            : 'Available after the team clears your document review. Check Profile → Notifications.',
                  ),
                ),
              );
              return;
            }
            switch (i) {
              case 0:
                context.go(RouteNames.chefHome);
                break;
              case 1:
                context.go(RouteNames.chefOrders);
                break;
              case 2:
                context.go(RouteNames.chefMenu);
                break;
              case 3:
                context.go(RouteNames.chefReels);
                break;
              case 4:
                context.go(RouteNames.chefChat);
                break;
              case 5:
                context.go(RouteNames.chefProfile);
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: _selectedColor,
          unselectedItemColor: _unselectedColor,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_outlined), activeIcon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
            BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline_rounded), activeIcon: Icon(Icons.play_circle_rounded), label: 'Reels'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
