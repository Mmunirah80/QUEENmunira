import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/admin_supabase_datasource.dart';
import '../../data/models/admin_analytics_bundle.dart';
import '../../data/models/admin_dashboard_stats.dart';
import '../../domain/admin_order_pipeline_buckets.dart';

final adminSupabaseDatasourceProvider = Provider<AdminSupabaseDatasource>((ref) {
  return AdminSupabaseDatasource();
});

final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.isAdmin == true && user?.isBlocked != true;
});

/// Session user id for admin chat (labels + send).
final adminChatSessionUserIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id.trim() ?? '';
});

/// User directory search (debounced in UI; updates list when query changes).
final adminProfilesSearchQueryProvider = StateProvider<String>((ref) => '');

/// Orders search (debounced typing + submit; updates list when query changes).
final adminOrdersSearchQueryProvider = StateProvider<String>((ref) => '');

/// All profiles (paged) for admin user directory.
final adminProfilesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  final q = ref.watch(adminProfilesSearchQueryProvider);
  return ref.watch(adminSupabaseDatasourceProvider).fetchProfilesForAdmin(
        limit: 300,
        searchQuery: q.trim().isEmpty ? null : q.trim(),
      );
});

/// All reels for admin moderation (newest first).
final adminReelsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  return ref.watch(adminSupabaseDatasourceProvider).fetchAllReelsForAdmin(limit: 500);
});

/// Cook / customer UUID filters (exact match on [orders.chef_id] / [orders.customer_id]).
final adminOrdersChefIdFilterProvider = StateProvider<String?>((ref) => null);

final adminOrdersCustomerIdFilterProvider = StateProvider<String?>((ref) => null);

/// Inclusive date bounds on [orders.created_at] (local calendar day end used for [to] in datasource).
final adminOrdersDateFromProvider = StateProvider<DateTime?>((ref) => null);

final adminOrdersDateToProvider = StateProvider<DateTime?>((ref) => null);

/// When [adminOrdersStuckOnlyProvider] is true, narrows stuck orders by pipeline stage (>2h since [updated_at]).
enum AdminOrdersStuckSubtype { any, acceptedLong, preparingLong, readyLong }

final adminOrdersStuckSubtypeProvider = StateProvider<AdminOrdersStuckSubtype>(
  (ref) => AdminOrdersStuckSubtype.any,
);

/// All marketplace orders (newest first) for admin monitoring.
final adminOrdersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const [];
  }
  final q = ref.watch(adminOrdersSearchQueryProvider);
  final chef = ref.watch(adminOrdersChefIdFilterProvider)?.trim();
  final cust = ref.watch(adminOrdersCustomerIdFilterProvider)?.trim();
  return ref.watch(adminSupabaseDatasourceProvider).fetchRecentOrdersForAdmin(
        limit: 200,
        searchQuery: q.trim().isEmpty ? null : q.trim(),
        chefIdEq: chef == null || chef.isEmpty ? null : chef,
        customerIdEq: cust == null || cust.isEmpty ? null : cust,
        createdAfter: ref.watch(adminOrdersDateFromProvider),
        createdBefore: ref.watch(adminOrdersDateToProvider),
      );
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

/// Recent orders aggregated into pipeline buckets (dashboard timeline).
final adminOrderPipelineProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const {};
  }
  final orders = await ref.watch(adminSupabaseDatasourceProvider).fetchRecentOrdersForAdmin(
        limit: 400,
      );
  return adminOrderPipelineBucketsFromOrderRows(orders);
});

/// Bottom navigation index for [AdminMainNavigationScreen] (0–4: Dashboard, Users, Orders, Chat, Reels).
final adminBottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Tab inside [AdminUsersHubScreen]: 0 = user directory, 1 = inspection.
final adminUsersHubTabProvider = StateProvider<int>((ref) => 0);

/// Initial tab on [AdminInspectionsScreen]: 0 = queue, 1 = overview, 2 = history.
final adminInspectionTabProvider = StateProvider<int>((ref) => 0);

/// [chef_violations] ledger for compliance overview (admin).
final adminInspectionViolationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchInspectionViolationsForAdmin(limit: 250);
});

