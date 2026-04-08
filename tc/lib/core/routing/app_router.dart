import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/screens/admin_main_navigation_screen.dart';
import '../../features/admin/screens/admin_user_detail_screen.dart';
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
import '../../features/cook/screens/documents_screen.dart';
import '../../features/cook/screens/chef_compliance_history_screen.dart';
import '../../features/cook/screens/chef_inspection_live_screen.dart';
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
import 'go_router_redirect_policy.dart';

/// Root [Navigator] key for dialogs/overlays.
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifies [GoRouter] when [authStateProvider] changes so redirects re-run.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (_, __) => notifyListeners());
    _ref.listen<AsyncValue<ChefDocModel?>>(chefDocStreamProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final goRouterRefreshProvider = Provider<GoRouterRefreshNotifier>((ref) {
  return GoRouterRefreshNotifier(ref);
});

/// Chef shell: [ChefAccessLevel.partialAccess] locks main tabs; moderation [ChefDocModel.suspended] locks;
/// [documents_operational_ok] is enforced for orders / online (see Home).

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = ref.read(authStateProvider);
      return auth.when(
        data: (user) {
          if (path == RouteNames.splash) {
            final session = Supabase.instance.client.auth.currentSession;
            final hasValid = session != null && !session.isExpired;
            final doc = ref.read(chefDocStreamProvider).valueOrNull;
            final splashTarget = computeSplashTarget(
              hasValidSession: hasValid,
              user: user,
              chefDoc: doc,
            );
            if (kDebugMode && splashTarget != null) {
              debugPrint('[ROUTER] redirect splash -> $splashTarget');
            }
            return splashTarget;
          }
          final doc = ref.read(chefDocStreamProvider).valueOrNull;
          final frozen = computeChefFrozenRedirect(user: user, chefDoc: doc, path: path);
          if (frozen != null) {
            if (kDebugMode) debugPrint('[ROUTER] redirect frozen $path -> $frozen');
            return frozen;
          }
          final session = Supabase.instance.client.auth.currentSession;
          final expired = session != null && session.isExpired;
          final authRedirect = computeAuthRedirect(
            user: user,
            path: path,
            sessionIsExpired: expired,
          );
          if (kDebugMode && authRedirect != null && authRedirect != path) {
            debugPrint('[ROUTER] redirect $path -> $authRedirect role=${user?.role}');
          }
          return authRedirect;
        },
        loading: () => null,
        error: (err, st) {
          if (kDebugMode) {
            debugPrint('[ROUTER] authState error -> login: $err\n$st');
          }
          return path == RouteNames.splash ? null : RouteNames.login;
        },
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
      GoRoute(
        path: RouteNames.chefVerificationDocuments,
        builder: (_, __) => const DocumentsScreen(),
      ),
      GoRoute(path: RouteNames.accountSuspended, builder: (_, __) => const BlockedScreen()),
      GoRoute(path: RouteNames.chefBlocked, builder: (_, __) => const BlockedScreen()),
      GoRoute(path: RouteNames.adminHome, builder: (_, __) => const AdminMainNavigationScreen()),
      GoRoute(
        path: '${RouteNames.adminHome}/user/:userId',
        builder: (context, state) {
          final id = state.pathParameters['userId'] ?? '';
          return AdminUserDetailScreen(userId: id);
        },
      ),
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
          final callId = extra?['callId'] as String? ?? '';
          return ChefInspectionLiveScreen(callId: callId, channelName: channelName);
        },
      ),
      GoRoute(
        path: RouteNames.chefComplianceHistory,
        builder: (_, __) => const ChefComplianceHistoryScreen(),
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

    final partial = user?.isChef == true &&
        (user?.isChefPartialAccess == true ||
            (chefDoc?.accessLevel ?? '').toLowerCase() == 'partial_access');
    final docSuspended = user?.isChef == true && (chefDoc?.suspended ?? false);
    final limitedShell = partial || docSuspended;

    Widget shellChild = child;
    if (user != null && user.isChef && limitedShell && _isLockedMainTab(currentLocation)) {
      final title = docSuspended ? 'Account paused' : 'Waiting for admin approval';
      final subtitle = docSuspended
          ? (chefDoc?.suspensionReason?.trim().isNotEmpty == true
              ? chefDoc!.suspensionReason!.trim()
              : 'A document needs attention. Upload a corrected file from Profile → Documents.')
          : 'You are inside the app, but Home, Orders, Menu and Reels stay locked until an admin approves your documents. '
              'Open Profile → Notifications for updates.';
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
                    docSuspended
                        ? 'Available after the team clears your document review. Check Profile → Notifications.'
                        : 'Available after an admin approves your application.',
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
