// ============================================================
// CUSTOMER HOME — Browse dishes (Supabase menu_items), chefs (chef_profiles).
// Categories, grid, Kitchens & Chefs, pull to refresh, add to cart with snackbar.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/core/widgets/snackbar_helper.dart';
import 'package:naham_cook_app/features/customer/widgets/skeleton_box.dart';
import 'package:naham_cook_app/features/customer/widgets/press_scale.dart';
import 'package:naham_cook_app/features/menu/domain/entities/dish_entity.dart';
import 'package:naham_cook_app/features/customer/data/customer_pickup_storage.dart';
import 'package:naham_cook_app/features/customer/presentation/providers/customer_providers.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';
import 'package:naham_cook_app/features/customer/screens/customer_search_screen.dart';
import 'package:naham_cook_app/features/customer/screens/customer_cart_screen.dart';
import 'package:naham_cook_app/features/customer/screens/chef_profile_screen.dart';
import 'package:naham_cook_app/features/customer/naham_customer_screens.dart' show NahamCustomerNotificationsScreen;
import 'package:latlong2/latlong.dart';
import 'package:naham_cook_app/core/location/customer_location_service.dart';
import 'package:naham_cook_app/core/location/pickup_distance.dart';
import 'package:naham_cook_app/features/customer/screens/map_pin_picker_screen.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class NahamCustomerHomeScreen extends ConsumerStatefulWidget {
  const NahamCustomerHomeScreen({super.key});

  @override
  ConsumerState<NahamCustomerHomeScreen> createState() => _NahamCustomerHomeScreenState();
}

/// Fixed category chips: images for Najdi/Northern/Eastern/Southern, icons for All/Sweets/Other.
const _categoryChips = ['All', 'Najdi', 'Northern', 'Eastern', 'Southern', 'Sweets', 'Other'];
const _categoryImages = <String, String>{
  'Najdi': 'assets/images/nj.png',
  'Northern': 'assets/images/nt.png',
  'Eastern': 'assets/images/es.png',
  'Southern': 'assets/images/so.png',
};
const _categoryIcons = <String, IconData>{
  'All': Icons.restaurant_menu,
  'Najdi': Icons.rice_bowl,
  'Northern': Icons.kebab_dining,
  'Eastern': Icons.set_meal,
  'Southern': Icons.soup_kitchen,
  'Sweets': Icons.cake,
  'Other': Icons.fastfood,
};

class _NahamCustomerHomeScreenState extends ConsumerState<NahamCustomerHomeScreen> with SingleTickerProviderStateMixin {
  String _activeCategory = 'All';

  late final AnimationController _dishFadeController;
  String _dishFadeSignature = '';
  int _dishFadeTotal = 0;

  @override
  void initState() {
    super.initState();
    _dishFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _dishFadeController.dispose();
    super.dispose();
  }

