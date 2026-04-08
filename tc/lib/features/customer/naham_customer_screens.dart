// ============================================================
// NAHAM CUSTOMER APP — Purple theme, main nav, home, reels, orders, chat, profile
// ============================================================
//
// DEPRECATION NOTE:
// This file contains legacy composite customer screens and shared widgets.
// Current app entry uses modular screens in `features/customer/screens/*` plus
// selected classes from this file (Chat/Reels/Profile variants).
// Keep for backward compatibility; avoid adding new business logic here.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

// ==================== COLORS (from AppDesignSystem) ====================
import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/naham_app_header.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/core/widgets/naham_empty_screens.dart';
import 'package:naham_cook_app/features/reels/domain/entities/reel_entity.dart';
import 'package:naham_cook_app/features/customer/screens/customer_chat_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_order_details_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_search_screen.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/auth/domain/entities/user_entity.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/auth/screens/login_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_reels_feed.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/orders/domain/entities/order_entity.dart';
import 'package:naham_cook_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:naham_cook_app/features/orders/presentation/widgets/orders_stream_error_panel.dart';
import 'package:naham_cook_app/features/customer/widgets/pending_chef_response_countdown.dart';
import 'package:naham_cook_app/features/customer/widgets/skeleton_box.dart';
import 'package:naham_cook_app/features/customer/widgets/press_scale.dart';

class NahamCustomerColors {
  static const Color primary = AppDesignSystem.primary;
  static const Color primaryDark = AppDesignSystem.primaryDark;
  static const Color primaryLight = AppDesignSystem.primaryLight;
  static const Color background = AppDesignSystem.backgroundOffWhite;
  static const Color cardBg = AppDesignSystem.cardWhite;
  static const Color textDark = AppDesignSystem.textPrimary;
  static const Color textGrey = AppDesignSystem.textSecondary;
  static const Color star = Color(0xFFFFC107);
  static const Color categoryBg = Color(0xFFEDE9FE);
  static const Color bottomNavBg = AppDesignSystem.bottomNavBackground;
  static const Color bannerPink = Color(0xFFEC4899);
  static const Color cardGradientStart = Color(0xFFEDE9FE);
  static const Color cardGradientEnd = Color(0xFFF5F3FF);
  static const Color ratingBg = Color(0xFFFFF7ED);

  static const String logoAsset = AppDesignSystem.logoAsset;
}

