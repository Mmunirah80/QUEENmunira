import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/snackbar_helper.dart';
import '../providers/admin_providers.dart';

/// Punishment: Strike 1 → Warning only. 2 → Frozen 3d. 3 → Frozen 7d. 4 → Frozen 14d. 5 → Block.
const List<String> _punishments = [
  'تحذير فقط',
  'تجميد 3 أيام',
  'تجميد 7 أيام',
  'تجميد 14 يوماً',
  'حظر دائم',
];

class ChefViolationHistoryScreen extends ConsumerStatefulWidget {
  final String chefId;
  final String chefName;

  const ChefViolationHistoryScreen({super.key, required this.chefId, required this.chefName});

  @override
  ConsumerState<ChefViolationHistoryScreen> createState() => _ChefViolationHistoryScreenState();
}

class _ChefViolationHistoryScreenState extends ConsumerState<ChefViolationHistoryScreen> {
  Map<String, dynamic>? _chefDoc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ds = ref.read(adminFirebaseDataSourceProvider);
    setState(() => _loading = true);
    try {
      final doc = await ds.getChefDoc(widget.chefId);
      if (mounted) setState(() {
        _chefDoc = doc;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int get _strikeCount => (_chefDoc?['strikeCount'] as num?)?.toInt() ?? 0;
  String get _chefStatus => _chefDoc?['chefStatus'] as String? ?? 'active';
  List<dynamic> get _history => _chefDoc?['violationHistory'] as List<dynamic>? ?? [];

  Future<void> _issueWarning() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إصدار تحذير'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب التحذير',
            hintText: 'أدخل السبب',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إصدار'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      SnackbarHelper.error(context, 'أدخل سبب التحذير');
      return;
    }
    final nextStrike = _strikeCount + 1;
    if (nextStrike > 5) {
      SnackbarHelper.error(context, 'الطاهي محظور بالفعل');
      return;
    }
    final punishment = _punishments[nextStrike - 1];
    DateTime? frozenUntil;
    String chefStatus = 'active';
    if (nextStrike == 2) {
      frozenUntil = DateTime.now().add(const Duration(days: 3));
    } else if (nextStrike == 3) {
      frozenUntil = DateTime.now().add(const Duration(days: 7));
    } else if (nextStrike == 4) {
      frozenUntil = DateTime.now().add(const Duration(days: 14));
    } else if (nextStrike == 5) {
      chefStatus = 'blocked';
    }
    try {
      await ref.read(adminFirebaseDataSourceProvider).applyViolation(
            chefId: widget.chefId,
            reason: reason,
            newStrikeCount: nextStrike,
            punishment: punishment,
            frozenUntil: frozenUntil,
            chefStatus: chefStatus,
          );
      if (mounted) {
        SnackbarHelper.success(context, 'تم إصدار التحذير');
        _load();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: NahamTheme.headerBackground,
          foregroundColor: Colors.white,
          title: Text('سجل المخالفات - ${widget.chefName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _loading
            ? const Center(child: LoadingWidget())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('خطأ: $_error', style: const TextStyle(color: AppDesignSystem.errorRed), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDesignSystem.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StatusCard(
                          strikeCount: _strikeCount,
                          chefStatus: _chefStatus,
                          frozenUntil: _chefDoc?['frozenUntil'] != null ? _parseFrozen(_chefDoc!['frozenUntil']) : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('سجل المخالفات', style: Theme.of(context).textTheme.titleLarge),
                            if (_strikeCount < 5)
                              FilledButton.icon(
                                onPressed: _issueWarning,
                                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                                label: const Text('إصدار تحذير'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppDesignSystem.warningOrange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_history.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('لا توجد مخالفات مسجلة')),
                            ),
                          )
                        else
                          ..._history.asMap().entries.map((e) {
                            final i = e.key;
                            final h = e.value as Map<String, dynamic>;
                            final date = h['date'];
                            String dateStr = '—';
                            if (date != null) {
                              DateTime? dt;
                              if (date is Timestamp) dt = date.toDate();
                              if (date is DateTime) dt = date;
                              if (dt != null) dateStr = '${dt.year}/${dt.month}/${dt.day}';
                            }
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(h['reason'] as String? ?? '—'),
                                subtitle: Text('${h['punishment'] as String? ?? '—'} · $dateStr'),
                                leading: CircleAvatar(
                                  backgroundColor: NahamTheme.primary.withValues(alpha: 0.2),
                                  child: Text('${i + 1}', style: const TextStyle(color: NahamTheme.primary, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }

  DateTime? _parseFrozen(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    return null;
  }
}

class _StatusCard extends StatelessWidget {
  final int strikeCount;
  final String chefStatus;
  final DateTime? frozenUntil;

  const _StatusCard({required this.strikeCount, required this.chefStatus, this.frozenUntil});

  @override
  Widget build(BuildContext context) {
    String statusText = chefStatus == 'active' ? 'نشط' : chefStatus == 'blocked' ? 'محظور' : 'مجمد';
    if (frozenUntil != null) statusText += ' حتى ${frozenUntil!.year}/${frozenUntil!.month}/${frozenUntil!.day}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الحالة الحالية', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: NahamTheme.textOnLight)),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text('التحذيرات: $strikeCount/5'),
                  backgroundColor: strikeCount >= 5 ? AppDesignSystem.errorRed.withValues(alpha: 0.2) : NahamTheme.cardBackground,
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(statusText),
                  backgroundColor: chefStatus == 'blocked' ? AppDesignSystem.errorRed.withValues(alpha: 0.2) : NahamTheme.cardBackground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
