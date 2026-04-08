import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../data/models/chef_doc_model.dart';

/// Non-freeze compliance notice when the cook has inspection violations on file.
class ChefInspectionComplianceBanner extends StatelessWidget {
  const ChefInspectionComplianceBanner({super.key, required this.chefDoc});

  final ChefDocModel chefDoc;

  @override
  Widget build(BuildContext context) {
    final n = chefDoc.inspectionViolationCount;
    if (n <= 0) return const SizedBox.shrink();
    if (chefDoc.isFreezeActive) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.policy_rounded, size: 20, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n == 1
                      ? 'Inspection compliance: 1 violation on record'
                      : 'Inspection compliance: $n violations on record',
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
          const Text(
            'Further issues can lead to automatic warnings or freezes. Open Inspection history for details.',
            style: TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push(RouteNames.chefComplianceHistory),
              child: const Text('Open inspection history'),
            ),
          ),
        ],
      ),
    );
  }
}
