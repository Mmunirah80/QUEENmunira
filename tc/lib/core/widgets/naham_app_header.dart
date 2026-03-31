import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Exact same header design for Customer and Cook: purple bg, logo + "Naham", search/cart/notification, location, search bar.
class NahamAppHeader extends StatelessWidget {
  final int cartCount;
  final String locationLabel;
  final String searchHint;
  final bool showSearchBar;
  final bool showCart;
  final VoidCallback? onSearch;
  final VoidCallback? onCart;
  final VoidCallback? onNotification;

  const NahamAppHeader({
    super.key,
    this.cartCount = 0,
    this.locationLabel = 'الرياض، حي الملقا',
    this.searchHint = 'ابحث عن وجبة أو مطبخ...',
    this.showSearchBar = true,
    this.showCart = true,
    this.onSearch,
    this.onCart,
    this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: AppDesignSystem.headerBackground,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      AppDesignSystem.logoAsset,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/logo.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        color: Colors.white,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: Colors.white70, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                    onPressed: onSearch ?? () {},
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      minimumSize: const Size(38, 38),
                    ),
                  ),
                  if (showCart) ...[
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                          onPressed: onCart ?? () {},
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            minimumSize: const Size(38, 38),
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                              child: Text(
                                cartCount > 99 ? '99+' : '$cartCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                        onPressed: onNotification ?? () {},
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          minimumSize: const Size(38, 38),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFFFF4444), shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                locationLabel,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
              ),
            ],
          ),
          if (showSearchBar) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('🔍', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
