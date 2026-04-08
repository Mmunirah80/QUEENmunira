// ============================================================
// Customer main navigation — 5 tabs (IndexedStack order):
// Home, Reels, Chat, Orders, Profile
// Home reads from Supabase (menu_items, chef_profiles) via providers.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/theme/naham_theme.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/customer_home_screen.dart' show NahamCustomerHomeScreen;
import 'package:naham_cook_app/features/customer/screens/customer_chat_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_orders_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_profile_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_reels_screen.dart';

/// Customer bottom nav: Home, Reels, Orders, Chat, Profile.
class CustomerMainNavigationScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final List<String> newlyPlacedOrderIds;

  const CustomerMainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.newlyPlacedOrderIds = const <String>[],
  });

  @override
  ConsumerState<CustomerMainNavigationScreen> createState() => _CustomerMainNavigationScreenState();
}

class _CustomerMainNavigationScreenState extends ConsumerState<CustomerMainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    // Pickup is not restored from disk here — [customerPickupOriginProvider] starts null until the
    // customer confirms GPS/map on Home (see CustomerPickupStorage.save on confirm only).
  }

  @override
  Widget build(BuildContext context) {
    // Chat before Orders so customers see messaging next to Reels (entry from Orders still works).
    final screens = <Widget>[
      const NahamCustomerHomeScreen(),
      const NahamCustomerReelsScreen(),
      const NahamCustomerChatScreen(),
      CustomerOrdersScreen(highlightedOrderIds: widget.newlyPlacedOrderIds),
      const NahamCustomerProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const labels = ['Home', 'Reels', 'Chat', 'Orders', 'Profile'];
    const icons = [
      (Icons.home_outlined, Icons.home_rounded),
      (Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
      (Icons.person_outline_rounded, Icons.person_rounded),
    ];
    final activeColor = NahamTheme.secondary;
    final unselectedColor = NahamTheme.textSecondary;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: NahamTheme.bottomNavBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            final isActive = _currentIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive ? activeColor.withOpacity(0.25) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? icons[index].$2 : icons[index].$1,
                      size: 24,
                      color: isActive ? activeColor : unselectedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? activeColor : unselectedColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OrdersPlaceholder extends StatelessWidget {
  const _OrdersPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Orders - Coming Soon',
          style: TextStyle(
            fontSize: 18,
            color: AppDesignSystem.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChatPlaceholder extends StatelessWidget {
  const _ChatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 72, color: AppDesignSystem.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 20),
            Text(
              'Chat – Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Message cooks and support will be available soon.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppDesignSystem.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
