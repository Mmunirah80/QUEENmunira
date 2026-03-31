import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/orders_mock_remote_datasource.dart';
import '../../data/repositories/orders_repository_impl.dart';
import '../../domain/entities/chef_today_stats.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/orders_repository.dart';

/// **Debug:** in-memory cook orders default **off** (real Supabase flow).
/// Enable mock dataset with: `flutter run --dart-define=COOK_MOCK_ORDERS=true`
const bool _kCookMockOrders =
    bool.fromEnvironment('COOK_MOCK_ORDERS', defaultValue: false);

/// Cook shell session: profile says chef, or login-time role was chef (covers profile lag / missing role).
bool _isChefCookSession(UserEntity? user, AppRole? selectedLoginRole) {
  if (user == null || user.id.isEmpty) return false;
  if (user.isChef) return true;
  return selectedLoginRole == AppRole.chef;
}

/// Chef-scoped when user is chef; customer-scoped when customer; otherwise unscoped (admin).
final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final selectedLoginRole = ref.watch(selectedRoleProvider);
  final chefId =
      _isChefCookSession(user, selectedLoginRole) ? user!.id : null;
  final customerId = user?.isCustomer == true ? user!.id : null;

  if (kDebugMode &&
      _kCookMockOrders &&
      chefId != null &&
      chefId.isNotEmpty) {
    debugPrint('[Orders] COOK_MOCK_ORDERS: in-memory cook orders (QA)');
    return OrdersRepositoryImpl(
      remoteDataSource: OrdersMockRemoteDataSource(chefId: chefId),
    );
  }

  return OrdersRepositoryImpl(chefId: chefId, customerId: customerId);
});

/// True when the signed-in cook uses [OrdersMockRemoteDataSource] (debug + `COOK_MOCK_ORDERS`).
final cookOrdersUsingMockProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final selectedLoginRole = ref.watch(selectedRoleProvider);
  return kDebugMode &&
      _kCookMockOrders &&
      _isChefCookSession(user, selectedLoginRole);
});

final ordersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return await repository.getOrders();
});

final pendingOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return await repository.getOrdersByStatus(OrderStatus.pending);
});

final activeOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repository = ref.watch(ordersRepositoryProvider);
  final accepted = await repository.getOrdersByStatus(OrderStatus.accepted);
  final preparing = await repository.getOrdersByStatus(OrderStatus.preparing);
  return [...accepted, ...preparing];
});

final completedOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return await repository.getOrdersByStatus(OrderStatus.completed);
});

/// All chef orders (any status). Single subscription; detail screen picks one id via [cookOrderLiveProvider].
final chefAllOrdersStreamProvider = StreamProvider.autoDispose<List<OrderEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  debugPrint('[Orders] chefAllOrdersStream chefId=${user?.id}, isChef=${user?.isChef}');
  return ref.watch(ordersRepositoryProvider).watchOrders(statuses: null);
});

/// Live row for order detail (merged from [chefAllOrdersStreamProvider]).
final cookOrderLiveProvider = Provider.autoDispose.family<OrderEntity?, String>((ref, orderId) {
  if (orderId.isEmpty) return null;
  final list = ref.watch(chefAllOrdersStreamProvider).valueOrNull;
  if (list == null) return null;
  for (final o in list) {
    if (o.id == orderId) return o;
  }
  return null;
});

/// Real-time stream: pending only (New tab).
final chefNewOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  debugPrint('[Orders] chefNewOrdersStream chefId=${user?.id}, isChef=${user?.isChef}');
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [OrderStatus.pending],
  );
});

/// Real-time stream: accepted + preparing (Active tab).
final chefActiveOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  debugPrint('[Orders] chefActiveOrdersStream chefId=${user?.id}, isChef=${user?.isChef}');
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [OrderStatus.accepted, OrderStatus.preparing, OrderStatus.ready],
  );
});

/// Real-time stream: completed (Completed tab).
final chefCompletedOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  debugPrint('[Orders] chefCompletedOrdersStream chefId=${user?.id}, isChef=${user?.isChef}');
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [OrderStatus.completed],
  );
});

/// Real-time stream: rejected + cancelled (Cancelled tab).
final chefCancelledOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  debugPrint('[Orders] chefCancelledOrdersStream chefId=${user?.id}, isChef=${user?.isChef}');
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [OrderStatus.rejected, OrderStatus.cancelled],
  );
});

