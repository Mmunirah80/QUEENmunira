import 'package:flutter/material.dart';

import '../../../core/theme/naham_theme.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'menu_screen.dart';
import 'reels_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Cook bottom nav: same style as Customer (purple #9B7EC8). Home, Orders, Menu, Reels, Chat, Profile. No cart.
class CookMainNavigationScreen extends StatefulWidget {
  const CookMainNavigationScreen({super.key});

  @override
  State<CookMainNavigationScreen> createState() => _CookMainNavigationScreenState();
}

class _CookMainNavigationScreenState extends State<CookMainNavigationScreen> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    OrdersScreen(),
    MenuScreen(),
    ReelsScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  static const _labels = ['Home', 'Orders', 'Menu', 'Reels', 'Chat', 'Profile'];
  static const _icons = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded),
    (Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
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
            children: List.generate(6, (i) {
              final isActive = _currentIndex == i;
              final activeColor = NahamTheme.secondary;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
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
                        isActive ? _icons[i].$2 : _icons[i].$1,
                        size: 24,
                        color: isActive ? activeColor : NahamTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? activeColor : NahamTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
