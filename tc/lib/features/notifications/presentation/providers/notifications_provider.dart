import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class ChefNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  ChefNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory ChefNotification.fromMap(Map<String, dynamic> map) {
    DateTime parseAt(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final idRaw = map['id'];
    return ChefNotification(
      id: idRaw == null ? '' : idRaw.toString(),
      title: (map['title'] as String?) ?? 'Notification',
      body: (map['body'] as String?) ?? '',
      createdAt: parseAt(map['created_at']),
      isRead: map['is_read'] as bool? ?? false,
    );
  }
}

/// Chef + customer recipients share [notifications.customer_id] (legacy column name).
/// Uses an initial REST load + Postgres realtime so it works even if `.stream()` is misconfigured.
final chefNotificationsProvider =
    StreamProvider.autoDispose<List<ChefNotification>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final chefId = user?.id;
  if (chefId == null || chefId.isEmpty) {
    return Stream.value(const []);
  }

  final client = Supabase.instance.client;
  final controller = StreamController<List<ChefNotification>>.broadcast();

  Future<void> load() async {
    try {
      final rows = await client
          .from('notifications')
          .select()
          .eq('customer_id', chefId)
          .order('created_at', ascending: false);
      final list = (rows as List)
          .map((e) => ChefNotification.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
      if (!controller.isClosed) controller.add(list);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    }
  }

  final channel = client.channel('chef-notifications-$chefId');
  void scheduleReload() {
    scheduleMicrotask(load);
  }

  channel
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: chefId,
      ),
      callback: (_) => scheduleReload(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: chefId,
      ),
      callback: (_) => scheduleReload(),
    )
    ..subscribe();

  scheduleMicrotask(load);

  ref.onDispose(() async {
    await channel.unsubscribe();
    await controller.close();
  });

  return controller.stream;
});
