import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cook/data/models/chef_doc_model.dart';
import '../../../menu/domain/entities/dish_entity.dart';
import '../../../orders/data/models/order_model.dart';
import '../../data/datasources/customer_firebase_datasource.dart';
import '../../data/datasources/customer_browse_supabase_datasource.dart';
import '../../data/datasources/customer_orders_supabase_datasource.dart';
import '../../data/datasources/customer_chat_supabase_datasource.dart';
import '../../data/datasources/customer_reels_supabase_datasource.dart';
import '../../data/models/cart_item_model.dart';
import '../../../reels/domain/entities/reel_entity.dart';

// ─── Data sources ────────────────────────────────────────────────────────
final customerFirebaseDataSourceProvider = Provider<CustomerFirebaseDataSource>((ref) {
  return CustomerFirebaseDataSource();
});

final customerBrowseDataSourceProvider = Provider<CustomerBrowseSupabaseDatasource>((ref) {
  return CustomerBrowseSupabaseDatasource();
});

final customerOrdersSupabaseDatasourceProvider = Provider<CustomerOrdersSupabaseDatasource>((ref) {
  return CustomerOrdersSupabaseDatasource();
});

final customerChatSupabaseDataSourceProvider = Provider<CustomerChatSupabaseDatasource>((ref) {
  return CustomerChatSupabaseDatasource();
});

final customerReelsSupabaseDatasourceProvider = Provider<CustomerReelsSupabaseDatasource>((ref) {
  return CustomerReelsSupabaseDatasource();
});

/// Customer id for orders/favorites/addresses: current auth user id, or empty string when not logged in.
final customerIdProvider = Provider<String>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.id ?? '';
});

/// Customer location (manual entry). Display: "Current Location: {district}, {city}" or fallback to region/city.
class CustomerLocationData {
  final String region;
  final String city;
  final String district;
  const CustomerLocationData({
    this.region = 'Riyadh',
    this.city = '',
    this.district = '',
  });
  String get displayText {
    if (district.isNotEmpty && city.isNotEmpty) return '$district, $city';
    if (city.isNotEmpty) return city;
    if (region.isNotEmpty) return region;
    return 'Riyadh';
  }
}

final customerLocationProvider = StateProvider<CustomerLocationData>((ref) {
  return const CustomerLocationData();
});

/// Simple in-memory city + district selection for the customer home screen.
/// Example shape: {'city': 'Riyadh', 'district': 'Al Olaya'} or null when not set.
final customerCitySelectionProvider = StateProvider<Map<String, String>?>((
  ref,
) {
  return null;
});

/// Customer pickup origin (GPS or map pin). Drives distance sorting on home.
class CustomerPickupOrigin {
  final double latitude;
  final double longitude;
  /// Short label (e.g. district + city).
  final String label;
  /// Longer line for header: area · city · region · country.
  final String detailLabel;

  const CustomerPickupOrigin({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.detailLabel = '',
  });

  /// Prefer [detailLabel] for the top bar when set.
  String get headerLine {
    final d = detailLabel.trim();
    if (d.isNotEmpty) return d;
    final l = label.trim();
    return l.isNotEmpty ? l : 'Pickup point';
  }
}

final customerPickupOriginProvider = StateProvider<CustomerPickupOrigin?>((ref) {
  return null;
});

// ─── Cart (in-memory) ────────────────────────────────────────────────────
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  CartNotifier() : super([]);

  void add(DishEntity dish, String chefId, String chefName) {
    final existing = state.indexWhere((e) => e.dishId == dish.id && e.chefId == chefId);
    if (existing >= 0) {
      final list = List<CartItemModel>.from(state);
      list[existing] = list[existing].copyWith(quantity: list[existing].quantity + 1);
      state = list;
    } else {
      state = [
        ...state,
        CartItemModel(
          dishId: dish.id,
          dishName: dish.name,
          chefId: chefId,
          chefName: chefName,
          price: dish.price,
          quantity: 1,
        ),
      ];
    }
  }

  void remove(String dishId, String chefId) {
    state = state.where((e) => !(e.dishId == dishId && e.chefId == chefId)).toList();
  }

  void updateQuantity(String dishId, String chefId, int quantity) {
    if (quantity <= 0) {
      remove(dishId, chefId);
      return;
    }
    final i = state.indexWhere((e) => e.dishId == dishId && e.chefId == chefId);
    if (i < 0) return;
    final list = List<CartItemModel>.from(state);
    list[i] = list[i].copyWith(quantity: quantity);
    state = list;
  }

  void clear() => state = [];
}

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (s, e) => s + e.quantity);
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold<double>(0, (s, e) => s + e.lineTotal);
});

