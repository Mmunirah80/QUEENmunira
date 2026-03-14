import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/naham_empty_screens.dart';
import '../data/models/order_model.dart';
import '../providers/admin_providers.dart';
import '../core/utils/extensions.dart';

class OrdersManagementScreen extends ConsumerStatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  ConsumerState<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends ConsumerState<OrdersManagementScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'إدارة الطلبات')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.space16),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'بحث برقم الطلب أو اسم العميل...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
                  ),
                ),
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(allOrdersProvider);
              return async.when(
                data: (orders) {
                  final filtered = _query.isEmpty
                      ? orders
                      : orders.where((o) =>
                            o.customerName.toLowerCase().contains(_query.toLowerCase()) ||
                            o.id.toLowerCase().contains(_query.toLowerCase())).toList();
                  if (filtered.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: NahamEmptyStateContent(
                          title: 'لا توجد طلبات',
                          subtitle: 'الطلبات ستظهر هنا.',
                          buttonLabel: 'تحديث',
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _OrderTile(order: filtered[i]),
                      childCount: filtered.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(child: LoadingWidget()),
                error: (e, st) => SliverFillRemaining(
                  child: ErrorStateContent(message: e.toString()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDesignSystem.space16, vertical: AppDesignSystem.space8),
      child: ListTile(
        title: Text(order.customerName),
        subtitle: Text(
          '${order.totalAmount.toStringAsFixed(0)} ر.س • ${order.createdAt.formattedDateTime}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Chip(
          label: Text(order.status.name),
          backgroundColor: NahamTheme.cardBackground,
        ),
        onTap: () => _showOrderDetails(context),
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusCard),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppDesignSystem.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلب #${order.id}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('العميل: ${order.customerName}'),
            Text('المجموع: ${order.totalAmount.toStringAsFixed(0)} ر.س'),
            Text('الحالة: ${order.status.name}'),
            if (order.deliveryAddress != null) Text('العنوان: ${order.deliveryAddress}'),
          ],
        ),
      ),
    );
  }
}
