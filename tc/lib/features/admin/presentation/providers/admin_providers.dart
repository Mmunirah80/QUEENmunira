import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_supabase_datasource.dart';
import '../../data/models/admin_dashboard_stats.dart';

final adminSupabaseDatasourceProvider = Provider<AdminSupabaseDatasource>((ref) {
  return AdminSupabaseDatasource();
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.isAdmin == true && user?.isBlocked != true;
});

/// All profiles (paged) for admin user directory.
final adminProfilesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  return ref.watch(adminSupabaseDatasourceProvider).fetchProfilesForAdmin(limit: 300);
});

/// All reels for admin moderation (newest first).
final adminReelsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  return ref.watch(adminSupabaseDatasourceProvider).fetchAllReelsForAdmin();
});

/// All marketplace orders (newest first) for admin monitoring.
final adminOrdersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  return ref.watch(adminSupabaseDatasourceProvider).fetchRecentOrdersForAdmin(limit: 200);
});

/// Order header + items for admin detail view.
final adminOrderDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, orderId) async {
  if (!ref.watch(isAdminProvider)) {
    return null;
  }
  if (orderId.isEmpty) return null;
  return ref.watch(adminSupabaseDatasourceProvider).fetchOrderDetailForAdmin(orderId);
});

/// Customer–chef thread linked to this order ([conversations.order_id]), if any.
final adminOrderConversationIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, orderId) async {
  if (!ref.watch(isAdminProvider)) {
    return null;
  }
  if (orderId.isEmpty) return null;
  return ref
      .watch(adminSupabaseDatasourceProvider)
      .fetchCustomerChefConversationIdForOrder(orderId);
});

final adminDashboardStatsProvider = FutureProvider<AdminDashboardStats>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const AdminDashboardStats(
      ordersToday: 0,
      revenueToday: 0,
      activeChefs: 0,
      openComplaints: 0,
    );
  }
  final ds = ref.watch(adminSupabaseDatasourceProvider);
  final stats = await ds.getDashboardStats();
  await ds.logAction(
    action: 'view_dashboard',
    targetTable: null,
    targetId: null,
    payload: {
      'source': 'admin_dashboard',
    },
  );
  return stats;
});

/// Paginated pending [chef_documents] for the admin dashboard (load more in UI).
class AdminPendingDocsState {
  final List<Map<String, dynamic>> rows;
  final bool initialLoading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;

  const AdminPendingDocsState({
    this.rows = const [],
    this.initialLoading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
  });

  AdminPendingDocsState copyWith({
    List<Map<String, dynamic>>? rows,
    bool? initialLoading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    bool? hasMore,
  }) {
    return AdminPendingDocsState(
      rows: rows ?? this.rows,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class AdminPendingChefDocumentsNotifier extends StateNotifier<AdminPendingDocsState> {
  AdminPendingChefDocumentsNotifier(this._ref)
      : super(const AdminPendingDocsState());

  final Ref _ref;
  static const _pageSize = 25;

  /// Monotonic token so in-flight [refresh] / [loadMore] responses never overwrite newer state.
  int _fetchGeneration = 0;

  Future<void> refresh() async {
    if (!_ref.read(isAdminProvider)) {
      state = AdminPendingDocsState(
        initialLoading: false,
        error: Exception('Admin access required'),
        hasMore: false,
      );
      return;
    }
    final gen = ++_fetchGeneration;
    final showFullSpinner = state.rows.isEmpty;
    state = state.copyWith(
      initialLoading: showFullSpinner,
      loadingMore: false,
      clearError: true,
    );
    try {
      final ds = _ref.read(adminSupabaseDatasourceProvider);
      final batch = await ds.fetchPendingChefDocuments(
        limit: _pageSize,
        offset: 0,
      );
      if (gen != _fetchGeneration) return;
      state = AdminPendingDocsState(
        rows: batch,
        initialLoading: false,
        hasMore: batch.length >= _pageSize,
        loadingMore: false,
      );
    } catch (e, st) {
      debugPrint('[Admin] pending docs refresh: $e\n$st');
      if (gen != _fetchGeneration) return;
      state = state.copyWith(initialLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!_ref.read(isAdminProvider)) return;
    if (state.loadingMore || !state.hasMore || state.initialLoading) return;
    final gen = ++_fetchGeneration;
    final offset = state.rows.length;
    final previousRows = List<Map<String, dynamic>>.from(state.rows);
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final ds = _ref.read(adminSupabaseDatasourceProvider);
      final batch = await ds.fetchPendingChefDocuments(
        limit: _pageSize,
        offset: offset,
      );
      if (gen != _fetchGeneration) return;
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final r in [...previousRows, ...batch]) {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        merged.add(r);
      }
      state = state.copyWith(
        rows: merged,
        loadingMore: false,
        hasMore: batch.length >= _pageSize,
      );
    } catch (e, st) {
      debugPrint('[Admin] pending docs loadMore: $e\n$st');
      if (gen != _fetchGeneration) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}

final adminPendingChefDocumentsNotifierProvider =
    StateNotifierProvider.autoDispose<AdminPendingChefDocumentsNotifier, AdminPendingDocsState>(
  (ref) => AdminPendingChefDocumentsNotifier(ref),
);

