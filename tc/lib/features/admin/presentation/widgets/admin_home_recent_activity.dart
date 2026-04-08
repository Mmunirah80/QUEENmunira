import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/admin_providers.dart';
import 'admin_design_system_widgets.dart';
import '../../screens/admin_orders_screen.dart';

/// Compact recent orders strip for Home (no heavy operational blocks).
class AdminHomeRecentActivity extends ConsumerWidget {
  const AdminHomeRecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardRecentOrdersSampleProvider);
    final scheme = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Text('Could not load activity', style: TextStyle(fontSize: 12, color: scheme.error)),
      data: (rows) {
        final slice = rows.take(5).toList();
        if (slice.isEmpty) {
          return Text(
            'No orders yet',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < slice.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Builder(
                builder: (ctx) {
                  final r = slice[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadius),
                      onTap: () {
                        final id = (r['id'] ?? '').toString();
                        if (id.isEmpty) return;
                        Navigator.of(ctx).push<void>(
                          MaterialPageRoute<void>(builder: (_) => AdminOrderDetailScreen(orderId: id)),
                        );
                      },
                      child: Ink(
                        decoration: AdminPanelTokens.surfaceCard(ctx, scheme),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AdminPanelTokens.space16,
                            vertical: AdminPanelTokens.space12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '#${_shortId((r['id'] ?? '').toString())} · ${AdminOrdersScreen.statusLabel((r['status'] ?? '').toString())}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _shortTime(r['updated_at'] ?? r['created_at']),
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  static String _shortId(String id) {
    if (id.isEmpty) return '—';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  static String _shortTime(dynamic v) {
    final t = DateTime.tryParse(v?.toString() ?? '');
    if (t == null) return '—';
    return DateFormat.MMMd().add_jm().format(t.toLocal());
  }
}
