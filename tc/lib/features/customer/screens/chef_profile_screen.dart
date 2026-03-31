// ============================================================
// CHEF PROFILE (Customer view) — Header (avatar, kitchen_name, bio, online, city), tabs: Dishes | Reels.
// Dishes from chefDishesForCustomerStreamProvider; Reels from myReelsStreamProvider(chefId).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/loading_widget.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/customer/screens/customer_home_screen.dart';
import 'package:naham_cook_app/features/customer/screens/reel_video_page.dart';
import 'package:naham_cook_app/features/menu/data/datasources/menu_supabase_datasource.dart';
import 'package:naham_cook_app/features/reels/domain/entities/reel_entity.dart';
import 'package:naham_cook_app/features/reels/presentation/providers/reels_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class ChefProfileScreen extends ConsumerStatefulWidget {
  final String chefId;

  const ChefProfileScreen({super.key, required this.chefId});

  @override
  ConsumerState<ChefProfileScreen> createState() => _ChefProfileScreenState();
}

class _ChefProfileScreenState extends ConsumerState<ChefProfileScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(chefDishesForCustomerStreamProvider(widget.chefId));
    final chefsAsync = ref.watch(chefsForCustomerStreamProvider);
    final pickupOrigin = ref.watch(customerPickupOriginProvider);
    final favoriteIds = ref.watch(favoriteDishIdsStreamProvider).valueOrNull ?? [];
    final uid = ref.watch(customerIdProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: const Text('Cook'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Dishes'),
            Tab(text: 'Reels'),
          ],
        ),
      ),
      body: chefsAsync.when(
        data: (chefs) {
          ChefDocModel? chef;
          for (final c in chefs) {
            if (c.chefId == widget.chefId) {
              chef = c;
              break;
            }
          }
          final kitchenName = chef?.kitchenName ?? 'Kitchen';
          final pickupDistLabel = pickupOrigin != null && chef != null
              ? pickupDistanceLabelForChef(chef, pickupOrigin.latitude, pickupOrigin.longitude)
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChefHeader(
                kitchenName: kitchenName,
                bio: chef?.bio,
                isOnline: chef?.isOnline ?? false,
                kitchenCity: chef?.kitchenCity,
                kitchenLatitude: chef?.kitchenLatitude,
                kitchenLongitude: chef?.kitchenLongitude,
              ),
              Expanded(
                child: TabBarView(
            controller: _tabController,
            children: [
              _DishesTab(
                chefId: widget.chefId,
                chefName: kitchenName,
                dishesAsync: dishesAsync,
                hasPickupPoint: pickupOrigin != null,
                pickupDistanceLabel: pickupDistLabel,
                onAddToCart: (dish) {
                  ref.read(cartProvider.notifier).add(dish, widget.chefId, kitchenName);
                  if (mounted) {
                    SnackbarHelper.success(context, '${dish.name} added to cart');
                  }
                },
                favoriteDishIds: favoriteIds,
                customerId: uid,
                onToggleFavorite: (dishId) {
                  if (uid == null || uid.isEmpty) return;
                  final inFav = favoriteIds.contains(dishId);
                  print('Fav toggle: uid=$uid, dish=$dishId, wasFav=$inFav');
                  if (inFav) {
                    ref.read(customerFirebaseDataSourceProvider).removeFavorite(uid, dishId);
                  } else {
                    ref.read(customerFirebaseDataSourceProvider).addFavorite(uid, dishId);
                  }
                  ref.invalidate(favoriteDishIdsStreamProvider);
                },
              ),
              _ChefReelsGridTab(chefId: widget.chefId),
            ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: AppDesignSystem.errorRed))),
      ),
    );
  }
}

class _ChefHeader extends StatelessWidget {
  final String kitchenName;
  final String? bio;
  final bool isOnline;
  final String? kitchenCity;
  final double? kitchenLatitude;
  final double? kitchenLongitude;

  const _ChefHeader({
    required this.kitchenName,
    this.bio,
    required this.isOnline,
    this.kitchenCity,
    this.kitchenLatitude,
    this.kitchenLongitude,
  });

