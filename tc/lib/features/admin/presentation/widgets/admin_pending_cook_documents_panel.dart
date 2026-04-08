import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/supabase_error_message.dart';
import '../../../../core/validation/naham_validators.dart';
import '../../../cook/data/cook_required_document_types.dart';
import '../../domain/admin_application_review_logic.dart';
import '../../services/admin_actions_service.dart';
import '../providers/admin_providers.dart';
import 'admin_document_preview.dart';

/// Pending cook applications: grouped by chef, per-document review with preview.
class AdminPendingCookDocumentsPanel extends ConsumerStatefulWidget {
  const AdminPendingCookDocumentsPanel({super.key, this.compact = false});

  /// When true, uses tighter padding (e.g. inside a tab).
  final bool compact;

  @override
  ConsumerState<AdminPendingCookDocumentsPanel> createState() =>
      _AdminPendingCookDocumentsPanelState();
}

class _AdminPendingCookDocumentsPanelState extends ConsumerState<AdminPendingCookDocumentsPanel> {
  String? _busyDocId;
  String? _busyOp;

  bool _busyApprove(String id) => _busyDocId == id && _busyOp == 'approve';
  bool _busyReject(String id) => _busyDocId == id && _busyOp == 'reject';

  String _chefIdForDocument(String documentId) {
    for (final g in ref.read(adminPendingCookDocumentsNotifierProvider).groups) {
      for (final r in g.documents) {
        if ((r['id'] ?? '').toString() == documentId) {
          return (r['chef_id'] ?? g.chefId).toString();
        }
      }
    }
    return '';
  }

  Future<void> _approve(String documentId) async {
    if (_busyDocId != null) return;
    final chefId = _chefIdForDocument(documentId);
    if (chefId.isEmpty) return;
    setState(() {
      _busyDocId = documentId;
      _busyOp = 'approve';
    });
    try {
      await ref.read(adminActionsServiceProvider).approveCookDocument(
            context,
            documentId: documentId,
            chefId: chefId,
          );
    } finally {
      if (mounted) {
        setState(() {
          _busyDocId = null;
          _busyOp = null;
        });
      }
    }
  }

