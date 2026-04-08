import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/admin_providers.dart';
import 'admin_dashboard_screen.dart';
import 'admin_monitor_chats_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reels_screen.dart';
import 'admin_users_hub_screen.dart';

class AdminMainNavigationScreen extends ConsumerStatefulWidget {
  const AdminMainNavigationScreen({super.key});

  @override
  ConsumerState<AdminMainNavigationScreen> createState() => _AdminMainNavigationScreenState();
}

class _AdminMainNavigationScreenState extends ConsumerState<AdminMainNavigationScreen> {
  static final _screens = <Widget>[
    const AdminDashboardScreen(),
    const AdminUsersHubScreen(),
    const AdminOrdersScreen(),
    const AdminSupportChatsScreen(),
    const AdminReelsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(adminBottomNavIndexProvider).clamp(0, _screens.length - 1);

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: IndexedStack(
        index: index,
        children: _screens,
      ),
      bottomNavigationBar: Material(
        elevation: 10,
        shadowColor: scheme.shadow.withValues(alpha: 0.14),
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: scheme.primaryContainer.withValues(alpha: 0.75),
            labelTextStyle: WidgetStateProperty.resolveWith((s) {
              final selected = s.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((s) {
              final selected = s.contains(WidgetState.selected);
              return IconThemeData(
                size: 24,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: index,
            height: 76,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: scheme.primaryContainer.withValues(alpha: 0.75),
            surfaceTintColor: Colors.transparent,
            onDestinationSelected: (value) {
              ref.read(adminBottomNavIndexProvider.notifier).state = value;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library_rounded),
                label: 'Reels',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