/// Today's order count and earnings (for chef Home screen).
/// Uses [ordersRepositoryProvider] (mock or Supabase) with the same filters as the datasource.
final chefTodayStatsProvider = FutureProvider<ChefTodayStats>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  final selectedLoginRole = ref.watch(selectedRoleProvider);
  final chefId =
      _isChefCookSession(user, selectedLoginRole) ? user!.id : null;
  if (chefId == null || chefId.isEmpty) {
    return const ChefTodayStats(
      completedRevenueToday: 0,
      completedOrdersToday: 0,
      inKitchenCountToday: 0,
      pipelineOrderValueToday: 0,
    );
  }

  return ref.watch(ordersRepositoryProvider).getTodayStats();
});

/// Delayed orders (e.g. > 30 min) for badge/quick action.
final chefDelayedOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  return ref.watch(ordersRepositoryProvider).getDelayedOrders(const Duration(minutes: 30));
});

/// Earnings summary for chef (last 30 days completed orders: total + last 7 days daily).
final chefEarningsSummaryProvider = FutureProvider<({double totalEarnings, int totalCount, List<double> last7DaysEarnings})>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  return ref.watch(ordersRepositoryProvider).getEarningsSummary(since);
});

/// Monthly insights for Earnings & Insights screen (current calendar month).
final chefMonthlyInsightsProvider = FutureProvider<
    ({double monthEarnings, int monthOrders, String topDish, double acceptanceRate})>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  final chefId = user?.isChef == true ? user!.id : null;
  if (chefId == null || chefId.isEmpty) {
    return (monthEarnings: 0.0, monthOrders: 0, topDish: '—', acceptanceRate: 0.0);
  }

  try {
    final client = Supabase.instance.client;
    final now = DateTime.now().toUtc();
    final startOfMonth = DateTime.utc(now.year, now.month, 1);

    // Load this month's orders for the chef.
    final ordersRaw = await client
        .from('orders')
        .select('id, total_amount, status')
        .eq('chef_id', chefId)
        .gte('created_at', startOfMonth.toIso8601String());

    final ordersList = (ordersRaw as List?) ?? const [];

    double totalEarnings = 0.0;
    int totalOrders = 0;
    int acceptedOrders = 0;
    final orderIds = <String>[];

    for (final r in ordersList) {
      final row = r as Map<String, dynamic>;
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) {
        orderIds.add(id);
      }
      final status = (row['status'] as String?) ?? '';
      totalOrders += 1;
      if (status == 'accepted' ||
          status == 'preparing' ||
          status == 'ready' ||
          status == 'completed') {
        acceptedOrders += 1;
      }
      final totalField = row['total_amount'];
      if (totalField is num) {
        totalEarnings += totalField.toDouble();
      } else if (totalField is String) {
        totalEarnings += double.tryParse(totalField) ?? 0.0;
      }
    }

    // Default top dish.
    String topDish = '—';

    if (orderIds.isNotEmpty) {
      final itemsRaw = await client
          .from('order_items')
          .select('order_id, dish_name, quantity')
          .inFilter('order_id', orderIds);

      final itemsList = (itemsRaw as List?) ?? const [];
      final dishCounts = <String, int>{};

      for (final r in itemsList) {
        final row = r as Map<String, dynamic>;
        final name = (row['dish_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final qtyField = row['quantity'];
        final qty = qtyField is num ? qtyField.toInt() : int.tryParse('$qtyField') ?? 1;
        dishCounts.update(name, (v) => v + qty, ifAbsent: () => qty);
      }

      if (dishCounts.isNotEmpty) {
        topDish = dishCounts.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        ).key;
      }
    }

    final acceptanceRate =
        totalOrders == 0 ? 0.0 : (acceptedOrders / totalOrders) * 100.0;

    return (
      monthEarnings: totalEarnings,
      monthOrders: totalOrders,
      topDish: topDish,
      acceptanceRate: acceptanceRate,
    );
  } catch (_) {
    return (monthEarnings: 0.0, monthOrders: 0, topDish: '—', acceptanceRate: 0.0);
  }
});

/// Customer: real-time active orders through pickup-ready (excludes completed / terminal).
final customerActiveOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
    ],
  );
});

/// Customer: real-time order history (completed, cancelled).
final customerHistoryOrdersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchOrders(
    statuses: [OrderStatus.completed, OrderStatus.rejected, OrderStatus.cancelled],
  );
});
