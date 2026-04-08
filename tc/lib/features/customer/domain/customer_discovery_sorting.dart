import '../../../core/location/pickup_distance.dart';
import '../../menu/domain/entities/dish_entity.dart';

/// Sorts dishes by the same chef order as [sortedChefs] (nearest first), then by dish name.
List<DishEntity> sortDishesByChefDistanceOrder(
  List<DishEntity> dishes,
  List<ChefWithPickupDistance> sortedChefs,
) {
  final order = <String, int>{};
  for (var i = 0; i < sortedChefs.length; i++) {
    final id = sortedChefs[i].chef.chefId;
    if (id != null && id.isNotEmpty) order[id] = i;
  }
  final out = List<DishEntity>.from(dishes);
  out.sort((a, b) {
    final oa = order[a.chefId ?? ''] ?? 9999;
    final ob = order[b.chefId ?? ''] ?? 9999;
    final c = oa.compareTo(ob);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  });
  return out;
}
