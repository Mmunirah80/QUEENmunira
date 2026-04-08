import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/supabase_error_message.dart';
import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';
import '../presentation/widgets/admin_pending_cook_documents_panel.dart';
import 'admin_compliance_overview_screen.dart';
import 'admin_inspection_assigned_screen.dart';

/// Cook document review + random live kitchen inspection (server-side eligibility).
///
/// When [embedded] is true (inside [AdminUsersHubScreen]), no outer [Scaffold].
class AdminInspectionsScreen extends ConsumerStatefulWidget {
  const AdminInspectionsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AdminInspectionsScreen> createState() => _AdminInspectionsScreenState();
}

class _AdminInspectionsScreenState extends ConsumerState<AdminInspectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      ref.read(adminInspectionTabProvider.notifier).state = _tab.index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final want = ref.read(adminInspectionTabProvider).clamp(0, 2);
      if (_tab.index != want) {
        _tab.index = want;
      }
      ref.read(adminPendingCookDocumentsNotifierProvider.notifier).refresh();
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await ref.read(adminSupabaseDatasourceProvider).fetchInspectionCallsForAdmin(limit: 40);
      if (!mounted) return;
      setState(() => _history = rows);
    } catch (e, st) {
      debugPrint('[AdminInspections] history: $e\n$st');
    }
  }

  Future<void> _startRandomInspection() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = ref.read(adminSupabaseDatasourceProvider);
      final call = await ds.startRandomInspectionCall();
      if (!mounted) return;
      final callId = (call['id'] ?? '').toString();
      final chefId = (call['chef_id'] ?? '').toString();
      final channel = (call['channel_name'] ?? '').toString();
      if (callId.isEmpty || chefId.isEmpty || channel.isEmpty) {
        throw Exception('Invalid inspection call payload');
      }
      final snap = await ds.fetchChefInspectionSnapshot(chefId);
      final cookName = (snap?['kitchen_name'] ?? '').toString().trim().isNotEmpty
          ? (snap!['kitchen_name'] ?? '').toString().trim()
          : chefId;
      final viol = (snap?['inspection_penalty_step'] as num?)?.toInt() ??
          (snap?['inspection_violation_count'] as num?)?.toInt() ??
          0;
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminInspectionAssignedScreen(
            callId: callId,
            chefId: chefId,
            chefName: cookName,
            channelName: channel,
            inspectionViolationCountBefore: viol,
          ),
        ),
      );
      if (!context.mounted) return;
      await _loadHistory();
      ref.invalidate(adminInspectionViolationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = adminInspectionFriendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openComplianceOverview() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AdminComplianceOverviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(adminInspectionTabProvider, (prev, next) {
      if (!mounted || _tab.indexIsChanging) return;
      final i = next.clamp(0, 2);
      if (_tab.index != i) {
        _tab.animateTo(i);
      }
    });
    final scheme = Theme.of(context).colorScheme;
    final inspectionTabBar = TabBar(
      controller: _tab,
      tabs: const [
        Tab(text: 'Queue'),
        Tab(text: 'Overview'),
        Tab(text: 'History'),
      ],
    );
    final dashboardTab = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.dashboard_customize_rounded, size: 44, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            'Inspection dashboard',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a random live session, review eligibility rules, and open the violations ledger.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openComplianceOverview,
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('Compliance & violations overview'),
          ),
          const SizedBox(height: 8),
          Text(
            'Lists automatic penalties from [chef_violations] (warning / freeze steps).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const SizedBox(height: 24),
          Text(
            'Random live inspection',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'The platform picks one eligible chef fairly. You cannot choose a kitchen manually. '
            'Among eligible cooks, the one with the longest time since their last completed inspection is preferred '
            '(ties broken at random). Eligibility: approved account, online, within working hours, not on vacation, '
            'not frozen or suspended, no active inspection, at least 7 days since any completed inspection, '
            'and fewer than 3 completed inspections in the last 30 days. Each session stores an audit snapshot.',
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: scheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer, fontSize: 13, height: 1.35),
                  ),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _loading ? null : _startRandomInspection,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.shuffle_rounded),
            label: Text(_loading ? 'Starting…' : 'Start random inspection'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
    final historyTab = RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent sessions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_history.isEmpty)
              const AdminEmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No inspection sessions yet',
                subtitle: 'Pull to refresh after you complete inspections, or start a random inspection.',
              )
            else
              ..._history.map((r) => _historyTile(context, r)),
          ],
        ),
      ),
    );
    final inspectionBody = TabBarView(
      controller: _tab,
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: const [
            Text(
              'Application queue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Review each document slot with View, Approve, or Reject. Statuses follow the cook verification pipeline.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 20),
            AdminPendingCookDocumentsPanel(compact: true),
          ],
        ),
        dashboardTab,
        historyTab,
      ],
    );
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(color: scheme.surface, child: inspectionTabBar),
          Expanded(child: inspectionBody),
        ],
      );
    }
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Inspection'),
        bottom: inspectionTabBar,
        actions: const [AdminSignOutIconButton()],
      ),
      body: inspectionBody,
    );
  }

  Widget _historyTile(BuildContext context, Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final st = (r['status'] ?? '—').toString();
    final out = (r['outcome'] ?? r['result_action'] ?? '—').toString();
    final chef = (r['chef_id'] ?? '').toString();
    final short = chef.length > 8 ? '${chef.substring(0, 8)}…' : chef;
    final when = (r['created_at'] ?? '—').toString();
    final audit = _auditLineFromSelection(r['selection_context']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$st · $out', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        isThreeLine: audit != null,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chef $short · $when', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            if (audit != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  audit,
                  style: TextStyle(fontSize: 11, height: 1.3, color: scheme.outline),
                ),
              ),
          ],
        ),
        dense: true,
      ),
    );
  }

  /// One line from [selection_context] JSON (server-side eligibility snapshot at pick time).
  static String? _auditLineFromSelection(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final sel = m['selection'];
    if (sel is! Map) return null;
    final pool = sel['eligible_pool_size'];
    final method = sel['method']?.toString();
    if (pool == null && method == null) return null;
    final parts = <String>[];
    if (method != null && method.isNotEmpty) parts.add(method);
    if (pool != null) parts.add('pool $pool');
    return parts.isEmpty ? null : 'At selection: ${parts.join(' · ')}';
  }
}
