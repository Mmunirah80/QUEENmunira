import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:naham_cook_app/core/constants/route_names.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';

/// Admin: list of [profiles] with block/unblock (updates [is_blocked]; RLS: admin UPDATE).
///
/// When [embedded] is true (inside [AdminUsersHubScreen]), no [Scaffold] — parent provides chrome.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

Map<String, dynamic>? _chefProfileFromRow(Map<String, dynamic> r) {
  final raw = r['chef_profiles'];
  if (raw is Map<String, dynamic>) return raw;
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

String _formatShortDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

bool _rowIsFrozenOrBlocked(Map<String, dynamic> r) {
  final role = (r['role'] ?? '').toString();
  final blocked = r['is_blocked'] == true;
  if (role != 'chef') return blocked;
  final cp = _chefProfileFromRow(r);
  final wc = (cp?['warning_count'] as num?)?.toInt() ?? 0;
  final fu = _parseDate(cp?['freeze_until']);
  final display = cookAccountStateForProfile(
    isBlocked: blocked,
    warningCount: wc,
    freezeUntil: fu,
    freezeType: cp?['freeze_type']?.toString(),
  );
  return display.state == CookAccountState.frozen || display.state == CookAccountState.blocked;
}

List<Map<String, dynamic>> _applyAccountFilter(
  List<Map<String, dynamic>> rows,
  AdminUsersAccountFilter f,
) {
  if (f == AdminUsersAccountFilter.all) return rows;
  return rows.where(_rowIsFrozenOrBlocked).toList();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchCtrl;
  late final TabController _tabCtrl;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_syncTabToRoleProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchCtrl.text = ref.read(adminProfilesSearchQueryProvider);
      final role = ref.read(adminUsersRoleTabProvider);
      _tabCtrl.index = _indexForRoleTab(role);
    });
  }

  void _syncTabToRoleProvider() {
    if (_tabCtrl.indexIsChanging) return;
    final tab = _roleTabForIndex(_tabCtrl.index);
    if (ref.read(adminUsersRoleTabProvider) != tab) {
      ref.read(adminUsersRoleTabProvider.notifier).state = tab;
    }
  }

  static int _indexForRoleTab(AdminUsersRoleTab t) => switch (t) {
        AdminUsersRoleTab.all => 0,
        AdminUsersRoleTab.customer => 1,
        AdminUsersRoleTab.cook => 2,
      };

  static AdminUsersRoleTab _roleTabForIndex(int i) => switch (i) {
        1 => AdminUsersRoleTab.customer,
        2 => AdminUsersRoleTab.cook,
        _ => AdminUsersRoleTab.all,
      };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.removeListener(_syncTabToRoleProvider);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyUserSearch() {
    ref.read(adminProfilesSearchQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _applyUserSearch();
    });
  }

  Future<void> _setBlocked({
    required BuildContext context,
    required String id,
    required String name,
    required bool blocked,
  }) async {
    final myId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    if (myId.isEmpty || id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(blocked ? 'Block user' : 'Unblock user'),
        content: Text(
          blocked
              ? 'Block ${name.isEmpty ? id : name}? They will lose access to features that require an active account.'
              : 'Unblock ${name.isEmpty ? id : name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(blocked ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(adminSupabaseDatasourceProvider).setProfileBlockedForAdmin(
            profileId: id,
            blocked: blocked,
            currentAdminId: myId,
          );
      if (context.mounted) {
        ref.invalidate(adminProfilesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(blocked ? 'User blocked' : 'User unblocked')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Widget _buildProfileCard(
    BuildContext context,
    Map<String, dynamic> r,
    String myId,
  ) {
    final name = (r['full_name'] ?? '').toString().trim();
    final role = (r['role'] ?? '').toString();
    final phone = (r['phone'] ?? '').toString().trim();
    final email = (r['email'] ?? '').toString().trim();
    final blocked = r['is_blocked'] == true;
    final id = (r['id'] ?? '').toString();
    final isSelf = myId.isNotEmpty && id == myId;
    final roleEnum = adminUserRoleFromDbRole(role);

    final cp = role == 'chef' ? _chefProfileFromRow(r) : null;
    final warningCount = (cp?['warning_count'] as num?)?.toInt() ?? 0;
    final freezeUntil = _parseDate(cp?['freeze_until']);
    final cookState = role == 'chef'
        ? cookAccountStateForProfile(
            isBlocked: blocked,
            warningCount: warningCount,
            freezeUntil: freezeUntil,
            freezeType: cp?['freeze_type']?.toString(),
          )
        : null;

    String firstChar(String s) {
      final t = s.trim();
      if (t.isEmpty) return '?';
      return t.substring(0, 1).toUpperCase();
    }

    final initials = name.isNotEmpty ? firstChar(name) : firstChar(id);

    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: id.isEmpty
            ? null
            : () => context.push(RouteNames.adminUserDetail(id)),
        child: Ink(
          decoration: AdminPanelTokens.surfaceCard(context, scheme),
          child: Padding(
            padding: const EdgeInsets.all(AdminPanelTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AdminPanelTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? '(No name)' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: AdminPanelTokens.space8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (roleEnum != null) AdminRoleBadge(role: roleEnum),
                              if (isSelf)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'You',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          if (email.isNotEmpty || phone.isNotEmpty) ...[
                            const SizedBox(height: AdminPanelTokens.space8),
                            Text(
                              [
                                if (email.isNotEmpty) email,
                                if (phone.isNotEmpty) phone,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.25,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Blocked: same plain copy for customer, admin, and cook (no cook-only badge when blocked).
                if (blocked) ...[
                  const SizedBox(height: AdminPanelTokens.space12),
                  Text(
                    'Account blocked',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                if (role == 'chef' && !blocked && cookState != null) ...[
                  const SizedBox(height: AdminPanelTokens.space12),
                  CookAccountStateBadge(display: cookState),
                ],
                if (id.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AdminPanelTokens.space8),
                    child: Text(
                      'ID: ${id.length > 12 ? '${id.substring(0, 8)}…' : id}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                if (_parseDate(r['created_at']) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AdminPanelTokens.space8),
                    child: Text(
                      'Registered: ${_formatShortDate(_parseDate(r['created_at'])!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                if (!isSelf && id.isNotEmpty && myId.isNotEmpty) ...[
                  const SizedBox(height: AdminPanelTokens.space8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: blocked
                        ? TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _setBlocked(
                              context: context,
                              id: id,
                              name: name,
                              blocked: false,
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: const Text('Unblock'),
                          )
                        : TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _setBlocked(
                              context: context,
                              id: id,
                              name: name,
                              blocked: true,
                            ),
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text('Block'),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profilesErrorPane(Object e) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(adminProfilesListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    String myId, {
    required String emptyMessage,
    String? emptySubtitle,
  }) {
    if (rows.isEmpty) {
      return AdminEmptyState(
        icon: Icons.people_outline_rounded,
        title: emptyMessage,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) => _buildProfileCard(
        context,
        rows[i],
        myId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    ref.listen<AdminUsersRoleTab>(adminUsersRoleTabProvider, (prev, next) {
      final idx = _AdminUsersScreenState._indexForRoleTab(next);
      if (_tabCtrl.index != idx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_tabCtrl.indexIsChanging && _tabCtrl.index != idx) {
            _tabCtrl.animateTo(idx);
          }
        });
      }
    });

    final async = ref.watch(adminProfilesListProvider);
    final myId = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    final appliedQuery = ref.watch(adminProfilesSearchQueryProvider);
    final accountFilter = ref.watch(adminUsersAccountFilterProvider);

    final scheme = Theme.of(context).colorScheme;
    TabBar buildRoleTabBar() => TabBar(
          controller: _tabCtrl,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.72),
          indicatorColor: scheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Customers'),
            Tab(text: 'Cooks'),
          ],
        );
    final directoryBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded)
            Material(
              color: scheme.surface,
              child: buildRoleTabBar(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Name, phone, or kitchen',
                      filled: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => _onSearchTextChanged(),
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      _applyUserSearch();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _applyUserSearch,
                ),
                if (appliedQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      ref.read(adminProfilesSearchQueryProvider.notifier).state = '';
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  FilterChip(
                    label: const Text('All'),
                    selected: accountFilter == AdminUsersAccountFilter.all,
                    onSelected: (_) {
                      ref.read(adminUsersAccountFilterProvider.notifier).state = AdminUsersAccountFilter.all;
                    },
                  ),
                  FilterChip(
                    label: const Text('Frozen or blocked'),
                    selected: accountFilter == AdminUsersAccountFilter.frozenOrBlocked,
                    onSelected: (_) {
                      ref.read(adminUsersAccountFilterProvider.notifier).state =
                          AdminUsersAccountFilter.frozenOrBlocked;
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _AdminUsersLoadingPane(),
                  _AdminUsersLoadingPane(),
                  _AdminUsersLoadingPane(),
                ],
              ),
              error: (e, _) => TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _profilesErrorPane(e),
                  _profilesErrorPane(e),
                  _profilesErrorPane(e),
                ],
              ),
              data: (rows) {
                final emptyAll = rows.isEmpty;
                final emptyAllMsg =
                    appliedQuery.isEmpty ? 'No users found' : 'No matching users';
                final cooks =
                    rows.where((r) => (r['role'] ?? '').toString() == 'chef').toList();
                final customers =
                    rows.where((r) => (r['role'] ?? '').toString() == 'customer').toList();
                final allFiltered = _applyAccountFilter(rows, accountFilter);
                final customersFiltered = _applyAccountFilter(customers, accountFilter);
                final cooksFiltered = _applyAccountFilter(cooks, accountFilter);

                final hint =
                    appliedQuery.isNotEmpty ? 'Try clearing search or changing account filters.' : null;
                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    emptyAll
                        ? AdminEmptyState(
                            icon: Icons.person_search_rounded,
                            title: emptyAllMsg,
                            subtitle: hint,
                          )
                        : _buildUserList(
                            context,
                            allFiltered,
                            myId,
                            emptyMessage: accountFilter == AdminUsersAccountFilter.frozenOrBlocked
                                ? 'No frozen or blocked users'
                                : 'No users match this view',
                            emptySubtitle: hint,
                          ),
                    emptyAll
                        ? AdminEmptyState(
                            icon: Icons.person_search_rounded,
                            title: emptyAllMsg,
                            subtitle: hint,
                          )
                        : _buildUserList(
                            context,
                            customersFiltered,
                            myId,
                            emptyMessage: accountFilter == AdminUsersAccountFilter.frozenOrBlocked
                                ? 'No frozen or blocked customers'
                                : 'No customers match this view',
                            emptySubtitle: hint,
                          ),
                    emptyAll
                        ? AdminEmptyState(
                            icon: Icons.person_search_rounded,
                            title: emptyAllMsg,
                            subtitle: hint,
                          )
                        : _buildUserList(
                            context,
                            cooksFiltered,
                            myId,
                            emptyMessage: accountFilter == AdminUsersAccountFilter.frozenOrBlocked
                                ? 'No frozen Cooks in this filter'
                                : 'No Cooks match this view',
                            emptySubtitle: hint,
                          ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    if (widget.embedded) {
      return directoryBody;
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Directory'),
        bottom: buildRoleTabBar(),
        actions: const [AdminSignOutIconButton()],
      ),
      body: directoryBody,
    );
  }
}

class _AdminUsersLoadingPane extends StatelessWidget {
  const _AdminUsersLoadingPane();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading directory…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
