import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../menu/domain/entities/dish_entity.dart';
import '../../../menu/presentation/providers/menu_provider.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/chef_firebase_datasource.dart';
import '../../data/datasources/chef_presence_datasource.dart';
import '../../data/models/chef_doc_model.dart';

final chefPresenceDataSourceProvider = Provider<ChefPresenceDataSource>((ref) {
  return ChefPresenceDataSource();
});

final chefFirebaseDataSourceProvider = Provider<ChefFirebaseDataSource>((ref) {
  return ChefFirebaseDataSource();
});

/// Real-time chef doc (isOnline, workingHours, dailyCapacity, kitchenName). Requires chef login.
final chefDocStreamProvider = StreamProvider<ChefDocModel?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final chefId = user?.id;
  if (chefId == null || chefId.isEmpty) {
    return const Stream<ChefDocModel?>.empty();
  }
  final sb = SupabaseConfig.client;
  return sb
      .from('chef_profiles')
      .stream(primaryKey: ['id'])
      .eq('id', chefId)
      .map((rows) {
        if (rows.isEmpty) return null;
        final raw = rows.first;
        try {
          return ChefDocModel.fromSupabase(
            Map<String, dynamic>.from(raw as Map),
          );
        } catch (e, st) {
          debugPrint('[chefDocStream] parse error: $e\n$st');
          return null;
        }
      });
});

/// Real-time list of chef's dishes (from Supabase menu_items when chef is logged in).
final chefDishesStreamProvider = StreamProvider<List<DishEntity>>((ref) {
  final ds = ref.watch(menuSupabaseDataSourceProvider);
  if (ds == null) return const Stream.empty();
  return ds.watchChefDishes();
});
