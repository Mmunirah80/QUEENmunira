import 'package:flutter/material.dart';

import '../core/theme/app_design_system.dart';
import '../core/widgets/naham_screen_header.dart';

class CashManagementScreen extends StatelessWidget {
  const CashManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'إدارة النقد والمدفوعات')),
          SliverPadding(
            padding: const EdgeInsets.all(AppDesignSystem.space24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignSystem.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مدفوعات بانتظار الموافقة',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _PaymentRow(
                          label: 'سحب من الطباخ أحمد - 500 ر.س',
                          date: '2025-03-01',
                          onApprove: () {},
                          onReject: () {},
                        ),
                        const Divider(),
                        _PaymentRow(
                          label: 'سحب من الطباخة فاطمة - 1,200 ر.س',
                          date: '2025-02-28',
                          onApprove: () {},
                          onReject: () {},
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تحديث القائمة'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignSystem.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص اليوم',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي المبيعات', style: Theme.of(context).textTheme.bodyLarge),
                            Text('3,450 ر.س', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppDesignSystem.successGreen)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('عمولات معلقة', style: Theme.of(context).textTheme.bodyLarge),
                            Text('345 ر.س', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentRow({
    required this.label,
    required this.date,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Text(date, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded),
            color: AppDesignSystem.successGreen,
            onPressed: onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded),
            color: AppDesignSystem.errorRed,
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
