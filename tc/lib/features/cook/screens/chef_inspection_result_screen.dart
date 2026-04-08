import 'package:flutter/material.dart';

/// Full-screen summary after the server finalizes an inspection (outcome + automatic penalty).
class ChefInspectionResultScreen extends StatelessWidget {
  const ChefInspectionResultScreen({
    super.key,
    required this.outcome,
    required this.resultAction,
    this.resultNote,
    this.violationReason,
  });

  final String outcome;
  final String resultAction;
  final String? resultNote;
  final String? violationReason;

  String get _body {
    final note = (resultNote ?? '').trim();
    final noteLine = note.isEmpty ? '' : '\n\nNote: $note';

    if (outcome == 'passed' || resultAction == 'pass') {
      return 'This inspection was marked as passed. Thank you for cooperating.$noteLine';
    }
    if (outcome == 'admin_technical_issue' || resultAction == 'admin_technical_issue') {
      return 'The session ended due to a platform or technical issue. This does not count against your record.$noteLine';
    }
    if (resultAction == 'warning') {
      return 'A warning has been recorded on your account following this inspection. '
          'Please keep your kitchen compliant with platform standards.$noteLine';
    }
    if (resultAction == 'freeze_3d' || resultAction == 'freeze_7d' || resultAction == 'freeze_14d') {
      final days = switch (resultAction) {
        'freeze_3d' => '3',
        'freeze_7d' => '7',
        _ => '14',
      };
      return 'Your account is frozen for $days days after this inspection outcome. '
          'Customers cannot place new orders until the freeze ends. You can still use Profile and support chat.$noteLine';
    }
    final readable = switch (outcome) {
      'no_answer' => 'Marked as no answer',
      'kitchen_not_clean' => 'Kitchen cleanliness / compliance issue',
      'refused_inspection' => 'Inspection was declined',
      _ => outcome.isNotEmpty ? outcome : resultAction,
    };
    return 'Inspection update: $readable.$noteLine';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection result')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            outcome == 'passed' || resultAction == 'pass' ? Icons.check_circle_outline : Icons.info_outline_rounded,
            size: 56,
            color: scheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            _body,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          if ((violationReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reason code: ${violationReason!.trim()}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
