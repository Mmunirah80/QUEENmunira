import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/menu_supabase_datasource.dart';
import '../../data/repositories/menu_repository_impl.dart';
import '../../domain/entities/dish_entity.dart';
import '../../domain/repositories/menu_repository.dart';

/// Chef-scoped Supabase menu datasource. Null when not logged in as chef.
final menuSupabaseDataSourceProvider = Provider<MenuSupabaseDataSource?>((ref) {
  final chefId = ref.watch(authStateProvider).valueOrNull?.id;
  if (chefId == null || chefId.isEmpty) return null;
  return MenuSupabaseDataSource(chefId: chefId);
});

/// Chef-side: fetch own dishes.
final dishesProvider = FutureProvider<List<DishEntity>>((ref) async {
  final repo = ref.watch(menuRepositoryProvider);
  return repo.getDishes();
});

/// Menu repository (create/update/delete/toggle). Uses Supabase when chef is logged in.
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final ds = ref.watch(menuSupabaseDataSourceProvider);
  if (ds == null) {
    throw UnimplementedError('Menu repository requires a logged-in chef');
  }
  return MenuRepositoryImpl(remoteDataSource: ds);
});