/// When true, [AdminOrdersScreen] lists only likely stuck active orders.
final adminOrdersStuckOnlyProvider = StateProvider<bool>((ref) => false);

/// Synced with [AdminUsersScreen] tab bar: All / Customer / Cook (KPI taps update this).
enum AdminUsersRoleTab { all, customer, cook }

final adminUsersRoleTabProvider = StateProvider<AdminUsersRoleTab>((ref) => AdminUsersRoleTab.all);

/// Extra filter on Users list (combined with role tab).
enum AdminUsersAccountFilter { all, frozenOrBlocked }

final adminUsersAccountFilterProvider = StateProvider<AdminUsersAccountFilter>((ref) => AdminUsersAccountFilter.all);

/// One-shot tab index for [AdminOrdersScreen] (0–3). Consumed when Orders screen builds.
final adminOrdersTargetTabProvider = StateProvider<int?>((ref) => null);

/// Reels moderation list filter (KPI “Reported content” sets [reported]).
enum AdminReelsModerationFilter { all, reported }

enum AdminReelsSort { newest, mostReported }

final adminReelsSortProvider = StateProvider<AdminReelsSort>((ref) => AdminReelsSort.newest);

/// Admin reels search (debounced typing + submit; filters All + Reported tabs).
final adminReelsSearchQueryProvider = StateProvider<String>((ref) => '');

final adminReelsModerationFilterProvider = StateProvider<AdminReelsModerationFilter>(
  (ref) => AdminReelsModerationFilter.all,
);

/// Chat monitoring queue (requires [conversations.admin_moderation_state] / [admin_reviewed_at]).
enum AdminChatQueueFilter { all, reported, flagged, unresolved, reviewed }

final adminOrderChatQueueFilterProvider = StateProvider<AdminChatQueueFilter>(
  (ref) => AdminChatQueueFilter.all,
);

final adminSupportChatQueueFilterProvider = StateProvider<AdminChatQueueFilter>(
  (ref) => AdminChatQueueFilter.all,
);

/// Analytics page: primary window in days (7 / 30 / 90).
final adminAnalyticsWindowDaysProvider = StateProvider<int>((ref) => 30);

