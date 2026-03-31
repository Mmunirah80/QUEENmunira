// Shared vertical reels feed (video + like + chef + order). Used by shell + tab variants.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/customer/screens/chef_profile_screen.dart';
import 'package:naham_cook_app/features/customer/screens/reel_video_page.dart';
import 'package:naham_cook_app/features/menu/data/datasources/menu_supabase_datasource.dart';
import 'package:naham_cook_app/features/reels/domain/entities/reel_entity.dart';

class CustomerReelsFeed extends ConsumerStatefulWidget {
  const CustomerReelsFeed({
    super.key,
    required this.accentColor,
  });

  final Color accentColor;

  @override
  ConsumerState<CustomerReelsFeed> createState() => _CustomerReelsFeedState();
}

class _CustomerReelsFeedState extends ConsumerState<CustomerReelsFeed> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addReelDishToCart(BuildContext context, ReelEntity reel) async {
    final dishId = reel.dishId;
    if (dishId == null || dishId.isEmpty) return;
    final uid = ref.read(customerIdProvider);
    if (uid.isEmpty) {
      SnackbarHelper.error(context, 'Please sign in to order');
      return;
    }
    try {
      final ds = MenuSupabaseDataSource(chefId: reel.chefId);
      final dish = await ds.getDishById(dishId);
      if (!dish.isAvailable || dish.remainingQuantity <= 0) {
        if (context.mounted) {
          SnackbarHelper.error(context, 'This dish is unavailable right now');
        }
        return;
      }
      ref.read(cartProvider.notifier).add(dish, reel.chefId, reel.chefName);
      if (context.mounted) {
        SnackbarHelper.success(context, '${dish.name} added to cart');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.error(
          context,
          userFriendlyErrorMessage(
            e,
            fallback: 'Could not add dish. Check connection or permissions.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reelsAsync = ref.watch(customerReelsStreamProvider);

    return reelsAsync.when(
      data: (reels) {
        if (reels.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined, size: 72, color: widget.accentColor.withValues(alpha: 0.6)),
                const SizedBox(height: 20),
                const Text(
                  'No reels yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Discover cook dishes in short videos when reels are added.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          );
        }
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: reels.length,
          onPageChanged: (i) => setState(() => _activeIndex = i),
          itemBuilder: (context, index) {
            final reel = reels[index];
            return ReelVideoPage(
              reel: reel,
              isActive: index == _activeIndex,
              onTapChef: (chefId) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChefProfileScreen(chefId: chefId),
                  ),
                );
              },
              onOrderDish: _addReelDishToCart,
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: widget.accentColor)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error: ${userFriendlyErrorMessage(e)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(customerReelsStreamProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