// ─── Available dishes (Supabase realtime from menu_items) ─────────────
final availableDishesStreamProvider = StreamProvider<List<DishEntity>>((ref) {
  return ref.watch(customerBrowseDataSourceProvider).watchAvailableDishes();
});

final chefDishesForCustomerStreamProvider =
    StreamProvider.family<List<DishEntity>, String>((ref, chefId) {
  return ref.watch(customerBrowseDataSourceProvider).watchChefDishes(chefId);
});

// ─── Chefs (from chef_profiles) ───────────────────────────────────────
final chefsForCustomerStreamProvider = StreamProvider<List<ChefDocModel>>((ref) {
  return ref.watch(customerBrowseDataSourceProvider).watchAllChefs();
});

// ─── Customer orders (Supabase) ───────────────────────────────────────────
final customerOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  final customerId = ref.watch(customerIdProvider);
  if (kDebugMode) {
    debugPrint('[customerOrdersStreamProvider] customerId=$customerId');
  }
  if (customerId.isEmpty) {
    if (kDebugMode) {
      debugPrint('[customerOrdersStreamProvider] customerId empty — no orders stream');
    }
    return Stream.value(const <OrderModel>[]);
  }
  return ref.watch(customerOrdersSupabaseDatasourceProvider).watchOrdersByCustomerId(customerId);
});

final customerOrderByIdStreamProvider = StreamProvider.family<OrderModel?, String>((ref, orderId) {
  return ref.watch(customerOrdersSupabaseDatasourceProvider).watchOrderById(orderId);
});

// ─── Favorites ────────────────────────────────────────────────────────────
final favoriteDishIdsStreamProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(customerIdProvider);
  return ref.watch(customerFirebaseDataSourceProvider).watchFavoriteDishIds(uid);
});

// ─── Addresses ────────────────────────────────────────────────────────────
final customerAddressesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(customerIdProvider);
  return ref.watch(customerFirebaseDataSourceProvider).watchAddresses(uid);
});

// ─── Notifications ────────────────────────────────────────────────────────
final customerNotificationsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(customerIdProvider);
  return ref.watch(customerFirebaseDataSourceProvider).watchNotifications(uid);
});

// ─── Chat (Supabase conversations + messages) ─────────────────────────────
final customerChefChatsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final customerId = ref.watch(customerIdProvider);
  return ref.watch(customerChatSupabaseDataSourceProvider).watchConversations(customerId, 'customer-chef');
});

final customerSupportChatsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final customerId = ref.watch(customerIdProvider);
  return ref.watch(customerChatSupabaseDataSourceProvider).watchConversations(customerId, 'customer-support');
});

final customerChatMessagesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, conversationId) {
  return ref.watch(customerChatSupabaseDataSourceProvider).watchMessages(conversationId);
});

/// Legacy alias: use [customerChatSupabaseDataSourceProvider] for sendMessage in conversation screen.
final customerChatFirebaseDataSourceProvider = Provider<CustomerChatSupabaseDatasource>((ref) {
  return ref.watch(customerChatSupabaseDataSourceProvider);
});

// ─── Customer Reels (Supabase reels + reel_likes) ─────────────────────────
/// Stream of all reels (ordered by created_at desc) with chef name and isLiked for current customer.
final reelsStreamProvider = StreamProvider<List<ReelEntity>>((ref) {
  final customerId = ref.watch(customerIdProvider);
  return ref.watch(customerReelsSupabaseDatasourceProvider).watchReels(customerId);
});

/// Stream of reel ids the current customer has liked. Use with [reelsStreamProvider] for like state.
final reelLikesProvider = StreamProvider<Set<String>>((ref) {
  final customerId = ref.watch(customerIdProvider);
  return ref.watch(customerReelsSupabaseDatasourceProvider).watchLikedReelIds(customerId);
});

/// Alias for [reelsStreamProvider] (used by customer Reels screen).
final customerReelsStreamProvider = reelsStreamProvider;