/// Shared header for all customer screens: purple #9B7FD4, logo + "Naham" white.
/// When [title] is set (e.g. "Chat", "My Orders", "My Profile"), it is perfectly centered between left and right.
Widget nahamCustomerHeader({
  String? title,
  List<Widget>? actions,
}) {
  return Container(
    width: double.infinity,
    color: NahamCustomerColors.primary,
    padding: const EdgeInsets.only(
      top: 12,
      bottom: 12,
      left: 16,
      right: 16,
    ),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          // Left: logo + Naham (fixed width so right can match for balance)
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      NahamCustomerColors.logoAsset,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Naham',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Center: title (takes remaining space, text centered)
          Expanded(
            child: title != null
                ? Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                : const SizedBox.shrink(),
          ),
          // Right: actions (same width as left for perfect title centering)
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerRight,
              child: actions != null && actions.isNotEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
}

// ==================== MAIN NAVIGATION ====================
@Deprecated('Legacy customer navigation. Use CustomerMainNavigationScreen in screens/customer_main_navigation_screen.dart')
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; // Home, Reels, Orders, Chat, Profile
  int _cartCount = 0;

  void _addToCart() {
    setState(() {
      _cartCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      NahamCustomerHomeScreen(
          onAddToCart: _addToCart, cartCount: _cartCount),
      const NahamCustomerReelsScreen(),
      const NahamCustomerOrdersScreen(),
      const NahamCustomerChatScreen(),
      const NahamCustomerProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Nav bar order: Reels, Orders, Home, Chat, Profile — all items same style
  static const List<int> _navToScreenIndex = [1, 2, 0, 3, 4];

  Widget _buildBottomNav() {
    const labels = ['Reels', 'Orders', 'Home', 'Chat', 'Profile'];
    const icons = [
      (Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
      (Icons.home_outlined, Icons.home_rounded),
      (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
      (Icons.person_outline_rounded, Icons.person_rounded),
    ];
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: NahamCustomerColors.bottomNavBg,
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
          children: List.generate(5, (navIndex) {
            final screenIndex = _navToScreenIndex[navIndex];
            final isActive = _currentIndex == screenIndex;
            const activeColor = NahamCustomerColors.primaryDark;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = screenIndex),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isActive
                          ? activeColor.withOpacity(0.25)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? icons[navIndex].$2 : icons[navIndex].$1,
                      size: 24,
                      color: isActive
                          ? activeColor
                          : NahamCustomerColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[navIndex],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? activeColor
                          : NahamCustomerColors.textGrey,
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

// ==================== HOME SCREEN (Flutter) ====================
class NahamCustomerHomeScreen extends StatefulWidget {
  final VoidCallback onAddToCart;
  final int cartCount;

  const NahamCustomerHomeScreen({
    super.key,
    required this.onAddToCart,
    required this.cartCount,
  });

  @override
  State<NahamCustomerHomeScreen> createState() =>
      _NahamCustomerHomeScreenState();
}

class _NahamCustomerHomeScreenState extends State<NahamCustomerHomeScreen> {
  String _activeCategory = 'Northern';

  // Cuisine Regions (Figma)
  static const _categories = [
    'Northern',
    'Eastern',
    'Southern',
    'Najdi',
    'Western',
  ];

  // Local asset images for each region (top image in chips)
  static const Map<String, String> _categoryAssets = {
    'Northern': 'assets/images/nt.png',
    'Eastern': 'assets/images/es.png',
    'Southern': 'assets/images/so.png',
    'Najdi': 'assets/images/nj.png',
    'Western': 'assets/images/w.png',
  };

  static final _kitchens = [
    {
      'name': "Maria's Kitchen",
      'rating': 4.9,
      'img': '🍝',
      'dish': 'Creamy Truffle Pasta',
      'cuisine': 'Italian',
      'distance': '1.2 km',
      'time': '25-35 min',
      'badge': 'Most ordered',
    },
    {
      'name': 'Cook Qasim',
      'rating': 4.7,
      'img': '🍛',
      'dish': 'Kabsa Riyadh Style',
      'cuisine': 'Arabic cuisine',
      'distance': '0.8 km',
      'time': '20-30 min',
      'badge': null,
    },
    {
      'name': "Sarah's Home",
      'rating': 4.8,
      'img': '🥗',
      'dish': 'Quinoa Pomegranate Salad',
      'cuisine': 'Healthy',
      'distance': '2.1 km',
      'time': '30-40 min',
      'badge': 'New',
    },
    {
      'name': 'Um Khalid',
      'rating': 4.6,
      'img': '🍲',
      'dish': 'Traditional Jareesh',
      'cuisine': 'Kuwaiti',
      'distance': '1.5 km',
      'time': '35-45 min',
      'badge': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NahamCustomerColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    _buildCategoryChips(),
                    _buildPopularDishes(context),
                    _buildBanner(),
                    _buildFamousCooks(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return NahamAppHeader(
      cartCount: widget.cartCount,
      showSearchBar: false,
      onSearch: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const NahamCustomerSearchScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: _categories.map((c) {
          final isActive = _activeCategory == c;
          final assetPath = _categoryAssets[c];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _activeCategory = c),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? NahamCustomerColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: NahamCustomerColors.primary
                                  .withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (assetPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            assetPath,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: NahamCustomerColors.categoryBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Image.asset(
                                NahamCustomerColors.logoAsset,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: NahamCustomerColors.primary, size: 24),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        c,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : NahamCustomerColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPopularDishes(BuildContext context) {
    final dishes = [
      {'name': 'Gereesh', 'price': '20.0 SR'},
      {'name': 'Qrsan', 'price': '22.0 SR'},
      {'name': 'Mandy Laham', 'price': '90.0 SR'},
      {'name': 'Cream', 'price': '35.0 SR'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Dishes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: NahamCustomerColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
            children: dishes.map((d) => _PopularDishCard(
                  name: d['name']!,
                  price: d['price']!,
                  onAddToCart: widget.onAddToCart,
                )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NahamCustomerColors.primary,
            NahamCustomerColors.bannerPink,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s offer',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '20% off',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'On your first order 🎉',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
          const Text('🍽️', style: TextStyle(fontSize: 60)),
        ],
      ),
    );
  }

  Widget _buildFamousCooks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Famous Cooks',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: NahamCustomerColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ..._kitchens.map((k) => _KitchenCard(
                name: k['name'] as String,
                rating: k['rating'] as double,
                img: k['img'] as String,
                dish: k['dish'] as String,
                cuisine: k['cuisine'] as String,
                distance: k['distance'] as String,
                time: k['time'] as String,
                badge: k['badge'] as String?,
                onAddToCart: widget.onAddToCart,
              )),
        ],
      ),
    );
  }
}

class _PopularDishCard extends StatelessWidget {
  final String name;
  final String price;
  final VoidCallback onAddToCart;

  const _PopularDishCard({
    required this.name,
    required this.price,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NahamCustomerColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    NahamCustomerColors.cardGradientStart,
                    NahamCustomerColors.cardGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Image.asset(
                  NahamCustomerColors.logoAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, size: 32, color: NahamCustomerColors.primary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: NahamCustomerColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NahamCustomerColors.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: onAddToCart,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: NahamCustomerColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final String name;
  final double rating;
  final String img;
  final String dish;
  final String cuisine;
  final String distance;
  final String time;
  final String? badge;
  final VoidCallback onAddToCart;

  const _KitchenCard({
    required this.name,
    required this.rating,
    required this.img,
    required this.dish,
    required this.cuisine,
    required this.distance,
    required this.time,
    this.badge,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: NahamCustomerColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: NahamCustomerColors.categoryBg,
                  child: Text(
                    img,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: NahamCustomerColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: NahamCustomerColors.ratingBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⭐', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: NahamCustomerColors.star,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dish,
                        style: const TextStyle(
                          fontSize: 13,
                          color: NahamCustomerColors.textGrey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: NahamCustomerColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '📍 $distance',
                  style: const TextStyle(
                    fontSize: 13,
                    color: NahamCustomerColors.textGrey,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '⏱ $time',
                  style: const TextStyle(
                    fontSize: 13,
                    color: NahamCustomerColors.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAddToCart,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          NahamCustomerColors.primary,
                          NahamCustomerColors.primaryLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Add to cart +',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== REELS SCREEN (shared feed: customer_reels_feed.dart) ====================
class NahamCustomerReelsScreen extends StatelessWidget {
  const NahamCustomerReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NahamCustomerColors.background,
      body: Column(
        children: [
          nahamCustomerHeader(title: 'Reels'),
          Expanded(
            child: Container(
              color: Colors.black,
              child: const CustomerReelsFeed(accentColor: NahamCustomerColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  final ReelEntity reel;
  final String customerId;
  final VoidCallback onLike;
  final VoidCallback onChefTap;

  const _ReelCard({
    required this.reel,
    required this.customerId,
    required this.onLike,
    required this.onChefTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: NahamCustomerColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail or gradient placeholder (cards show even without video)
          AspectRatio(
            aspectRatio: 9 / 16,
            child: reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _reelPlaceholderGradient(),
                    ),
                  )
                : _reelPlaceholderGradient(),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reel.caption != null && reel.caption!.isNotEmpty)
                  Text(
                    reel.caption!,
                    style: const TextStyle(fontSize: 14, color: NahamCustomerColors.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (reel.caption != null && reel.caption!.isNotEmpty) const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onChefTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            reel.chefName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NahamCustomerColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PressScale(
                      enabled: true,
                      child: IconButton(
                        icon: Icon(
                          reel.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: reel.isLiked ? Colors.red : NahamCustomerColors.textGrey,
                          size: 26,
                        ),
                        onPressed: onLike,
                      ),
                    ),
                    if (reel.likesCount > 0)
                      Text(
                        '${reel.likesCount}',
                        style: const TextStyle(fontSize: 12, color: NahamCustomerColors.textGrey),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reelPlaceholderGradient() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NahamCustomerColors.primary.withValues(alpha: 0.25),
            NahamCustomerColors.primary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.play_circle_outline_rounded, size: 64, color: NahamCustomerColors.primary.withValues(alpha: 0.5)),
      ),
    );
  }
}

// ==================== ORDERS SCREEN ====================
class NahamCustomerOrdersScreen extends ConsumerStatefulWidget {
  const NahamCustomerOrdersScreen({super.key});

  @override
  ConsumerState<NahamCustomerOrdersScreen> createState() =>
      _NahamCustomerOrdersScreenState();
}

class _NahamCustomerOrdersScreenState extends ConsumerState<NahamCustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshActiveOrders() async {
    ref.invalidate(customerActiveOrdersStreamProvider);
    await ref.read(customerActiveOrdersStreamProvider.future);
  }

  Future<void> _refreshHistoryOrders() async {
    ref.invalidate(customerHistoryOrdersStreamProvider);
    await ref.read(customerHistoryOrdersStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NahamCustomerColors.background,
        body: Column(
          children: [
            nahamCustomerHeader(title: 'My Orders'),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: NahamCustomerColors.primaryDark,
                labelColor: NahamCustomerColors.primaryDark,
                unselectedLabelColor: NahamCustomerColors.textGrey,
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveOrders(),
                  _buildHistoryOrders(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    final async = ref.watch(customerActiveOrdersStreamProvider);
    return async.when(
      data: (orders) {
        if (orders.isEmpty) {
          return RefreshIndicator(
            color: NahamCustomerColors.primary,
            onRefresh: _refreshActiveOrders,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyOrdersScreen(
                      fullScreen: false,
                      title: 'No orders yet',
                      subtitle: 'Your active orders will appear here.',
                      fallbackIcon: Icons.shopping_bag_rounded,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: NahamCustomerColors.primary,
          onRefresh: _refreshActiveOrders,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(
              order: orders[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CustomerOrderDetailsScreen(orderId: orders[i].id),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonBox(height: 96, borderRadius: 16),
      ),
      error: (e, _) => Center(
        child: OrdersStreamErrorPanel(
          error: e,
          onRetry: () => ref.invalidate(customerActiveOrdersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildHistoryOrders() {
    final async = ref.watch(customerHistoryOrdersStreamProvider);
    return async.when(
      data: (orders) {
        if (orders.isEmpty) {
          return RefreshIndicator(
            color: NahamCustomerColors.primary,
            onRefresh: _refreshHistoryOrders,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyOrdersScreen(
                      fullScreen: false,
                      title: 'No orders yet',
                      subtitle: 'Completed or cancelled orders will appear here.',
                      fallbackIcon: Icons.shopping_bag_rounded,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: NahamCustomerColors.primary,
          onRefresh: _refreshHistoryOrders,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(
              order: orders[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CustomerOrderDetailsScreen(orderId: orders[i].id),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const SkeletonBox(height: 96, borderRadius: 16),
      ),
      error: (e, _) => Center(
        child: OrdersStreamErrorPanel(
          error: e,
          onRetry: () => ref.invalidate(customerHistoryOrdersStreamProvider),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderEntity order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  static Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return NahamCustomerColors.primary;
      case OrderStatus.accepted: case OrderStatus.preparing: case OrderStatus.ready: return Colors.green;
      case OrderStatus.completed: return Colors.green;
      case OrderStatus.rejected: case OrderStatus.cancelled: return Colors.red;
    }
  }

  static String _formatTime(DateTime d) {
    return '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final itemsSummary = order.items.isEmpty
        ? '—'
        : order.items.take(2).map((e) => e.dishName).join(', ');
    final timeStr = _formatTime(order.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NahamCustomerColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    OrderDbStatus.customerFacingLabel(
                      order.dbStatus,
                      cancelReason: order.cancelReason,
                      orderStatusFallback: order.status,
                    ),
                    style: TextStyle(color: _statusColor(order.status), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(timeStr, style: const TextStyle(color: NahamCustomerColors.textGrey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: NahamCustomerColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: NahamCustomerColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.chefName ?? 'Cook',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        itemsSummary,
                        style: const TextStyle(color: NahamCustomerColors.textGrey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.totalAmount.toStringAsFixed(0)} SAR',
                  style: const TextStyle(
                    color: NahamCustomerColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (order.status == OrderStatus.pending) ...[
              const SizedBox(height: 8),
              PendingChefResponseCountdown(
                createdAtUtc: order.createdAt,
                strongColor: NahamCustomerColors.primary,
                mutedColor: NahamCustomerColors.textGrey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== CHAT SCREEN ====================
// [NahamCustomerChatScreen] lives in `customer_chat_screen.dart` (single inbox + conversation UI).

// ==================== PROFILE SCREEN ====================
class NahamCustomerProfileScreen extends ConsumerWidget {
  const NahamCustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => Scaffold(
        backgroundColor: NahamCustomerColors.background,
        body: Center(child: CircularProgressIndicator(color: NahamCustomerColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: NahamCustomerColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: NahamCustomerColors.textGrey)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: NahamCustomerColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sign in to view your profile',
                    style: TextStyle(fontSize: 16, color: NahamCustomerColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
      backgroundColor: NahamCustomerColors.background,
      body: Column(
        children: [
          nahamCustomerHeader(title: 'My Profile'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(context, user),
                  const SizedBox(height: 20),
                  _buildProfileOptions(context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserEntity user) {
    final name = user.name;
    final email = user.email;
    final phone = user.phone;
    final photoUrl = user.profileImageUrl;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 30,
      ),
      decoration: const BoxDecoration(
        color: NahamCustomerColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          if (photoUrl != null && photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(45),
              child: Image.network(
                photoUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(),
              ),
            )
          else
            _avatarPlaceholder(),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (phone != null && phone.isNotEmpty)
            Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.person, size: 50, color: Colors.white),
    );
  }

  Widget _buildProfileOptions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _optionCard(
            context: context,
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Name, phone, photo',
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder<void>(
                pageBuilder: (context, animation, secondaryAnimation) => const NahamCustomerEditProfileScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
          _optionCard(
            context: context,
            icon: Icons.favorite_border,
            title: 'Favorites',
            subtitle: 'My favorite dishes',
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder<void>(
                pageBuilder: (context, animation, secondaryAnimation) => const NahamCustomerFavoritesScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NahamCustomerColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: NahamCustomerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: NahamCustomerColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: NahamCustomerColors.textGrey,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: NahamCustomerColors.textGrey),
          ],
        ),
      ),
    );
  }
}

// ==================== EDIT PROFILE SCREEN ====================
class NahamCustomerEditProfileScreen extends ConsumerStatefulWidget {
  const NahamCustomerEditProfileScreen({super.key});

  @override
  ConsumerState<NahamCustomerEditProfileScreen> createState() =>
      _NahamCustomerEditProfileScreenState();
}

class _NahamCustomerEditProfileScreenState
    extends ConsumerState<NahamCustomerEditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  String? _profileImageUrl;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).valueOrNull;
    _nameCtrl = TextEditingController(text: (user?.name ?? '').trim());
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _profileImageUrl = user?.profileImageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted || picked == null) return;
    final uid = ref.read(customerIdProvider);
    if (uid.isEmpty) return;
    setState(() => _loading = true);
    try {
      final url = await ref.read(customerFirebaseDataSourceProvider).uploadProfilePhoto(uid, File(picked.path));
      if (mounted) setState(() { _profileImageUrl = url; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = userFriendlyErrorMessage(e); });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    final uid = ref.read(customerIdProvider);
    if (uid.isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(customerFirebaseDataSourceProvider).updateCustomerProfile(
            uid,
            name: name,
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            profileImageUrl: _profileImageUrl,
          );
      if (mounted) {
        setState(() => _saving = false);
        ref.invalidate(authStateProvider);
        SnackbarHelper.success(context, 'Profile saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[EditProfile] Error: $e');
      if (mounted) setState(() { _saving = false; _error = userFriendlyErrorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NahamCustomerColors.background,
        appBar: AppBar(
          backgroundColor: NahamCustomerColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Edit Profile'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _pickPhoto,
                  child: Stack(
                    children: [
                      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: Image.network(
                            _profileImageUrl!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                          ),
                        )
                      else
                        _avatarPlaceholder(),
                      if (_loading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: NahamCustomerColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel('Name'),
              const SizedBox(height: 6),
              _buildField(_nameCtrl),
              const SizedBox(height: 16),
              _buildLabel('Phone'),
              const SizedBox(height: 6),
              _buildField(_phoneCtrl, keyboard: TextInputType.phone),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppDesignSystem.errorRed, fontSize: 12)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NahamCustomerColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: NahamCustomerColors.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(color: NahamCustomerColors.primary.withValues(alpha: 0.3), width: 3),
      ),
      child: const Icon(Icons.person, size: 50, color: NahamCustomerColors.primary),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NahamCustomerColors.textGrey),
    );
  }

  Widget _buildField(TextEditingController ctrl, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: NahamCustomerColors.textDark),
      decoration: InputDecoration(
        filled: true,
        fillColor: NahamCustomerColors.cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NahamCustomerColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ==================== FAVORITES SCREEN ====================
class NahamCustomerFavoritesScreen extends ConsumerWidget {
  const NahamCustomerFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIdsAsync = ref.watch(favoriteDishIdsStreamProvider);
    final dishesAsync = ref.watch(availableDishesStreamProvider);
    final chefsAsync = ref.watch(chefsForCustomerStreamProvider);
    final uid = ref.watch(customerIdProvider);

    return Scaffold(
      backgroundColor: NahamCustomerColors.background,
      appBar: AppBar(
        backgroundColor: NahamCustomerColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Favorites'),
      ),
      body: favIdsAsync.when(
          data: (ids) {
            if (ids.isEmpty) {
              return Center(
                child: NahamEmptyStateContent(
                  title: 'No favorites yet',
                  subtitle: 'Add dishes from Home to your favorites',
                  buttonLabel: 'OK',
                  fallbackIcon: Icons.favorite_border_rounded,
                ),
              );
            }
            return dishesAsync.when(
              data: (allDishes) {
                final dishes = ids
                    .map((id) {
                      final l = allDishes.where((d) => d.id == id).toList();
                      return l.isEmpty ? null : l.first;
                    })
                    .whereType<DishEntity>()
                    .toList();
                if (dishes.isEmpty) {
                  return Center(
                    child: NahamEmptyStateContent(
                      title: 'No favorites yet',
                      subtitle: 'Add dishes from Home to your favorites',
                      buttonLabel: 'OK',
                      fallbackIcon: Icons.favorite_border_rounded,
                    ),
                  );
                }
                return chefsAsync.when(
                  data: (chefs) {
                    final chefById = <String, String>{};
                    for (final c in chefs) {
                      final id = c.chefId;
                      if (id != null && id.isNotEmpty) chefById[id] = c.kitchenName ?? 'Cook';
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: dishes.length,
                      itemBuilder: (context, index) {
                        final dish = dishes[index];
                        final cookName = dish.chefId != null ? (chefById[dish.chefId!] ?? 'Cook') : 'Cook';
                        return Dismissible(
                          key: ValueKey(dish.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.errorRed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
                          ),
                          onDismissed: (_) {
                            if (uid.isNotEmpty) {
                              ref.read(customerFirebaseDataSourceProvider).removeFavorite(uid, dish.id);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: NahamCustomerColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                                      ? Image.network(dish.imageUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _dishPlaceholder())
                                      : _dishPlaceholder(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dish.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      Text(
                                        cookName,
                                        style: const TextStyle(color: NahamCustomerColors.textGrey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${dish.price.toStringAsFixed(0)} SAR',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: NahamCustomerColors.primary),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: NahamCustomerColors.primary)),
                  error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: NahamCustomerColors.textGrey))),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: NahamCustomerColors.primary)),
              error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: NahamCustomerColors.textGrey))),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: NahamCustomerColors.primary)),
          error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: NahamCustomerColors.textGrey))),
        ),
    );
  }

  static Widget _dishPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: NahamCustomerColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant_rounded, color: NahamCustomerColors.primary, size: 28),
    );
  }
}

// ==================== NOTIFICATIONS SCREEN ====================
class NahamCustomerNotificationsScreen extends ConsumerWidget {
  const NahamCustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(customerNotificationsStreamProvider);
    final uid = ref.watch(customerIdProvider);

    return Scaffold(
      backgroundColor: NahamCustomerColors.background,
      appBar: AppBar(
        backgroundColor: NahamCustomerColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
        actions: [
          if (uid.isNotEmpty)
            TextButton(
                onPressed: () async {
                  await ref.read(customerFirebaseDataSourceProvider).markAllNotificationsRead(uid);
                },
                child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: notificationsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: NahamEmptyStateContent(
                  title: 'No notifications yet',
                  subtitle: 'Order and message notifications will appear here',
                  buttonLabel: 'OK',
                  fallbackIcon: Icons.notifications_none_rounded,
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final n = list[index];
                final id = n['id'] as String? ?? '';
                final title = n['title'] as String? ?? '';
                final body = n['body'] as String? ?? '';
                final read = n['read'] as bool? ?? false;
                final createdAt = n['createdAt'] as String? ?? '';
                return InkWell(
                  onTap: uid.isNotEmpty && !read
                      ? () => ref.read(customerFirebaseDataSourceProvider).markNotificationRead(uid, id)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: read ? NahamCustomerColors.cardBg : NahamCustomerColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          read ? Icons.done_all_rounded : Icons.notifications_rounded,
                          color: NahamCustomerColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: NahamCustomerColors.textDark,
                                ),
                              ),
                              if (body.isNotEmpty)
                                Text(
                                  body,
                                  style: const TextStyle(color: NahamCustomerColors.textGrey, fontSize: 13),
                                ),
                              if (createdAt.isNotEmpty)
                                Text(
                                  createdAt,
                                  style: const TextStyle(color: NahamCustomerColors.textGrey, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: NahamCustomerColors.primary)),
          error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: NahamCustomerColors.textGrey))),
        ),
    );
  }
}

// ==================== WEB NAV BAR & HEADER (DESKTOP) ====================
class NahamCustomerWebNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const NahamCustomerWebNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Home', Icons.home_rounded),
      ('Reels', Icons.play_circle_rounded),
      ('Orders', Icons.receipt_long_rounded),
      ('Chat', Icons.chat_bubble_rounded),
      ('Profile', Icons.person_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: NahamCustomerColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  NahamCustomerColors.logoAsset,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Naham',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: List.generate(items.length, (index) {
              final isActive = index == currentIndex;
              final (label, icon) = items[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onItemSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: isActive
                              ? NahamCustomerColors.primaryDark
                              : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive
                                ? NahamCustomerColors.primaryDark
                                : Colors.white,
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Notifications',
                ),
                const SizedBox(width: 4),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: NahamCustomerColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NahamCustomerWebHeader extends StatelessWidget {
  const NahamCustomerWebHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NahamCustomerColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order home-cooked food with authentic flavors',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover the best home kitchens near you. Order in seconds and track your order in real time.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: NahamCustomerColors.textGrey,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search for a dish or kitchen...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: NahamCustomerColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text(
                  'Choose your location',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _NahamWebStatChip(value: '+200', label: 'Home kitchens'),
              SizedBox(width: 10),
              _NahamWebStatChip(value: '20-30 min', label: 'Avg. delivery'),
              SizedBox(width: 10),
              _NahamWebStatChip(value: '4.8', label: 'Avg. rating'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NahamWebStatChip extends StatelessWidget {
  final String value;
  final String label;

  const _NahamWebStatChip({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

