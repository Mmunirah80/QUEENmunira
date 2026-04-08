import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/chef/cook_freeze_display.dart';
import '../../data/models/chef_doc_model.dart';

/// Cook-facing freeze notice (English). Refreshes countdown periodically.
class CookFreezeBanner extends StatefulWidget {
  const CookFreezeBanner({super.key, required this.chefDoc});

  final ChefDocModel chefDoc;

  @override
  State<CookFreezeBanner> createState() => _CookFreezeBannerState();
}

class _CookFreezeBannerState extends State<CookFreezeBanner> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.chefDoc.freezeUntil;
    if (until == null || !until.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    final hard = widget.chefDoc.isHardFreezeActive;
    final mode = CookFreezeDisplay.freezeModeLabel(widget.chefDoc.freezeType);
    final planned = CookFreezeDisplay.freezePeriodPlannedLabel(
      freezeStartedAt: widget.chefDoc.freezeStartedAt,
      freezeUntil: until,
      freezeType: widget.chefDoc.freezeType,
    );
    final reason = widget.chefDoc.freezeReason?.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ac_unit_rounded, size: 20, color: Color(0xFF0369A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  planned != null ? '$planned · $mode' : 'Frozen · $mode',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CookFreezeDisplay.timeRemainingVerbose(until),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Until ${CookFreezeDisplay.frozenUntilDate(until)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          const Text(
            'You cannot receive new orders during this period.',
            style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF334155)),
          ),
          if (hard) ...[
            const SizedBox(height: 6),
            const Text(
              'A hard freeze is in effect. You cannot accept new orders or advance active orders. '
              'You may still reject pending orders. Contact support if an order needs escalation.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF334155)),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'You can complete current active orders.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF334155)),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: $reason',
              style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }
}