  void _ensureDishFadeAnimation({required int totalCount}) {
    if (!mounted) return;
    _dishFadeTotal = totalCount;
    if (totalCount <= 0) return;
    final signature = '$_activeCategory:$totalCount';
    if (_dishFadeSignature == signature) return;
    _dishFadeSignature = signature;
    final totalMs = 300 + 50 * (totalCount - 1);
    _dishFadeController.duration = Duration(milliseconds: totalMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dishFadeController.forward(from: 0);
    });
  }

  Animation<double> _dishCardFadeAnimation({required int index, required int totalCount}) {
    if (totalCount <= 0) return const AlwaysStoppedAnimation<double>(0);
    final totalMs = 300 + 50 * (totalCount - 1);
    final startMs = 50 * index;
    final endMs = startMs + 300;
    final start = startMs / totalMs;
    final end = (endMs / totalMs).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _dishFadeController,
      curve: Interval(start.clamp(0.0, 1.0), end, curve: Curves.easeOut),
    );
  }

  Route<void> _fadeRoute(Widget target) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => target,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetTween,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(availableDishesStreamProvider);
    final chefsAsync = ref.watch(chefsForCustomerStreamProvider);
    final cartCount = ref.watch(cartCountProvider);
    final notifications = ref.watch(customerNotificationsStreamProvider).valueOrNull ?? [];
    final unreadCount = notifications.where((n) => (n['is_read'] as bool? ?? false) == false).length;
    final pickupOrigin = ref.watch(customerPickupOriginProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(context, cartCount, unreadCount, pickupOrigin),
          _buildLocationHeader(context, pickupOrigin),
          if (pickupOrigin == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _C.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: _C.primary, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Allow location or pick on map',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pickup only — we sort cooks by distance (up to ${kMaxPickupRadiusKm.toStringAsFixed(0)} km).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: _C.textSub),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => _showLocationBottomSheet(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Set pickup point'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
                    child: dishesAsync.when(
              data: (dishes) {
                return chefsAsync.when(
                  data: (chefs) {
                    final sorted = buildPickupSortedChefs(
                      chefs,
                      pickupOrigin.latitude,
                      pickupOrigin.longitude,
                    );
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(availableDishesStreamProvider);
                        ref.invalidate(chefsForCustomerStreamProvider);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCategoryChips(),
                            _buildDishesSection(context, dishes, sorted),
                            _buildChefsSection(context, sorted),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                            children: const [
                              SkeletonBox(height: 170, borderRadius: 16),
                              SkeletonBox(height: 170, borderRadius: 16),
                              SkeletonBox(height: 170, borderRadius: 16),
                              SkeletonBox(height: 170, borderRadius: 16),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, __) => const SkeletonBox(width: 160, height: 120, borderRadius: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  error: (e, _) => Center(child: Text('Error: ${userFriendlyErrorMessage(e)}', style: const TextStyle(color: AppDesignSystem.errorRed))),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: const [
                    SkeletonBox(height: 180, borderRadius: 16),
                    SizedBox(height: 12),
                    SkeletonBox(height: 180, borderRadius: 16),
                  ],
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int cartCount,
    int unreadCount,
    CustomerPickupOrigin? pickupOrigin,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _C.primary,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              AppDesignSystem.logoAsset,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 10),
            const Text('Naham', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (pickupOrigin == null) {
                  SnackbarHelper.error(
                    context,
                    'Set your pickup point first (GPS or map on Home).',
                  );
                  return;
                }
                Navigator.push(context, _fadeRoute(const NahamCustomerSearchScreen()));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: pickupOrigin == null ? 0.12 : 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: pickupOrigin == null ? 0.65 : 1),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: pickupOrigin == null ? 0.65 : 1),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                _fadeRoute(const NahamCustomerNotificationsScreen()),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                  if (unreadCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, _fadeRoute(const NahamCustomerCartScreen())),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
                  if (cartCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader(BuildContext context, CustomerPickupOrigin? origin) {
    final hasLocation = origin != null;
    final Widget textBlock;
    if (origin == null) {
      textBlock = Text(
        'Pickup point not set',
        style: TextStyle(fontSize: 13, color: _C.textSub, fontWeight: FontWeight.w500),
      );
    } else {
      final o = origin;
      textBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.headerLine,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.text,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${o.latitude.toStringAsFixed(4)}, ${o.longitude.toStringAsFixed(4)} · ${o.label}',
            style: TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_rounded, size: 18, color: _C.textSub),
          ),
          const SizedBox(width: 6),
          Expanded(child: textBlock),
          GestureDetector(
            onTap: () => _showLocationBottomSheet(context),
            child: Text(
              hasLocation ? 'Change' : 'Set',
              style: TextStyle(fontSize: 13, color: _C.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPickupPoint(BuildContext context, double lat, double lng) async {
    final geo = await CustomerLocationService.pickupGeocodeLabels(lat, lng);
    if (!context.mounted) return;
    final origin = CustomerPickupOrigin(
      latitude: lat,
      longitude: lng,
      label: geo.shortLabel,
      detailLabel: geo.detailLine,
    );
    ref.read(customerPickupOriginProvider.notifier).state = origin;
    ref.read(customerLocationProvider.notifier).state = CustomerLocationData(
      region: '',
      city: geo.detailLine.isNotEmpty ? geo.detailLine : geo.shortLabel,
      district: '',
    );
    ref.read(customerCitySelectionProvider.notifier).state = {
      'city': geo.detailLine.isNotEmpty ? geo.detailLine : geo.shortLabel,
      'district': '',
    };
    await CustomerPickupStorage.save(origin);
    if (!context.mounted) return;
    SnackbarHelper.success(context, 'Pickup point saved');
  }

  void _showLocationBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Pickup point', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.text)),
              const SizedBox(height: 8),
              Text(
                'Where you will collect your order. We show cooks within ${kMaxPickupRadiusKm.toStringAsFixed(0)} km.',
                style: TextStyle(fontSize: 13, color: _C.textSub),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final pos = await CustomerLocationService.tryCurrentPosition();
                  if (!context.mounted) return;
                  if (pos == null) {
                    SnackbarHelper.error(context, 'Location unavailable. Try the map picker.');
                    return;
                  }
                  await _applyPickupPoint(context, pos.latitude, pos.longitude);
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Use my current location'),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  const riyadh = LatLng(24.7136, 46.6753);
                  final existing = ref.read(customerPickupOriginProvider);
                  final initial = existing != null ? LatLng(existing.latitude, existing.longitude) : riyadh;
                  final picked = await Navigator.of(context, rootNavigator: true).push<LatLng>(
                    MaterialPageRoute<LatLng>(
                      fullscreenDialog: true,
                      builder: (_) => MapPinPickerScreen(initial: initial),
                    ),
                  );
                  if (!context.mounted || picked == null) return;
                  await _applyPickupPoint(context, picked.latitude, picked.longitude);
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('Pick on map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: _categoryChips.map((c) {
          final isActive = _activeCategory == c;
          final imagePath = _categoryImages[c];
          final icon = _categoryIcons[c] ?? Icons.restaurant_menu;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeCategory = c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? _C.primary : _C.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imagePath != null)
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isActive ? Colors.white.withValues(alpha: 0.3) : _C.surface,
                        backgroundImage: AssetImage(imagePath),
                      )
                    else
                      Icon(icon, size: 18, color: isActive ? Colors.white : _C.textSub),
                    const SizedBox(width: 8),
                    Text(
                      c,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? Colors.white : _C.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDishesSection(
    BuildContext context,
    List<DishEntity> dishes,
    List<ChefWithPickupDistance> sortedChefs,
  ) {
    if (dishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _C.primaryLight.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu_rounded, size: 44, color: _C.primaryLight),
              ),
              const SizedBox(height: 12),
              const Text(
                'No dishes to show right now',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'When cooks near your pickup point list dishes, they appear here. You can also try another map location.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.textSub),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _showLocationBottomSheet(context),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                label: const Text('Change pickup point'),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pickupChefIds = sortedChefs.map((e) => e.chef.chefId).whereType<String>().toSet();
    final nearbyDishes = pickupChefIds.isEmpty
        ? <DishEntity>[]
        : dishes.where((d) => d.chefId != null && pickupChefIds.contains(d.chefId)).toList();

    if (nearbyDishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _C.primaryLight.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu_rounded, size: 44, color: _C.primaryLight),
              ),
              const SizedBox(height: 12),
              Text(
                'No cooks (or dishes) within ${kMaxPickupRadiusKm.toStringAsFixed(0)} km of your pickup point.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _C.textSub, height: 1.35),
              ),
              const SizedBox(height: 8),
              const Text(
                'No cooks near you — try a second backup location on the map (another district or area).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _C.textSub, height: 1.35),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _showLocationBottomSheet(context),
                icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                label: const Text('Change pickup point'),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final favoriteIds = ref.watch(favoriteDishIdsStreamProvider).valueOrNull ?? [];
    final uid = ref.watch(customerIdProvider);
    final filtered = _activeCategory == 'All'
        ? nearbyDishes
        : nearbyDishes
            .where((d) => d.categories.any((cat) => cat.toLowerCase() == _activeCategory.toLowerCase()))
            .toList();
    final chefById = <String, ChefDocModel>{};
    final distanceByChefId = <String, String>{};
    for (final e in sortedChefs) {
      final id = e.chef.chefId;
      if (id != null && id.isNotEmpty) {
        chefById[id] = e.chef;
        if (e.distanceKm != null) {
          distanceByChefId[id] = formatPickupDistanceKm(e.distanceKm!);
        }
      }
    }
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _C.primaryLight.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restaurant_menu_rounded, size: 44, color: _C.primaryLight),
              ),
              const SizedBox(height: 12),
              Text('No dishes in this category', style: TextStyle(fontSize: 14, color: _C.textSub)),
            ],
          ),
        ),
      );
    }
    _ensureDishFadeAnimation(totalCount: filtered.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular Dishes Near You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
              return FadeTransition(
                opacity: _dishCardFadeAnimation(index: i, totalCount: filtered.length),
                child: DishCard(
                  dish: dish,
                  chefId: chefId,
                  chefName: chefName,
                  pickupDistanceLabel: chefId.isNotEmpty ? distanceByChefId[chefId] : null,
                  onAddToCart: () {
                    if (chefId.isEmpty) return;
                      final cartItems = ref.read(cartProvider);
                      final inCart = cartItems.where((e) => e.dishId == dish.id).fold<int>(0, (s, e) => s + e.quantity);
                      final remaining = dish.remainingQuantity;

                      print('[QuantityCheck][AddToCart] dishId=${dish.id} chefId=$chefId inCart=$inCart remaining=$remaining');

                      if (remaining <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('This dish is sold out'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (inCart >= remaining) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Only $remaining available from this cook'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      ref.read(cartProvider.notifier).add(dish, chefId, chefName);
                      if (context.mounted) {
                        SnackbarHelper.success(context, '${dish.name} added to cart');
                      }
                  },
                  onChefTap: chefId.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            _fadeRoute(ChefProfileScreen(chefId: chefId)),
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChefsSection(BuildContext context, List<ChefWithPickupDistance> sortedChefs) {
    if (sortedChefs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_off_outlined, size: 22, color: _C.primary.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No cooks near you',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'There are no cooks within pickup range of this point. Try a backup location on the map — for example another district, mall area, or where you usually meet people.',
              style: TextStyle(fontSize: 13, color: _C.textSub, height: 1.4, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showLocationBottomSheet(context),
              icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
              label: const Text('Change pickup point'),
              style: FilledButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cooks near you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text)),
          const SizedBox(height: 12),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sortedChefs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final entry = sortedChefs[i];
                final chef = entry.chef;
                final chefId = chef.chefId ?? '';
                final dist = entry.distanceKm != null ? formatPickupDistanceKm(entry.distanceKm!) : null;
                final rating = chef.ratingAvg;
                return ChefCard(
                  kitchenName: chef.kitchenName ?? 'Kitchen',
                  distanceLabel: dist,
                  rating: rating,
                  onTap: chefId.isEmpty
                      ? () {}
                      : () => Navigator.push(
                            context,
                            _fadeRoute(ChefProfileScreen(chefId: chefId)),
                          ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable dish card: image, name, price SAR, optional category chip, favorite heart, tappable cook name, Add to Cart.
class DishCard extends StatelessWidget {
  final DishEntity dish;
  final String chefId;
  final String chefName;
  final VoidCallback onAddToCart;
  final VoidCallback? onChefTap;
  /// Straight-line distance to this cook's kitchen from customer's pickup pin.
  final String? pickupDistanceLabel;
  /// When set, shows a small category badge below the price (e.g. "Najdi", "Sweets").
  final String? categoryLabel;
  /// Whether this dish is in the user's favorites (fills the heart icon).
  final bool isFavorite;
  /// When set, shows a heart icon top-right; tap toggles favorites table.
  final VoidCallback? onToggleFavorite;

  const DishCard({
    super.key,
    required this.dish,
    required this.chefId,
    required this.chefName,
    required this.onAddToCart,
    this.onChefTap,
    this.pickupDistanceLabel,
    this.categoryLabel,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = dish.id != null ? 'dish_${dish.id}' : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: (() {
                    final inner = dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                        ? Image.network(
                            dish.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder();
                    return heroTag != null ? Hero(tag: heroTag, child: inner) : inner;
                  })(),
                ),
                if (onToggleFavorite != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: PressScale(
                      enabled: true,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              size: 22,
                              color: isFavorite ? Colors.red : _C.textSub,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dish.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${dish.price.toStringAsFixed(0)} SAR',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary),
          ),
          if (dish.remainingQuantity <= 3) ...[
            const SizedBox(height: 4),
            Text(
              dish.remainingQuantity == 1 ? 'Last one!' : '${dish.remainingQuantity} left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dish.remainingQuantity == 1 ? Colors.red : Colors.orange,
              ),
            ),
          ],
          if (categoryLabel != null && categoryLabel!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _C.primaryLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                categoryLabel!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.primary),
              ),
            ),
          ],
          if (onChefTap != null)
            GestureDetector(
              onTap: onChefTap,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chefName,
                      style: TextStyle(fontSize: 12, color: _C.primary, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (pickupDistanceLabel != null && pickupDistanceLabel!.isNotEmpty)
                      Text(
                        pickupDistanceLabel!,
                        style: TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chefName, style: TextStyle(fontSize: 12, color: _C.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (pickupDistanceLabel != null && pickupDistanceLabel!.isNotEmpty)
                    Text(
                      pickupDistanceLabel!,
                      style: TextStyle(fontSize: 11, color: _C.textSub, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: PressScale(
              enabled: chefId.isNotEmpty,
              pressedScale: 0.95,
              duration: const Duration(milliseconds: 150),
              child: FilledButton(
                onPressed: chefId.isEmpty ? null : onAddToCart,
                style: FilledButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Add to Cart'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      color: _C.primaryLight.withValues(alpha: 0.3),
      child: const Icon(Icons.restaurant_rounded, size: 36, color: _C.primary),
    );
  }
}

class ChefCard extends StatelessWidget {
  final String kitchenName;
  final VoidCallback onTap;
  final String? distanceLabel;
  final double? rating;

  const ChefCard({
    super.key,
    required this.kitchenName,
    required this.onTap,
    this.distanceLabel,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.primaryLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: _C.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              kitchenName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (rating != null && rating! > 0) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade700),
                  Text(
                    rating!.toStringAsFixed(1),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.textSub),
                  ),
                ],
              ),
            ],
            if (distanceLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded, size: 12, color: _C.primary),
                  const SizedBox(width: 2),
                  Text(
                    distanceLabel!,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.primary),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Pin not set',
                style: TextStyle(fontSize: 10, color: _C.textSub, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