/// Conversation row for resolving message sender roles in admin chat.
final adminConversationMetaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, chatId) async {
  if (!ref.watch(isAdminProvider) || chatId.isEmpty) return null;

  Future<Map<String, dynamic>?> loadBase() async {
    try {
      final row = await SupabaseConfig.client
          .from('conversations')
          .select('id,type,customer_id,chef_id,order_id,admin_moderation_state,admin_reviewed_at')
          .eq('id', chatId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (e, st) {
      debugPrint('[adminConversationMeta] extended columns missing? $e\n$st');
      try {
        final row = await SupabaseConfig.client
            .from('conversations')
            .select('id,type,customer_id,chef_id,order_id')
            .eq('id', chatId)
            .maybeSingle();
        if (row == null) return null;
        return Map<String, dynamic>.from(row);
      } catch (e2, st2) {
        debugPrint('[adminConversationMeta] order_id missing? $e2\n$st2');
        final row = await SupabaseConfig.client
            .from('conversations')
            .select('id,type,customer_id,chef_id')
            .eq('id', chatId)
            .maybeSingle();
        if (row == null) return null;
        return Map<String, dynamic>.from(row);
      }
    }
  }

  final m = await loadBase();
  if (m == null) return null;

  final oid = (m['order_id'] ?? '').toString().trim();
  if (oid.isNotEmpty) {
    try {
      final o = await SupabaseConfig.client
          .from('orders')
          .select('id,status,customer_name,chef_name')
          .eq('id', oid)
          .maybeSingle();
      if (o != null) {
        final om = Map<String, dynamic>.from(o);
        m['_header_customer'] = (om['customer_name'] ?? '').toString();
        m['_header_cook'] = (om['chef_name'] ?? '').toString();
        m['_header_order_status'] = (om['status'] ?? '').toString();
      }
    } catch (e, st) {
      debugPrint('[adminConversationMeta] order join: $e\n$st');
    }
  }

  final custId = (m['customer_id'] ?? '').toString().trim();
  final chefId = (m['chef_id'] ?? '').toString().trim();
  final needCustomerName =
      ((m['_header_customer'] ?? '') as String).isEmpty && custId.isNotEmpty;
  final needCookName = ((m['_header_cook'] ?? '') as String).isEmpty && chefId.isNotEmpty;
  if (needCustomerName || needCookName) {
    try {
      final ids = <String>{if (custId.isNotEmpty) custId, if (chefId.isNotEmpty) chefId}.toList();
      if (ids.isNotEmpty) {
        final pr = await SupabaseConfig.client.from('profiles').select('id,full_name').inFilter('id', ids);
        final names = <String, String>{};
        for (final raw in pr as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final id = (row['id'] ?? '').toString();
          final nm = (row['full_name'] ?? '').toString().trim();
          if (id.isNotEmpty && nm.isNotEmpty) names[id] = nm;
        }
        if (((m['_header_customer'] ?? '') as String).isEmpty && custId.isNotEmpty) {
          m['_header_customer'] = names[custId] ?? '';
        }
        if (((m['_header_cook'] ?? '') as String).isEmpty && chefId.isNotEmpty) {
          m['_header_cook'] = names[chefId] ?? '';
        }
      }
    } catch (e, st) {
      debugPrint('[adminConversationMeta] profiles: $e\n$st');
    }
  }

  if (((m['_header_cook'] ?? '') as String).isEmpty && chefId.isNotEmpty) {
    try {
      final ch = await SupabaseConfig.client
          .from('chef_profiles')
          .select('id,kitchen_name')
          .eq('id', chefId)
          .maybeSingle();
      if (ch != null) {
        final kn = (Map<String, dynamic>.from(ch)['kitchen_name'] ?? '').toString().trim();
        if (kn.isNotEmpty) m['_header_cook'] = kn;
      }
    } catch (e, st) {
      debugPrint('[adminConversationMeta] chef_profiles: $e\n$st');
    }
  }

  return m;
});

final adminDashboardStatsProvider = FutureProvider<AdminDashboardStats>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return const AdminDashboardStats(
      ordersToday: 0,
      revenueToday: 0,
      activeChefs: 0,
      openComplaints: 0,
      completedOrders: 0,
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

/// Shorter window for dashboard charts / rankings (performance).
final adminDashboardAnalyticsProvider =
    FutureProvider.autoDispose<AdminAnalyticsBundle>((ref) async {
  if (!ref.watch(isAdminProvider)) return AdminAnalyticsBundle.empty();
  final raw = await ref.watch(adminSupabaseDatasourceProvider).getAdminAnalyticsBundle(
        dailyDays: 14,
        monthlyMonths: 4,
        hourLookbackDays: 14,
      );
  return AdminAnalyticsBundle.fromMap(raw);
});

final adminAlertsSummaryProvider = FutureProvider.autoDispose<AdminAlertsSummary>((ref) async {
  if (!ref.watch(isAdminProvider)) return const AdminAlertsSummary();
  final raw = await ref.read(adminSupabaseDatasourceProvider).getAdminAlertsSummary();
  return AdminAlertsSummary.fromMap(raw);
});

/// Full analytics page uses [adminAnalyticsWindowDaysProvider].
final adminAnalyticsBundleProvider = FutureProvider.autoDispose<AdminAnalyticsBundle>((ref) async {
  if (!ref.watch(isAdminProvider)) return AdminAnalyticsBundle.empty();
  final days = ref.watch(adminAnalyticsWindowDaysProvider).clamp(7, 120);
  final raw = await ref.watch(adminSupabaseDatasourceProvider).getAdminAnalyticsBundle(
        dailyDays: days,
        monthlyMonths: 6,
        hourLookbackDays: days,
      );
  return AdminAnalyticsBundle.fromMap(raw);
});

final adminUserDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, userId) async {
  if (!ref.watch(isAdminProvider) || userId.isEmpty) return {};
  return ref.watch(adminSupabaseDatasourceProvider).getAdminUserDetail(userId);
});

final adminCookMenuDetailProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchMenuItemsForCook(cookId);
});

