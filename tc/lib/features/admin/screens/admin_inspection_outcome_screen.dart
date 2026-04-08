import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/inspection_outcome.dart';
import '../presentation/providers/admin_providers.dart';

/// Full-screen outcome capture. Admin chooses **outcome only**; penalties are computed on the server.
class AdminInspectionOutcomeScreen extends ConsumerStatefulWidget {
  const AdminInspectionOutcomeScreen({
    super.key,
    required this.callId,
    required this.chefName,
    required this.inspectionViolationCountBefore,
    this.callStatus,
    this.suggestedOutcome,
  });

  final String callId;
  final String chefName;
  final int inspectionViolationCountBefore;
  /// Raw [inspection_calls.status] when this screen opened (pending | accepted | declined | missed | …).
  final String? callStatus;
  final InspectionOutcome? suggestedOutcome;

  @override
  ConsumerState<AdminInspectionOutcomeScreen> createState() => _AdminInspectionOutcomeScreenState();
}

class _AdminInspectionOutcomeScreenState extends ConsumerState<AdminInspectionOutcomeScreen> {
  static const _outcomes = <InspectionOutcome>[
    InspectionOutcome.passed,
    InspectionOutcome.noAnswer,
    InspectionOutcome.kitchenNotClean,
    InspectionOutcome.refusedInspection,
    InspectionOutcome.adminTechnicalIssue,
  ];

  static String _label(InspectionOutcome o) => switch (o) {
        InspectionOutcome.passed => 'Passed — kitchen OK',
        InspectionOutcome.noAnswer => 'No answer (missed / no pickup)',
        InspectionOutcome.kitchenNotClean => 'Kitchen not clean / compliance issue',
        InspectionOutcome.refusedInspection => 'Refused inspection',
        InspectionOutcome.adminTechnicalIssue => 'Technical issue (does not count against chef)',
      };

  late InspectionOutcome _outcome;
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final st = (widget.callStatus ?? '').toLowerCase();
    if (widget.suggestedOutcome != null) {
      _outcome = widget.suggestedOutcome!;
    } else if (st == 'missed') {
      _outcome = InspectionOutcome.noAnswer;
    } else if (st == 'declined') {
      _outcome = InspectionOutcome.refusedInspection;
    } else {
      _outcome = InspectionOutcome.passed;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isViolation =>
      _outcome == InspectionOutcome.noAnswer ||
      _outcome == InspectionOutcome.kitchenNotClean ||
      _outcome == InspectionOutcome.refusedInspection;

  String _escalationPreview() {
    final n = widget.inspectionViolationCountBefore;
    final next = n + 1;
    if (next == 1) return 'If you record a countable violation, the next automatic step is: warning.';
    if (next == 2) return 'Next countable violation: automatic 3-day freeze.';
    if (next == 3) return 'Next countable violation: automatic 7-day freeze.';
    return 'Next countable violation: automatic 14-day freeze (maximum repeat).';
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(adminSupabaseDatasourceProvider).finalizeInspectionOutcome(
            callId: widget.callId,
            outcome: _outcome,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save outcome: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = (widget.callStatus ?? '—').toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection outcome')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.chefName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Session status when opened: $st',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Penalties are applied automatically by the platform. You only choose the outcome.',
            style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          if (_isViolation) ...[
            const SizedBox(height: 12),
            Material(
              color: scheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_escalationPreview(), style: const TextStyle(fontSize: 12, height: 1.35)),
              ),
            ),
          ],
          const SizedBox(height: 20),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Outcome'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InspectionOutcome>(
                value: _outcome,
                isExpanded: true,
                items: _outcomes
                    .map((e) => DropdownMenuItem(value: e, child: Text(_label(e))))
                    .toList(),
                onChanged: _submitting ? null : (v) => setState(() => _outcome = v ?? InspectionOutcome.passed),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
              hintText: 'Short context for the audit log',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit outcome'),
          ),
        ],
      ),
    );
  }
}
