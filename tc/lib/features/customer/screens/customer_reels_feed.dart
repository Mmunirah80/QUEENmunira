// Shared vertical reels feed (video + like + chef + order). Used by shell + tab variants.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/location/pickup_distance.dart';
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
    if (reel.chefOrderingDisabled) {
      SnackbarHelper.error(context, 'Temporarily unavailable');
      return;
    }
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
      final cartItems = ref.read(cartProvider);
      final inCart = cartQuantityForDishChef(cartItems, dish.id, reel.chefId);
      if (inCart >= dish.remainingQuantity) {
        if (context.mounted) {
          SnackbarHelper.error(
            context,
            'Only ${dish.remainingQuantity} available from this cook',
          );
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
    final uid = ref.watch(customerIdProvider);
    if (uid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.login_rounded, size: 72, color: widget.accentColor.withValues(alpha: 0.6)),
              const SizedBox(height: 20),
              const Text(
                'Sign in to watch reels',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reels match your Home pickup location after you sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final pickupOrigin = ref.watch(customerPickupOriginProvider);
    if (pickupOrigin == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, size: 72, color: widget.accentColor.withValues(alpha: 0.6)),
              const SizedBox(height: 20),
              const Text(
                'Choose your location',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set your pickup point on Home (GPS or map) before we show reels for your area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final reelsAsync = ref.watch(customerReelsStreamProvider);

    return reelsAsync.when(
      data: (reels) {
        final locality = pickupOrigin.localityCity?.trim();
        final hasLocality = locality != null && locality.isNotEmpty;

        if (reels.isEmpty) {
          late final String title;
          late final String subtitle;
          late final IconData icon;
          if (!hasLocality) {
            icon = Icons.video_library_outlined;
            title = 'No reels in range yet';
            subtitle =
                'We filter reels by your pickup pin (city when known, otherwise within pickup distance). Try another location or check back later.';
          } else {
            icon = Icons.video_library_outlined;
            title = 'No reels yet';
            subtitle = 'No cooks have posted reels in $locality yet.';
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 72, color: widget.accentColor.withValues(alpha: 0.6)),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  Text(
                    hasLocality ? 'Reels near you' : 'Reels near your pickup',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLocality
                        ? 'From kitchens in $locality · same scope as Home'
                        : 'Same kitchens as Home · up to ${kFallbackBrowseRadiusWhenCityUnknownKm.toStringAsFixed(0)} km if city unknown',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (i) => setState(() => _activeIndex = i),
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  return ReelVideoPage(
                    key: ValueKey(reel.id),
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
              ),
            ),
          ],
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
