import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:naham_cook_app/core/constants/route_names.dart';
import 'package:naham_cook_app/core/utils/supabase_error_message.dart';
import 'package:naham_cook_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:naham_cook_app/features/admin/presentation/widgets/admin_design_system_widgets.dart';
import 'package:naham_cook_app/features/admin/services/admin_actions_service.dart';
import 'package:naham_cook_app/features/admin/screens/admin_reels_vertical_feed_screen.dart';

/// Reels: [All] feed and [Reported] queue (minimal filters).
class AdminReelsScreen extends ConsumerStatefulWidget {
  const AdminReelsScreen({super.key});

  @override
  ConsumerState<AdminReelsScreen> createState() => _AdminReelsScreenState();
}

class _AdminReelsScreenState extends ConsumerState<AdminReelsScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchCtrl;
  late final TabController _tabCtrl;
  Timer? _searchDebounce;

  void _syncReelsFilterToTab() {
    if (_tabCtrl.indexIsChanging || !mounted) return;
    ref.read(adminReelsModerationFilterProvider.notifier).state =
        _tabCtrl.index == 1 ? AdminReelsModerationFilter.reported : AdminReelsModerationFilter.all;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_syncReelsFilterToTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchCtrl.text = ref.read(adminReelsSearchQueryProvider);
      final f = ref.read(adminReelsModerationFilterProvider);
      if (f == AdminReelsModerationFilter.reported) {
        _tabCtrl.index = 1;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabCtrl.removeListener(_syncReelsFilterToTab);
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _applySearch() {
    ref.read(adminReelsSearchQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  void _onSearchTextChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), _applySearch);
  }

  static int _reportCount(Map<String, dynamic> r) => (r['report_count'] as num?)?.toInt() ?? 0;

  static DateTime _created(Map<String, dynamic> r) {
    return DateTime.tryParse((r['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<Map<String, dynamic>> _filterBySearchQuery(List<Map<String, dynamic>> rows, String searchQ) {
    final q = searchQ.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) {
      final cap = (r['caption'] ?? '').toString().toLowerCase();
      final cook = (r['_kitchen_name'] ?? r['chef_id'] ?? '').toString().toLowerCase();
      final id = (r['id'] ?? '').toString().toLowerCase();
      return cap.contains(q) || cook.contains(q) || id.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _filterAll(List<Map<String, dynamic>> rows, String searchQ) {
    final list = List<Map<String, dynamic>>.from(rows);
    list.sort((a, b) => _created(b).compareTo(_created(a)));
    return _filterBySearchQuery(list, searchQ);
  }

  List<Map<String, dynamic>> _filterReported(List<Map<String, dynamic>> rows, String searchQ) {
    final list = rows.where((r) => _reportCount(r) > 0).toList();
    list.sort((a, b) {
      final rb = _reportCount(b);
      final ra = _reportCount(a);
      if (rb != ra) return rb.compareTo(ra);
      return _created(b).compareTo(_created(a));
    });
    return _filterBySearchQuery(list, searchQ);
  }

  Future<void> _confirmDelete(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    final chefId = (r['chef_id'] ?? '').toString();
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reel'),
        content: const Text('Delete this reel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final actions = ref.read(adminActionsServiceProvider);
    final success = await actions.deleteReel(context, reelId: id, chefId: chefId);
    if (success && mounted) ref.invalidate(adminReelsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final async = ref.watch(adminReelsListProvider);
    final appliedSearch = ref.watch(adminReelsSearchQueryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Reels'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Reported'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Vertical feed (swipe)',
            icon: const Icon(Icons.swipe_vertical_rounded),
            onPressed: () {
              final rows = ref.read(adminReelsListProvider).valueOrNull ?? [];
              final q = ref.read(adminReelsSearchQueryProvider);
              final visible =
                  _tabCtrl.index == 1 ? _filterReported(rows, q) : _filterAll(rows, q);
              if (visible.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No reels to show in this tab')),
                );
                return;
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AdminReelsVerticalFeedScreen(rows: visible),
                ),
              );
            },
          ),
          const AdminSignOutIconButton(),
        ],
      ),
      body: async.when(
        loading: () => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading reels…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AdminEmptyState(
              icon: Icons.video_library_outlined,
              title: 'No reels available',
              subtitle: 'Uploaded reels will show here for moderation.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search caption, cook, or ID',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => _onSearchTextChanged(),
                        onSubmitted: (_) {
                          _searchDebounce?.cancel();
                          _applySearch();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _applySearch();
                      },
                    ),
                    if (appliedSearch.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(adminReelsSearchQueryProvider.notifier).state = '';
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    Builder(
                      builder: (context) {
                        final visible = _filterAll(rows, appliedSearch);
                        if (visible.isEmpty) {
                          return const AdminEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching reels',
                            subtitle: 'Try another search term.',
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = visible[i];
                            return _AllReelCard(
                              row: r,
                              onCookTap: (chefId) {
                                if (chefId.isEmpty) return;
                                context.push(RouteNames.adminUserDetail(chefId));
                              },
                              onDelete: () => _confirmDelete(r),
                            );
                          },
                        );
                      },
                    ),
                    Builder(
                      builder: (context) {
                        final visible = _filterReported(rows, appliedSearch);
                        if (visible.isEmpty) {
                          return AdminEmptyState(
                            icon: Icons.flag_outlined,
                            title: appliedSearch.trim().isEmpty
                                ? 'No reported reels'
                                : 'No matching reported reels',
                            subtitle: appliedSearch.trim().isEmpty
                                ? 'When users report content, it will appear here.'
                                : 'Try clearing search.',
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final r = visible[i];
                            return _ReportedReelCard(
                              row: r,
                              onCookTap: (chefId) {
                                if (chefId.isEmpty) return;
                                context.push(RouteNames.adminUserDetail(chefId));
                              },
                              onDelete: () => _confirmDelete(r),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AllReelCard extends StatelessWidget {
  const _AllReelCard({
    required this.row,
    required this.onCookTap,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final void Function(String chefId) onCookTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cookName = (row['_kitchen_name'] ?? row['chef_id'] ?? 'Cook').toString();
    final chefId = (row['chef_id'] ?? '').toString();
    final caption = (row['caption'] ?? '').toString();
    final thumb = row['thumbnail_url'] as String?;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 240,
            child: thumb != null && thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.movie_outlined, size: 48)),
                    ),
                  )
                : const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: Icon(Icons.movie_outlined, size: 48)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => onCookTap(chefId),
                        child: Text(
                          cookName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Cook',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AdminUiColors.cookOnSurface,
                        ),
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.25),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: chefId.isEmpty ? null : () => onCookTap(chefId),
                  child: const Text('View'),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportedReelCard extends StatelessWidget {
  const _ReportedReelCard({
    required this.row,
    required this.onCookTap,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final void Function(String chefId) onCookTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cookName = (row['_kitchen_name'] ?? row['chef_id'] ?? 'Cook').toString();
    final chefId = (row['chef_id'] ?? '').toString();
    final reason = (row['report_reason_preview'] ?? '').toString().trim();
    final reasonLine = reason.isNotEmpty ? 'Reported for: $reason' : 'Reported for: (no reason given)';
    final thumb = row['thumbnail_url'] as String?;
    final scheme = Theme.of(context).colorScheme;
    final reports = (row['report_count'] as num?)?.toInt() ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 120,
                child: thumb != null && thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.flag_outlined),
                        ),
                      )
                    : const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.flag_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => onCookTap(chefId),
                    child: Text(
                      cookName,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: scheme.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Cook', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AdminUiColors.cookOnSurface)),
                  const SizedBox(height: 8),
                  Text(
                    reasonLine,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                  if (reports > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$reports reports',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: chefId.isEmpty ? null : () => onCookTap(chefId),
                          child: const Text('View'),
                        ),
                        TextButton(
                          onPressed: onDelete,
                          child: const Text('Delete'),
                        ),
                      ],
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
}
