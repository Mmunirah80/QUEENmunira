import 'package:flutter/material.dart';

import 'admin_inspection_live_screen.dart';

/// Shown immediately after the server assigns a chef to a random inspection.
/// Admin reviews who was picked, then opens the live viewer (admin never controls the chef camera).
class AdminInspectionAssignedScreen extends StatelessWidget {
  const AdminInspectionAssignedScreen({
    super.key,
    required this.callId,
    required this.chefId,
    required this.chefName,
    required this.channelName,
    this.inspectionViolationCountBefore = 0,
  });

  final String callId;
  final String chefId;
  final String chefName;
  final String channelName;
  final int inspectionViolationCountBefore;

  Future<void> _openLive(BuildContext context) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminInspectionLiveScreen(
          callId: callId,
          chefId: chefId,
          chefName: chefName,
          channelName: channelName,
          inspectionViolationCountBefore: inspectionViolationCountBefore,
        ),
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned chef'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.person_search_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              chefName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'The platform selected this kitchen for a live inspection. '
              'When you continue, you join as a viewer only — the cook must accept the call and turn on their camera.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Session', callId.length > 12 ? '${callId.substring(0, 8)}…' : callId),
                    _row('Chef id', chefId.length > 12 ? '${chefId.substring(0, 8)}…' : chefId),
                    _row('Prior inspection violations', '$inspectionViolationCountBefore'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _openLive(context),
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Begin live session'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
