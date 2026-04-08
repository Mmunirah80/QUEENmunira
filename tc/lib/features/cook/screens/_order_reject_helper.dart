import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_config.dart';

Future<String?> showRejectReasonSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              title: Text(
                'Reject order',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Divider(height: 1),
            _ReasonTile(label: 'Busy'),
            _ReasonTile(label: 'Item sold out'),
            _ReasonTile(label: 'Closed'),
            _ReasonTile(label: 'Other'),
            SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Legacy client-side stock restore after chef reject.
/// **Do not call** when using `transition_order_status`: the server runs
/// [restore_order_stock_once] and a second restore would double-count inventory.
@Deprecated('Server handles stock on reject/cancel via transition_order_status')
Future<void> restoreRejectedOrderQuantities(String orderId) async {
  try {
    final items = await SupabaseConfig.dataClient
        .from('order_items')
        .select('menu_item_id,quantity')
        .eq('order_id', orderId);
    for (final item in (items as List)) {
      final row = item as Map<String, dynamic>;
      final menuItemId = (row['menu_item_id'] ?? '').toString();
      final quantity = row['quantity'] is num
          ? (row['quantity'] as num).toInt()
          : int.tryParse('${row['quantity']}') ?? 0;
      if (menuItemId.isEmpty || quantity <= 0) continue;
      await SupabaseConfig.dataClient.rpc<dynamic>(
        'increase_remaining_quantity',
        params: {
          'p_dish_id': menuItemId,
          'p_quantity': quantity,
        },
      );
    }
  } catch (e) {
    debugPrint('[CookOrders] restore quantities error=$e');
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;

  const _ReasonTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.of(context).pop(label),
    );
  }
}