/// Menu rows with [_order_count] from completed [order_items] (see [AdminSupabaseDatasource.fetchOrderCountsByMenuItemForCook]).
final adminCookMenuWithOrderCountsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  final ds = ref.watch(adminSupabaseDatasourceProvider);
  final menu = await ds.fetchMenuItemsForCook(cookId);
  final counts = await ds.fetchOrderCountsByMenuItemForCook(cookId);
  return menu.map((r) {
    final id = (r['id'] ?? '').toString();
    final c = counts[id] ?? 0;
    return <String, dynamic>{...r, '_order_count': c};
  }).toList();
});

final adminCookActivityTimelineProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchCookActivityTimelineRows(cookId);
});

final adminCookTopDishesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchTopDishLinesForCook(cookId, limit: 10);
});

/// Sample for dashboard “delayed” list (same source as order pipeline).
final adminDashboardRecentOrdersSampleProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchRecentOrdersForAdmin(limit: 200);
});

/// Reported reels (requires [reel_reports] enrichment in [fetchAllReelsForAdmin]).
final adminDashboardReportedReelsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(isAdminProvider)) return const [];
  final reels = await ref.watch(adminSupabaseDatasourceProvider).fetchAllReelsForAdmin();
  final withReports = reels.where((r) {
    final n = (r['report_count'] as num?)?.toInt() ?? 0;
    return n > 0;
  }).toList();
  withReports.sort((a, b) {
    final ta = DateTime.tryParse((a['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = DateTime.tryParse((b['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });
  return withReports.take(12).toList();
});

final adminDashboardSupportTicketsProvider =
    FutureProvider.autoDispose<({List<Map<String, dynamic>> rows, bool backendAvailable})>((ref) async {
  if (!ref.watch(isAdminProvider)) {
    return (rows: <Map<String, dynamic>>[], backendAvailable: false);
  }
  return ref.watch(adminSupabaseDatasourceProvider).fetchSupportTicketsPreviewForAdmin(limit: 10);
});

final adminCookDocumentsDetailProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchChefDocumentsAllForAdmin(cookId);
});

final adminCookOrdersDetailProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchOrdersForUserRole(
        userId: cookId,
        role: 'chef',
        limit: 100,
      );
});

final adminCookReelsDetailProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, cookId) async {
  if (!ref.watch(isAdminProvider) || cookId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchReelsForCook(cookId);
});

final adminCustomerOrdersDetailProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  if (!ref.watch(isAdminProvider) || customerId.isEmpty) return const [];
  return ref.watch(adminSupabaseDatasourceProvider).fetchOrdersForUserRole(
        userId: customerId,
        role: 'customer',
        limit: 50,
      );
});

/// One cook application: all [chef_documents] rows (newest-first), for per-document review.
class AdminPendingApplicationGroup {
  const AdminPendingApplicationGroup({
    required this.chefId,
    required this.applicantName,
    required this.kitchenName,
    required this.documents,
  });

  final String chefId;
  /// From [profiles.full_name] when available.
  final String applicantName;
  final String kitchenName;
  final List<Map<String, dynamic>> documents;
}

/// Paginated pending applications (grouped by chef) for Cook Inspection.
class AdminPendingDocsState {
  final List<AdminPendingApplicationGroup> groups;
  final bool initialLoading;
  final bool loadingMore;
  final Object? error;
  final bool hasMore;

  const AdminPendingDocsState({
    this.groups = const [],
    this.initialLoading = true,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
  });

