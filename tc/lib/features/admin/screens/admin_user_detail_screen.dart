import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';
import 'package:naham_cook_app/features/admin/screens/admin_orders_screen.dart';
import 'package:naham_cook_app/features/admin/services/admin_actions_service.dart';
import 'package:naham_cook_app/features/admin/services/chef_enforcement.dart';
import 'package:naham_cook_app/features/cook/data/cook_required_document_types.dart';
import 'package:naham_cook_app/features/orders/data/order_db_status.dart';
import 'package:naham_cook_app/features/reels/presentation/providers/reels_provider.dart';

Map<String, dynamic>? _asJsonMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

String _str(dynamic v) => v?.toString().trim() ?? '';

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return DateTime.tryParse(s.replaceAll('"', ''));
}

/// Drill-down profile for a customer or cook (RPC + related lists).
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _cookTabs;

  @override
  void didUpdateWidget(covariant AdminUserDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _cookTabs?.dispose();
      _cookTabs = null;
    }
  }

  @override
  void dispose() {
    _cookTabs?.dispose();
    super.dispose();
  }

  Future<void> _afterAdminAction() async {
    ref.invalidate(adminUserDetailProvider(widget.userId));
    ref.invalidate(adminProfilesListProvider);
    ref.invalidate(adminCustomerOrdersDetailProvider(widget.userId));
    ref.invalidate(adminCookOrdersDetailProvider(widget.userId));
    ref.invalidate(adminCookActivityTimelineProvider(widget.userId));
    ref.invalidate(adminCookTopDishesProvider(widget.userId));
    ref.invalidate(adminCookMenuWithOrderCountsProvider(widget.userId));
    if (!mounted) return;
    setState(() {});
  }

  void _ensureCookTabs() {
    const length = 7;
    if (_cookTabs == null || _cookTabs!.length != length) {
      _cookTabs?.dispose();
      _cookTabs = TabController(length: length, vsync: this);
    }
  }

  Future<void> _takeCookEnforcement(BuildContext context, String cookId, String nextLabel) async {
    if (nextLabel.isEmpty) return;
    final ok = await AdminActionsService.confirmDestructive(
      context,
      title: 'Take action',
      message: 'Apply: $nextLabel?',
      confirmLabel: 'Apply',
    );
    if (ok != true || !context.mounted) return;
    final success =
        await ref.read(adminActionsServiceProvider).takeChefEnforcementAction(context, cookId: cookId);
    if (success) await _afterAdminAction();
  }

  void _goCookInspection(BuildContext context) {
    ref.read(adminInspectionTabProvider.notifier).state = 1;
    ref.read(adminUsersHubTabProvider.notifier).state = 1;
    ref.read(adminBottomNavIndexProvider.notifier).state = 1;
    context.pop();
  }

  void _goOrders(BuildContext context) {
    ref.read(adminBottomNavIndexProvider.notifier).state = 2;
    context.pop();
  }

  void _goChat(BuildContext context) {
    ref.read(adminBottomNavIndexProvider.notifier).state = 3;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.userId.trim();
    if (id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: const Center(child: Text('Invalid user id')),
      );
    }

    final async = ref.watch(adminUserDetailProvider(id));

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('User')),
        body: Center(child: Text(userFriendlyErrorMessage(e))),
      ),
      data: (raw) {
        final err = _str(raw['error']);
        if (err.isNotEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('User')),
            body: Center(child: Text(err == 'not_found' ? 'User not found' : err)),
          );
        }

        final profile = _asJsonMap(raw['profile']);
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User')),
            body: const Center(child: Text('No profile data')),
          );
        }

        final role = _str(profile['role']).toLowerCase();
        final name = _str(profile['full_name']).isEmpty ? id : _str(profile['full_name']);
        final email = _str(raw['email']);
        final isCook = role == 'chef' || role == 'cook';

        if (isCook) {
          _ensureCookTabs();
          final chef = _asJsonMap(raw['chef_profile']);
          final wc = (chef?['warning_count'] as num?)?.toInt() ?? 0;
          final fl = (chef?['freeze_level'] as num?)?.toInt() ?? 0;
          final profileBlocked = profile['is_blocked'] == true;
          final nextLabel = ChefEnforcement.nextActionLabel(
            warningCount: wc,
            freezeLevel: fl,
            profileBlocked: profileBlocked,
          );
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
            appBar: AppBar(
              title: Text(name),
              actions: const [AdminSignOutIconButton()],
              bottom: TabBar(
                controller: _cookTabs,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Dishes'),
                  Tab(text: 'Reels'),
                  Tab(text: 'Orders'),
                  Tab(text: 'Documents'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Activity'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _cookTabs,
              children: [
                _CookOverviewTab(
                  userId: id,
                  profile: profile,
                  email: email,
                  chef: chef,
                  rawDetail: raw,
                  nextEnforcementLabel: nextLabel,
                  onTakeAction: nextLabel.isEmpty
                      ? null
                      : () => _takeCookEnforcement(context, id, nextLabel),
                  onOpenInspection: () => _goCookInspection(context),
                  onOpenOrders: () => _goOrders(context),
                  onOpenChat: () => _goChat(context),
                ),
                _CookDishesTab(cookId: id),
                _CookReelsTab(cookId: id),
                _CookOrdersTab(cookId: id),
                _CookDocumentsTab(cookId: id),
                _CookStatsTab(cookId: id, rawDetail: raw, chef: chef),
                _CookActivityTab(cookId: id),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            title: Text(name),
            actions: const [AdminSignOutIconButton()],
          ),
          body: _CustomerBody(
            userId: id,
            profile: profile,
            email: email,
            rawDetail: raw,
            onOpenOrders: () => _goOrders(context),
            onOpenChat: () => _goChat(context),
          ),
        );
      },
    );
  }
}

