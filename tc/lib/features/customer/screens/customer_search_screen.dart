// ============================================================
// CUSTOMER SEARCH — Search dishes by name or category (from availableDishesStreamProvider).
// Same DishCard style as home; empty state when no results.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/loading_widget.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/screens/customer_home_screen.dart';
import 'package:naham_cook_app/features/customer/screens/chef_profile_screen.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart' show pickupDistanceLabelsByChefId, pickupVisibleChefIds;

class _C {
  static const primary = AppDesignSystem.primary;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const textSub = AppDesignSystem.textSecondary;
}

class NahamCustomerSearchScreen extends ConsumerStatefulWidget {
  const NahamCustomerSearchScreen({super.key});

  @override
  ConsumerState<NahamCustomerSearchScreen> createState() => _NahamCustomerSearchScreenState();
}

class _NahamCustomerSearchScreenState extends ConsumerState<NahamCustomerSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(availableDishesStreamProvider);
    final chefsAsync = ref.watch(chefsForCustomerStreamProvider);
    final pickupOrigin = ref.watch(customerPickupOriginProvider);
    final favoriteIds = ref.watch(favoriteDishIdsStreamProvider).valueOrNull ?? [];
    final uid = ref.watch(customerIdProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        title: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TextField(
              controller: _queryController,
              style: const TextStyle(color: AppDesignSystem.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Search dishes or category...',
                hintStyle: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: pickupOrigin == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_rounded, size: 72, color: _C.primary.withValues(alpha: 0.85)),
                    const SizedBox(height: 16),
                    const Text(
                      'Set pickup point on Home first',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pickup only — use GPS or map on Home, then search dishes from nearby cooks.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: _C.textSub, height: 1.35),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            )
          : dishesAsync.when(
        data: (allDishes) {
          return chefsAsync.when(
            data: (chefs) {
              final chefById = <String, ChefDocModel>{};
              for (final c in chefs) {
                final id = c.chefId;
                if (id != null && id.isNotEmpty) chefById[id] = c;
              }
              final ids = pickupVisibleChefIds(
                chefs,
                pickupOrigin.latitude,
                pickupOrigin.longitude,
              );
              final scoped = allDishes.where((d) => d.chefId != null && ids.contains(d.chefId)).toList();
              final distByChef = pickupDistanceLabelsByChefId(
                chefs,
                pickupOrigin.latitude,
                pickupOrigin.longitude,
              );
              final filtered = _filter(scoped, _query, chefById);

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: _C.textSub),
                      const SizedBox(height: 16),
                      Text(
                        _query.isEmpty ? 'Start typing to search' : 'No results found',
                        style: const TextStyle(fontSize: 16, color: _C.textSub),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final dish = filtered[i];
                  final chefId = dish.chefId ?? '';
                  final chef = chefId.isNotEmpty ? chefById[chefId] : null;
                  final chefName = chef?.kitchenName ?? 'Kitchen';
                  return DishCard(
                    dish: dish,
                    chefId: chefId,
                    chefName: chefName,
                    pickupDistanceLabel: chefId.isNotEmpty ? distByChef[chefId] : null,
                    onAddToCart: () {
                      if (chefId.isNotEmpty) {
                        ref.read(cartProvider.notifier).add(dish, chefId, chefName);
                        if (context.mounted) {
                          SnackbarHelper.success(context, '${dish.name} added to cart');
                        }
                      }
                    },
                    onChefTap: chefId.isEmpty
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => ChefProfileScreen(chefId: chefId)),
                            ),
                    isFavorite: dish.id != null && favoriteIds.contains(dish.id),
                    onToggleFavorite: dish.id == null || uid == null || uid.isEmpty
                        ? null
                        : () {
                            final inFav = favoriteIds.contains(dish.id);
                            print('Fav toggle: uid=$uid, dish=${dish.id}, wasFav=$inFav');
                            if (inFav) {
                              ref.read(customerFirebaseDataSourceProvider).removeFavorite(uid, dish.id!);
                            } else {
                              ref.read(customerFirebaseDataSourceProvider).addFavorite(uid, dish.id!);
                            }
                            ref.invalidate(favoriteDishIdsStreamProvider);
                          },
                  );
                },
              );
            },
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: AppDesignSystem.errorRed)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => ref.invalidate(chefsForCustomerStreamProvider), child: const Text('Retry')),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: AppDesignSystem.errorRed)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(availableDishesStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DishEntity> _filter(List<DishEntity> dishes, String q, Map<String, ChefDocModel> chefById) {
    if (q.isEmpty) return dishes;
    final lower = q.toLowerCase();
    return dishes.where((d) {
      if (d.name.toLowerCase().contains(lower)) return true;
      for (final c in d.categories) {
        if (c.toLowerCase().contains(lower)) return true;
      }
      final chefId = d.chefId ?? '';
      if (chefId.isNotEmpty) {
        final chef = chefById[chefId];
        final kitchenName = chef?.kitchenName ?? '';
        if (kitchenName.toLowerCase().contains(lower)) return true;
      }
      return false;
    }).toList();
  }
}
