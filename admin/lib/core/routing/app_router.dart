import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/theme_constants.dart';
import '../../providers/auth_provider.dart';
import '../../screens/login_screen.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/user_management_screen.dart';
import '../../screens/orders_management_screen.dart';
import '../../screens/cash_management_screen.dart';
import '../../screens/hygiene_inspection_screen.dart';
import '../../screens/analytics_screen.dart';
import '../../screens/chat_support_screen.dart';
import '../../screens/pending_approval_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/video_call_screen.dart';
import '../../screens/inspection_result_screen.dart';
import '../../screens/chef_violation_history_screen.dart';
import '../../screens/chef_detail_screen.dart';
import '../../screens/support_conversation_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final path = state.uri.path;
      final isLogin = path == RouteNames.login;
      return authState.when(
        data: (user) {
          final loggedIn = user != null;
          if (!loggedIn && !isLogin) return RouteNames.login;
          if (loggedIn && isLogin) return RouteNames.dashboard;
          return null;
        },
        loading: () => null,
        error: (_, __) => isLogin ? null : RouteNames.login,
      );
    },
    routes: [
    GoRoute(
      path: RouteNames.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.root,
      redirect: (_, __) => RouteNames.dashboard,
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(
        currentPath: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(path: RouteNames.dashboard, builder: (_, __) => const DashboardScreen()),
        GoRoute(path: RouteNames.userManagement, builder: (_, __) => const UserManagementScreen()),
        GoRoute(path: RouteNames.orders, builder: (_, __) => const OrdersManagementScreen()),
        GoRoute(path: RouteNames.cashManagement, builder: (_, __) => const CashManagementScreen()),
        GoRoute(path: RouteNames.hygieneInspection, builder: (_, __) => const HygieneInspectionScreen()),
        GoRoute(path: RouteNames.analytics, builder: (_, __) => const AnalyticsScreen()),
        GoRoute(path: RouteNames.chatSupport, builder: (_, __) => const ChatSupportScreen()),
        GoRoute(path: RouteNames.pendingApproval, builder: (_, __) => const PendingApprovalScreen()),
        GoRoute(path: RouteNames.notifications, builder: (_, __) => const NotificationsScreen()),
      ],
    ),
    GoRoute(
      path: RouteNames.videoCall,
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
        final channelName = extra?['channelName'] as String?;
        final chefId = extra?['chefId'] as String?;
        final chefName = extra?['chefName'] as String?;
        return VideoCallScreen(
          channelName: channelName,
          chefId: chefId,
          chefName: chefName,
        );
      },
    ),
    GoRoute(
      path: RouteNames.inspectionResult,
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
        final chefId = extra?['chefId'] as String? ?? '';
        final chefName = extra?['chefName'] as String? ?? 'الطباخ';
        return InspectionResultScreen(chefId: chefId, chefName: chefName);
      },
    ),
    GoRoute(
      path: RouteNames.chefViolation,
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
        final chefId = extra?['chefId'] as String? ?? '';
        final chefName = extra?['chefName'] as String? ?? 'الطباخ';
        return ChefViolationHistoryScreen(chefId: chefId, chefName: chefName);
      },
    ),
    GoRoute(
      path: RouteNames.chefDetail,
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
        final chefId = extra?['chefId'] as String? ?? '';
        return ChefDetailScreen(chefId: chefId);
      },
    ),
    GoRoute(
      path: RouteNames.supportConversation,
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map<dynamic, dynamic> : null;
        final id = extra?['conversationId'] as String? ?? '';
        final name = extra?['participantName'] as String? ?? 'محادثة';
        return SupportConversationScreen(conversationId: id, participantName: name);
      },
    ),
  ],
  );
});


class AdminShell extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AdminShell({required this.currentPath, required this.child, super.key});

  int _index(String path) {
    if (path.startsWith(RouteNames.dashboard)) return 0;
    if (path.startsWith(RouteNames.userManagement)) return 1;
    if (path.startsWith(RouteNames.orders)) return 2;
    if (path.startsWith(RouteNames.cashManagement)) return 3;
    if (path.startsWith(RouteNames.pendingApproval)) return 4;
    if (path.startsWith(RouteNames.notifications)) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _index(currentPath);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ThemeConstants.bottomNavBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ThemeConstants.navBarBorderRadiusTop)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(ThemeConstants.navBarShadowOpacity),
              blurRadius: ThemeConstants.navBarShadowBlur,
              offset: Offset(0, ThemeConstants.navBarShadowOffsetY),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            switch (i) {
              case 0:
                context.go(RouteNames.dashboard);
                break;
              case 1:
                context.go(RouteNames.userManagement);
                break;
              case 2:
                context.go(RouteNames.orders);
                break;
              case 3:
                context.go(RouteNames.cashManagement);
                break;
              case 4:
                context.go(RouteNames.pendingApproval);
                break;
              case 5:
                context.go(RouteNames.notifications);
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: ThemeConstants.secondary,
          unselectedItemColor: ThemeConstants.textSecondary,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'لوحة التحكم'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people_rounded), label: 'المستخدمين'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long_rounded), label: 'الطلبات'),
            BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), activeIcon: Icon(Icons.payments_rounded), label: 'النقد'),
            BottomNavigationBarItem(icon: Icon(Icons.how_to_reg_outlined), activeIcon: Icon(Icons.how_to_reg_rounded), label: 'الموافقات'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications_rounded), label: 'الإشعارات'),
          ],
        ),
      ),
    );
  }
}