class _CustomerBody extends ConsumerWidget {
  const _CustomerBody({
    required this.userId,
    required this.profile,
    required this.email,
    required this.rawDetail,
    required this.onOpenOrders,
    required this.onOpenChat,
  });

  final String userId;
  final Map<String, dynamic> profile;
  final String email;
  final Map<String, dynamic> rawDetail;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final stats = _asJsonMap(rawDetail['order_stats']) ?? {};
    final total = (stats['total'] as num?)?.toInt() ?? 0;
    final completed = (stats['completed'] as num?)?.toInt() ?? 0;
    final cancelled = (stats['cancelled'] as num?)?.toInt() ?? 0;
    final revenue = (stats['completed_revenue'] as num?)?.toDouble() ?? 0.0;
    final conv = (rawDetail['conversation_count'] as num?)?.toInt() ?? 0;
    final lastAt = _parseDt(rawDetail['last_order_activity_at']);
    final favs = rawDetail['favorite_cooks'];
    final blocked = profile['is_blocked'] == true;
    final roleEnum = adminUserRoleFromDbRole(_str(profile['role']));
    final ordersAsync = ref.watch(adminCustomerOrdersDetailProvider(userId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (roleEnum != null) AdminRoleBadge(role: roleEnum),
            CookAccountStateBadge(
              display: blocked
                  ? const CookAccountStateDisplay(state: CookAccountState.blocked, subtitle: 'Account blocked')
                  : const CookAccountStateDisplay(state: CookAccountState.clean),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _CustomerBody._kv('Name', _str(profile['full_name'])),
        _CustomerBody._kv('Email', email.isEmpty ? '—' : email),
        _CustomerBody._kv('Phone', _str(profile['phone'])),
        _CustomerBody._kv('User ID', userId),
        const SizedBox(height: 20),
        Text('Orders summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _CustomerBody._statCard(context, 'Total', '$total', Icons.receipt_long_outlined)),
            const SizedBox(width: 8),
            Expanded(child: _CustomerBody._statCard(context, 'Completed', '$completed', Icons.check_circle_outline)),
            const SizedBox(width: 8),
            Expanded(child: _CustomerBody._statCard(context, 'Cancelled', '$cancelled', Icons.cancel_outlined)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Completed revenue', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      Text(
                        '${revenue.toStringAsFixed(2)} SAR',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Recent orders', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ordersAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, _) => Text(userFriendlyErrorMessage(e)),
          data: (rows) {
            if (rows.isEmpty) {
              return Text('No orders yet.', style: TextStyle(color: scheme.onSurfaceVariant));
            }
            final slice = rows.take(12).toList();
            return Column(
              children: [
                for (final r in slice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AdminOrdersScreen.orderMonitoringCard(
                      context,
                      r: r,
                      onTap: () {
                        final oid = (r['id'] ?? '').toString();
                        if (oid.isEmpty) return;
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(builder: (_) => AdminOrderDetailScreen(orderId: oid)),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text('Cooks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _FavoriteCooksList(raw: favs),
        const SizedBox(height: 20),
        Text('Chat summary', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _CustomerBody._kv('Conversations', '$conv'),
        const SizedBox(height: 8),
        Text(
          'Last activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          lastAt != null ? DateFormat.yMMMd().add_jm().format(lastAt.toLocal()) : '—',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenOrders,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Orders'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Open chat',
              onPressed: onOpenChat,
              icon: const Icon(Icons.forum_outlined),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  static Widget _statCard(BuildContext context, String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCooksList extends StatelessWidget {
  const _FavoriteCooksList({required this.raw});

  final dynamic raw;

  @override
  Widget build(BuildContext context) {
    final fav = raw;
    if (fav is! List<dynamic>) {
      return Text('—', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    if (fav.isEmpty) {
      return Text('—', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    final tiles = <Widget>[];
    for (var i = 0; i < fav.length && tiles.length < 10; i++) {
      final e = fav[i];
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        tiles.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(_str(m['name'])),
            subtitle: Text('${_str(m['order_count'])} orders · ${_str(m['chef_id'])}'),
          ),
        );
      }
    }
    return Column(children: tiles);
  }
}

class _CookOverviewTab extends StatelessWidget {
  const _CookOverviewTab({
    required this.userId,
    required this.profile,
    required this.email,
    required this.chef,
    required this.rawDetail,
    required this.nextEnforcementLabel,
    required this.onTakeAction,
    required this.onOpenInspection,
    required this.onOpenOrders,
    required this.onOpenChat,
  });

  final String userId;
  final Map<String, dynamic> profile;
  final String email;
  final Map<String, dynamic>? chef;
  final Map<String, dynamic> rawDetail;
  /// Empty when profile is blocked or ladder complete.
  final String nextEnforcementLabel;
  final VoidCallback? onTakeAction;
  final VoidCallback onOpenInspection;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final blocked = profile['is_blocked'] == true;
    final wc = (chef?['warning_count'] as num?)?.toInt() ?? 0;
    final fu = _parseDt(chef?['freeze_until']);
    final cookState = cookAccountStateForProfile(
      isBlocked: blocked,
      warningCount: wc,
      freezeUntil: fu,
      freezeType: chef?['freeze_type']?.toString(),
    );
    final openOrders = _asJsonMap(rawDetail['cook_open_orders']);
    final pendingOrders = (openOrders?['pending'] as num?)?.toInt();
    final activeOrders = (openOrders?['active'] as num?)?.toInt();

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminRoleBadge(role: AdminUserRoleLabel.cook),
            if (blocked)
              Text(
                'Account blocked',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
              )
            else
              CookAccountStateBadge(display: cookState),
          ],
        ),
        const SizedBox(height: 16),
        Text('Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _CookOverviewTab._kv('Kitchen / name', _str(chef?['kitchen_name']).isEmpty ? _str(profile['full_name']) : _str(chef?['kitchen_name'])),
        _CookOverviewTab._kv('Full name', _str(profile['full_name'])),
        _CookOverviewTab._kv('Email', email.isEmpty ? '—' : email),
        _CookOverviewTab._kv('Phone', _str(profile['phone'])),
        _CookOverviewTab._kv('User ID', userId),
        const SizedBox(height: 16),
        Text('Cook account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _CookOverviewTab._kv('Approval status', _str(chef?['approval_status'])),
        _CookOverviewTab._kv('Suspended', '${chef?['suspended'] == true}'),
        _CookOverviewTab._kv('Open now', '${chef?['is_online'] == true}'),
        _CookOverviewTab._kv('Vacation mode', '${chef?['vacation_mode'] == true}'),
        if (fu != null && fu.isAfter(DateTime.now())) ...[
          _CookOverviewTab._kv(
            'Freeze type',
            (chef?['freeze_type']?.toString().toLowerCase().trim() == 'hard') ? 'Hard freeze' : 'Soft freeze',
          ),
          _CookOverviewTab._kv('Frozen until', DateFormat.yMMMd().add_jm().format(fu.toLocal())),
          if (_parseDt(chef?['freeze_started_at']) != null)
            _CookOverviewTab._kv(
              'Freeze started',
              DateFormat.yMMMd().add_jm().format(_parseDt(chef?['freeze_started_at'])!.toLocal()),
            ),
          if (_str(chef?['freeze_reason']).isNotEmpty)
            _CookOverviewTab._kv('Freeze reason', _str(chef?['freeze_reason'])),
        ],
        if (pendingOrders != null && activeOrders != null) ...[
          _CookOverviewTab._kv('Pending orders (now)', '$pendingOrders'),
          _CookOverviewTab._kv('Active orders (now)', '$activeOrders'),
        ],
        _CookOverviewTab._kv('Working hours', _workingHoursSummary(chef)),
        if (_str(chef?['suspension_reason']).isNotEmpty)
          _CookOverviewTab._kv('Suspension note', _str(chef?['suspension_reason'])),
        if (chef != null) _CookOverviewTab._kv('Freeze level', '${(chef!['freeze_level'] as num?)?.toInt() ?? 0}'),
        const SizedBox(height: 20),
        Text('Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Live kitchen inspections: record an outcome only — penalties are automatic. '
          'The button below is the general escalation ladder (one step per click), not the inspection flow.',
          style: TextStyle(fontSize: 12, height: 1.35, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onOpenInspection,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('View Approvals'),
            ),
            FilledButton.tonalIcon(
              onPressed: onOpenOrders,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View Orders'),
            ),
            IconButton.filledTonal(
              tooltip: 'Open chat',
              onPressed: onOpenChat,
              icon: const Icon(Icons.forum_outlined),
            ),
            if (onTakeAction != null && nextEnforcementLabel.isNotEmpty)
              FilledButton.icon(
                onPressed: onTakeAction,
                icon: const Icon(Icons.gavel_rounded),
                label: Text('Take Action · $nextEnforcementLabel'),
              ),
          ],
        ),
      ],
    );
  }

  static String _workingHoursSummary(Map<String, dynamic>? chef) {
    if (chef == null) return '—';
    final wh = chef['working_hours'];
    if (wh is Map && wh.isNotEmpty) {
      return wh.entries.map((e) => '${e.key}: ${e.value}').take(4).join('\n');
    }
    final a = _str(chef['working_hours_start']);
    final b = _str(chef['working_hours_end']);
    if (a.isEmpty && b.isEmpty) return '—';
    return '$a – $b';
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.black54, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _CookDishesTab extends ConsumerWidget {
  const _CookDishesTab({required this.cookId});

  final String cookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCookMenuWithOrderCountsProvider(cookId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFriendlyErrorMessage(e))),
      data: (rows) {
        if (rows.isEmpty) return const Center(child: Text('No dishes'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final price = (r['price'] as num?)?.toDouble();
            final oc = (r['_order_count'] as num?)?.toInt() ?? 0;
            return ListTile(
              title: Text(_str(r['name'])),
              subtitle: Text('Sold (completed orders): $oc · Available: ${r['is_available'] == true}'),
              trailing: Text(price != null ? price.toStringAsFixed(2) : '—'),
            );
          },
        );
      },
    );
  }
}

class _CookReelsTab extends ConsumerWidget {
  const _CookReelsTab({required this.cookId});

  final String cookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCookReelsDetailProvider(cookId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFriendlyErrorMessage(e))),
      data: (rows) {
        if (rows.isEmpty) return const Center(child: Text('No reels'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = rows[i];
            final id = _str(r['id']);
            final thumb = r['thumbnail_url'] as String?;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 72,
                        height: 96,
                        child: thumb != null && thumb.isNotEmpty
                            ? Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.movie),
                                ),
                              )
                            : const ColoredBox(
                                color: Colors.black12,
                                child: Icon(Icons.movie),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_str(r['caption']).isEmpty ? 'Reel' : _str(r['caption']), maxLines: 2),
                          const SizedBox(height: 8),
                          Text('Reports: not tracked in list view', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove reel',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: id.isEmpty
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove reel'),
                                  content: const Text('Delete this reel from the app?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (ok != true || !context.mounted) return;
                              try {
                                await ref.read(reelsRepositoryProvider).deleteReel(id);
                                ref.invalidate(adminCookReelsDetailProvider(cookId));
                                ref.invalidate(adminReelsListProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel removed')));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(userFriendlyErrorMessage(e))),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

enum _CookOrdersSlice { all, active, completed, cancelled }

class _CookOrdersTab extends ConsumerStatefulWidget {
  const _CookOrdersTab({required this.cookId});

  final String cookId;

  @override
  ConsumerState<_CookOrdersTab> createState() => _CookOrdersTabState();
}

class _CookOrdersTabState extends ConsumerState<_CookOrdersTab> {
  _CookOrdersSlice _slice = _CookOrdersSlice.all;

  bool _matchesSlice(String statusRaw) {
    final s = statusRaw.trim();
    switch (_slice) {
      case _CookOrdersSlice.all:
        return true;
      case _CookOrdersSlice.active:
        return OrderDbStatus.isInKitchenDbStatus(s) || OrderDbStatus.pending.contains(s);
      case _CookOrdersSlice.completed:
        return s == 'completed';
      case _CookOrdersSlice.cancelled:
        return OrderDbStatus.cancelled.contains(s) || s == 'rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminCookOrdersDetailProvider(widget.cookId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFriendlyErrorMessage(e))),
      data: (rows) {
        final filtered = rows.where((r) => _matchesSlice((r['status'] ?? '').toString())).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _slice == _CookOrdersSlice.all,
                    onSelected: (_) => setState(() => _slice = _CookOrdersSlice.all),
                  ),
                  ChoiceChip(
                    label: const Text('Active'),
                    selected: _slice == _CookOrdersSlice.active,
                    onSelected: (_) => setState(() => _slice = _CookOrdersSlice.active),
                  ),
                  ChoiceChip(
                    label: const Text('Completed'),
                    selected: _slice == _CookOrdersSlice.completed,
                    onSelected: (_) => setState(() => _slice = _CookOrdersSlice.completed),
                  ),
                  ChoiceChip(
                    label: const Text('Cancelled'),
                    selected: _slice == _CookOrdersSlice.cancelled,
                    onSelected: (_) => setState(() => _slice = _CookOrdersSlice.cancelled),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No orders in this filter'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = filtered[i];
                        final id = (r['id'] ?? '').toString();
                        return AdminOrdersScreen.orderMonitoringCard(
                          context,
                          r: r,
                          onTap: id.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AdminOrderDetailScreen(orderId: id),
                                    ),
                                  );
                                },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CookDocumentsTab extends ConsumerWidget {
  const _CookDocumentsTab({required this.cookId});

  final String cookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCookDocumentsDetailProvider(cookId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFriendlyErrorMessage(e))),
      data: (rows) {
        if (rows.isEmpty) return const Center(child: Text('No documents'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            return Card(
              child: ListTile(
                title: Text(CookRequiredDocumentTypes.displayLabelForRawDocumentType(_str(r['document_type']))),
                subtitle: Text(
                  'Status: ${_str(r['status'])}\nExpires: ${_str(r['expiry_date'])}\nUpdated: ${_str(r['updated_at'])}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _CookStatsTab extends ConsumerWidget {
  const _CookStatsTab({required this.cookId, required this.rawDetail, required this.chef});

  final String cookId;
  final Map<String, dynamic> rawDetail;
  final Map<String, dynamic>? chef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _asJsonMap(rawDetail['order_stats']) ?? {};
    final total = (stats['total'] as num?)?.toInt() ?? 0;
    final completed = (stats['completed'] as num?)?.toInt() ?? 0;
    final cancelled = (stats['cancelled'] as num?)?.toInt() ?? 0;
    final revenue = (stats['completed_revenue'] as num?)?.toDouble() ?? 0.0;
    final rating = (chef?['rating_avg'] as num?)?.toDouble();
    final completionPct = total > 0 ? (100 * completed / total).toStringAsFixed(1) : '—';
    final cancelPct = total > 0 ? (100 * cancelled / total).toStringAsFixed(1) : '—';
    final topAsync = ref.watch(adminCookTopDishesProvider(cookId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Performance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _CookOverviewTab._kv('Total orders (DB)', '$total'),
        _CookOverviewTab._kv('Completed orders', '$completed'),
        _CookOverviewTab._kv('Cancelled / rejected', '$cancelled'),
        _CookOverviewTab._kv('Completion rate', total > 0 ? '$completionPct%' : '—'),
        _CookOverviewTab._kv('Cancellation rate', total > 0 ? '$cancelPct%' : '—'),
        _CookOverviewTab._kv('Total revenue (completed)', revenue.toStringAsFixed(2)),
        _CookOverviewTab._kv('Rating (profile)', rating != null ? rating.toStringAsFixed(2) : '—'),
        _CookOverviewTab._kv('Recorded warnings', '${(chef?['warning_count'] as num?)?.toInt() ?? 0}'),
        const SizedBox(height: 20),
        Text('Top dishes (completed orders)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        topAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(userFriendlyErrorMessage(e)),
          data: (lines) {
            if (lines.isEmpty) {
              return Text(
                'No completed order lines with dish_name for this cook (check order_items).',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < lines.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(_str(lines[i]['dish_name'])),
                    trailing: Text('× ${(lines[i]['quantity_sold'] as num?)?.toInt() ?? 0}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CookActivityTab extends ConsumerWidget {
  const _CookActivityTab({required this.cookId});

  final String cookId;

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'account':
        return Icons.person_outline;
      case 'approval':
        return Icons.verified_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'reel':
        return Icons.movie_outlined;
      case 'dish':
        return Icons.restaurant_outlined;
      case 'audit':
        return Icons.fact_check_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(adminCookActivityTimelineProvider(cookId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFriendlyErrorMessage(e))),
      data: (events) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Timeline merges profile, documents, reels, dishes, and admin audit lines from get_admin_logs_for_cook '
                  '(run supabase_admin_moderation_extensions.sql). Actions should call log_admin_action with payload.chef_id.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Text('No activity rows yet.', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              for (final e in events)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(_iconFor(_str(e['kind'])), color: scheme.onPrimaryContainer, size: 20),
                    ),
                    title: Text(_str(e['title']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${_str(e['subtitle'])}\n${_str(e['at'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                  ),
                ),
          ],
        );
      },
    );
  }
}