  AdminPendingDocsState copyWith({
    List<AdminPendingApplicationGroup>? groups,
    bool? initialLoading,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    bool? hasMore,
  }) {
    return AdminPendingDocsState(
      groups: groups ?? this.groups,
      initialLoading: initialLoading ?? this.initialLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class AdminPendingCookDocumentsNotifier extends StateNotifier<AdminPendingDocsState> {
  AdminPendingCookDocumentsNotifier(this._ref)
      : super(const AdminPendingDocsState());

  final Ref _ref;
  static const _pageSize = 12;

  /// Monotonic token so in-flight [refresh] / [loadMore] responses never overwrite newer state.
  int _fetchGeneration = 0;

  Future<List<AdminPendingApplicationGroup>> _loadGroupsForChefIds(
    List<String> chefIds,
    AdminSupabaseDatasource ds,
    Map<String, String> kitchenNames,
  ) async {
    if (chefIds.isEmpty) return const [];
    final applicants = await ds.fetchChefApplicantDisplayNames(chefIds);
    final out = <AdminPendingApplicationGroup>[];
    for (final id in chefIds) {
      final docs = await ds.fetchChefDocumentsAllForAdmin(id);
      out.add(
        AdminPendingApplicationGroup(
          chefId: id,
          applicantName: applicants[id] ?? id,
          kitchenName: kitchenNames[id] ?? id,
          documents: docs,
        ),
      );
    }
    return out;
  }

  /// Reloads one chef after a document decision without full list refresh.
  Future<void> refreshChef(String chefId) async {
    if (!_ref.read(isAdminProvider) || chefId.isEmpty) return;
    final ds = _ref.read(adminSupabaseDatasourceProvider);
    try {
      final docs = await ds.fetchChefDocumentsAllForAdmin(chefId);
      final stillPending = docs.any((d) => (d['status'] ?? '').toString().toLowerCase().trim() == 'pending_review');
      final names = await ds.fetchKitchenNamesForChefIds([chefId]);
      final applicants = await ds.fetchChefApplicantDisplayNames([chefId]);
      final name = names[chefId] ?? chefId;
      final applicant = applicants[chefId] ?? chefId;
      final list = List<AdminPendingApplicationGroup>.from(state.groups);
      final idx = list.indexWhere((g) => g.chefId == chefId);
      if (!stillPending) {
        if (idx >= 0) list.removeAt(idx);
      } else {
        final g = AdminPendingApplicationGroup(
          chefId: chefId,
          applicantName: idx >= 0 ? list[idx].applicantName : applicant,
          kitchenName: idx >= 0 ? list[idx].kitchenName : name,
          documents: docs,
        );
        if (idx >= 0) {
          list[idx] = g;
        } else {
          list.insert(0, g);
        }
      }
      state = state.copyWith(groups: list);
    } catch (e, st) {
      debugPrint('[Admin] refreshChef $chefId: $e\n$st');
    }
  }

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
    final showFullSpinner = state.groups.isEmpty;
    state = state.copyWith(
      initialLoading: showFullSpinner,
      loadingMore: false,
      clearError: true,
    );
    try {
      final ds = _ref.read(adminSupabaseDatasourceProvider);
      final batch = await ds.fetchChefIdsWithPendingReviewDocuments(
        limit: _pageSize,
        offset: 0,
      );
      if (gen != _fetchGeneration) return;
      final kitchens = await ds.fetchKitchenNamesForChefIds(batch.chefIds);
      final groups = await _loadGroupsForChefIds(batch.chefIds, ds, kitchens);
      if (gen != _fetchGeneration) return;
      state = AdminPendingDocsState(
        groups: groups,
        initialLoading: false,
        hasMore: batch.hasMore,
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
    final offset = state.groups.length;
    final previous = List<AdminPendingApplicationGroup>.from(state.groups);
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final ds = _ref.read(adminSupabaseDatasourceProvider);
      final batch = await ds.fetchChefIdsWithPendingReviewDocuments(
        limit: _pageSize,
        offset: offset,
      );
      if (gen != _fetchGeneration) return;
      final kitchens = await ds.fetchKitchenNamesForChefIds(batch.chefIds);
      final loaded = await _loadGroupsForChefIds(batch.chefIds, ds, kitchens);
      if (gen != _fetchGeneration) return;
      final seen = <String>{};
      final merged = <AdminPendingApplicationGroup>[];
      for (final g in [...previous, ...loaded]) {
        if (seen.contains(g.chefId)) continue;
        seen.add(g.chefId);
        merged.add(g);
      }
      state = state.copyWith(
        groups: merged,
        loadingMore: false,
        hasMore: batch.hasMore,
      );
    } catch (e, st) {
      debugPrint('[Admin] pending docs loadMore: $e\n$st');
      if (gen != _fetchGeneration) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}

final adminPendingCookDocumentsNotifierProvider =
    StateNotifierProvider.autoDispose<AdminPendingCookDocumentsNotifier, AdminPendingDocsState>(
  (ref) => AdminPendingCookDocumentsNotifier(ref),
);