  Future<void> _openMaps() async {
    final lat = kitchenLatitude;
    final lng = kitchenLongitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLarge),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.primaryLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 40, color: _C.primary),
          ),
          const SizedBox(height: 12),
          Text(kitchenName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.text)),
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio!, style: TextStyle(fontSize: 14, color: _C.textSub), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : _C.textSub,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, color: _C.textSub)),
              if (kitchenCity != null && kitchenCity!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text('• ${kitchenCity!}', style: TextStyle(fontSize: 12, color: _C.textSub)),
              ],
            ],
          ),
          if (kitchenLatitude != null && kitchenLongitude != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openMaps,
              icon: const Icon(Icons.directions_rounded, size: 20),
              label: const Text('Open in Google Maps'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.primary,
                side: BorderSide(color: _C.primary.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pickup at this pin — no delivery',
              style: TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}

class _DishesTab extends StatelessWidget {
  final String chefId;
  final String chefName;
  final AsyncValue<List<DishEntity>> dishesAsync;
  final bool hasPickupPoint;
  final String? pickupDistanceLabel;
  final void Function(DishEntity dish) onAddToCart;
  final List<String> favoriteDishIds;
  final String? customerId;
  final void Function(String dishId) onToggleFavorite;

  const _DishesTab({
    required this.chefId,
    required this.chefName,
    required this.dishesAsync,
    required this.hasPickupPoint,
    this.pickupDistanceLabel,
    required this.onAddToCart,
    required this.favoriteDishIds,
    this.customerId,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPickupPoint) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 64, color: _C.primary.withValues(alpha: 0.75)),
              const SizedBox(height: 16),
              const Text(
                'Set pickup point on Home first',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.text),
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup only — choose your location with GPS or map, then come back to add dishes from this kitchen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _C.textSub, height: 1.35),
              ),
            ],
          ),
        ),
      );
    }
    return dishesAsync.when(
      data: (dishes) {
        if (dishes.isEmpty) {
          return const Center(
            child: Text('No dishes available', style: TextStyle(color: _C.textSub)),
          );
        }
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: dishes.length,
              itemBuilder: (_, i) {
                final dish = dishes[i];
                final categoryLabel = dish.categories.isNotEmpty ? dish.categories.first : 'Other';
                return DishCard(
                  dish: dish,
                  chefId: chefId,
                  chefName: chefName,
                  pickupDistanceLabel: pickupDistanceLabel,
                  onAddToCart: () => onAddToCart(dish),
                  onChefTap: null,
                  categoryLabel: categoryLabel,
                  isFavorite: dish.id != null && favoriteDishIds.contains(dish.id),
                  onToggleFavorite: dish.id != null && customerId != null && customerId!.isNotEmpty
                      ? () => onToggleFavorite(dish.id!)
                      : null,
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: AppDesignSystem.errorRed))),
    );
  }
}

class _ChefReelsGridTab extends ConsumerWidget {
  final String chefId;

  const _ChefReelsGridTab({required this.chefId});

  Future<void> _addReelDishToCart(WidgetRef ref, BuildContext context, ReelEntity reel) async {
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
        SnackbarHelper.error(context, userFriendlyErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReelsStreamProvider(chefId));
    return async.when(
      data: (reels) {
        if (reels.isEmpty) {
          return Center(
            child: Text('No reels yet', style: TextStyle(fontSize: 16, color: _C.textSub)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 9 / 16,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: reels.length,
          itemBuilder: (ctx, i) {
            final r = reels[i];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (pageCtx) => Scaffold(
                      backgroundColor: Colors.black,
                      body: Stack(
                        fit: StackFit.expand,
                        children: [
                          ReelVideoPage(
                            reel: r,
                            isActive: true,
                            onTapChef: (id) {
                              Navigator.of(pageCtx).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (__) => ChefProfileScreen(chefId: id),
                                ),
                              );
                            },
                            onOrderDish: (c, reel) => _addReelDishToCart(ref, c, reel),
                          ),
                          SafeArea(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.of(pageCtx).pop(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: r.thumbnailUrl != null && r.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        r.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: _C.primary.withValues(alpha: 0.15),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: _C.primary, size: 48),
                          ),
                        ),
                      )
                    : ColoredBox(
                        color: _C.primary.withValues(alpha: 0.15),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill_rounded, color: _C.primary, size: 48),
                        ),
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: LoadingWidget()),
      error: (e, _) => Center(
        child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: AppDesignSystem.errorRed)),
      ),
    );
  }
}