  Future<void> _reject(String documentId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const AdminCookDocReasonDialog(
        title: 'Reject document',
        confirmLabel: 'Reject',
        fieldLabel: 'Reason',
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _applyRejected(documentId: documentId, reason: reason);
  }

  Future<void> _applyRejected({required String documentId, required String reason}) async {
    if (_busyDocId != null) return;
    final chefId = _chefIdForDocument(documentId);
    if (chefId.isEmpty) return;
    setState(() {
      _busyDocId = documentId;
      _busyOp = 'reject';
    });
    try {
      await ref.read(adminActionsServiceProvider).submitCookDocumentRejection(
            context,
            documentId: documentId,
            chefId: chefId,
            reason: reason,
          );
    } finally {
      if (mounted) {
        setState(() {
          _busyDocId = null;
          _busyOp = null;
        });
      }
    }
  }

  String _expiryLine(Object? expiryRaw, Object? noExpiryRaw) {
    if (noExpiryRaw == true) return 'No expiry';
    if (expiryRaw == null) return 'Expiry not set';
    return expiryRaw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(adminPendingCookDocumentsNotifierProvider);
    final notifier = ref.read(adminPendingCookDocumentsNotifierProvider.notifier);
    final pad = widget.compact ? 12.0 : 16.0;
    final scheme = Theme.of(context).colorScheme;
    const actionHeight = 40.0;

    if (st.initialLoading && st.groups.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (st.error != null && st.groups.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load applications',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => notifier.refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (st.groups.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Text(
            'No pending applications',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final titleCount = st.hasMore ? '${st.groups.length}+' : '${st.groups.length}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Pending ($titleCount)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          st.hasMore ? 'Load more for older kitchens' : 'Grouped by kitchen · newest activity first',
        ),
        children: [
          if (st.error != null && st.groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                userFriendlyErrorMessage(st.error!),
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          for (final g in st.groups) ...[
            _buildApplicationCard(
              context,
              scheme: scheme,
              group: g,
              actionHeight: actionHeight,
            ),
            const SizedBox(height: 8),
          ],
          if (st.hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: st.loadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () => notifier.loadMore(),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load more'),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context, {
    required ColorScheme scheme,
    required AdminPendingApplicationGroup group,
    required double actionHeight,
  }) {
    final bySlot = latestRequiredDocumentRowsBySlot(group.documents);

    DateTime? firstSubmitted;
    DateTime? lastActivity;
    for (final r in bySlot.values) {
      final c = DateTime.tryParse((r['created_at'] ?? '').toString());
      if (c == null) continue;
      if (firstSubmitted == null || c.isBefore(firstSubmitted)) {
        firstSubmitted = c;
      }
      if (lastActivity == null || c.isAfter(lastActivity)) {
        lastActivity = c;
      }
    }
    String fmt(DateTime? d) => d?.toIso8601String().split('T').first ?? '—';
    final submittedStr = fmt(firstSubmitted);
    final lastStr = fmt(lastActivity);

    final stats = countDocumentStatuses(bySlot.values);
    final overall = computeApplicationOverallStatus(bySlot);
    final overallLabel = formatOverallStatusLabel(overall);
    final displayName = group.applicantName.trim().isNotEmpty ? group.applicantName : group.kitchenName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              if (group.kitchenName.trim().isNotEmpty && group.kitchenName != displayName) ...[
                const SizedBox(height: 2),
                Text(
                  group.kitchenName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Role: Cook',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                'First submitted: $submittedStr',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                'Last activity: $lastStr',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Text(
                'Documents',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              for (final slot in CookRequiredDocumentTypes.requiredSlots) ...[
                _documentRow(
                  context,
                  scheme: scheme,
                  slot: slot,
                  row: bySlot[slot],
                  actionHeight: actionHeight,
                ),
                const SizedBox(height: 16),
              ],
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _miniStat('Approved', stats.approved, scheme.primary),
                  _miniStat('Pending', stats.pending, scheme.tertiary),
                  _miniStat('Rejected', stats.rejected, scheme.error),
                  Chip(
                    label: Text('Overall: $overallLabel'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Text(
      '$label: $value',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }

  Widget _documentRow(
    BuildContext context, {
    required ColorScheme scheme,
    required String slot,
    required Map<String, dynamic>? row,
    required double actionHeight,
  }) {
    final id = (row?['id'] ?? '').toString();
    final busyA = _busyApprove(id);
    final busyR = _busyReject(id);
    final rowBusy = busyA || busyR;
    final label = CookRequiredDocumentTypes.labelForSlot(slot);
    final chipLabel = adminDocumentStatusChipLabel(row);
    final needsDecision = row != null && documentRowNeedsAdminDecision(row);
    final locked = row != null && documentRowIsLockedApproved(row);
    final rejection = (row?['rejection_reason'] ?? '').toString().trim();
    final fileUrl = row?['file_url']?.toString();
    final hasFile = fileUrl != null && fileUrl.trim().isNotEmpty;
    final expiry = row?['expiry_date'];
    final noExpiry = row?['no_expiry'];

    Color chipColor = scheme.onSurfaceVariant;
    if (chipLabel == 'Approved') chipColor = scheme.primary;
    if (chipLabel == 'Needs resubmission' || chipLabel == 'Expired') chipColor = scheme.error;
    if (chipLabel == 'Pending') chipColor = scheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            Chip(
              label: Text(chipLabel),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: chipColor.withValues(alpha: 0.35)),
              labelStyle: TextStyle(fontSize: 13, color: chipColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (row == null) ...[
          const SizedBox(height: 4),
          Text(
            'Not uploaded yet',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ] else ...[
          const SizedBox(height: 4),
          _line(Icons.event_outlined, 'Expiry', _expiryLine(expiry, noExpiry)),
        ],
        if (rejection.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Reason: $rejection',
            style: TextStyle(fontSize: 12, color: scheme.error, height: 1.25),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: actionHeight,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, actionHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: row != null && hasFile
                      ? () => openCookDocumentPreview(context, fileUrl)
                      : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined, size: 18),
                      SizedBox(width: 6),
                      Text('View'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, actionHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: rowBusy || id.isEmpty || !needsDecision || locked
                      ? null
                      : () => _approve(id),
                  child: busyA
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, actionHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: rowBusy || id.isEmpty || !needsDecision || locked
                      ? null
                      : () => _reject(id),
                  child: busyR
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reject'),
                ),
              ),
            ],
          ),
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Approved — the cook can upload a new version only for this slot.',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ),
      ],
    );
  }

  static Widget _line(IconData icon, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.25),
                children: [
                  TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: v),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared reason dialog for cook document reject / resubmission flows.
class AdminCookDocReasonDialog extends StatefulWidget {
  const AdminCookDocReasonDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.hint,
    this.fieldLabel,
  });

  final String title;
  final String confirmLabel;
  final String? hint;
  final String? fieldLabel;

  @override
  State<AdminCookDocReasonDialog> createState() => _AdminCookDocReasonDialogState();
}

class _AdminCookDocReasonDialogState extends State<AdminCookDocReasonDialog> {
  final TextEditingController _reason = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _reason,
          decoration: InputDecoration(
            labelText: widget.fieldLabel ?? 'Rejection reason (required)',
            hintText: widget.hint ?? 'Explain what is wrong and what the cook should fix.',
            helperText: 'Minimum 5 characters.',
          ),
          maxLines: 4,
          autofocus: true,
          validator: NahamValidators.adminDocumentRejectionReason,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, _reason.text.trim());
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
