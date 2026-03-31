import 'dart:math' as math;

import '../../features/cook/data/models/chef_doc_model.dart';

/// Max straight-line distance for showing a cook on the customer home (pickup only).
const double kMaxPickupRadiusKm = 20.0;

/// Min distance shown in UI (500 m) — avoids tiny "34 m" labels; still real Haversine underneath.
const double kMinPickupDisplayKm = 0.5;

/// Max label cap (matches [kMaxPickupRadiusKm]).
const double kMaxPickupDisplayKm = kMaxPickupRadiusKm;

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}

double _rad(double deg) => deg * math.pi / 180.0;

/// Always kilometers, one decimal. Clamped to [kMinPickupDisplayKm]…[kMaxPickupDisplayKm].
String formatPickupDistanceKm(double km) {
  if (km.isNaN || km < 0) {
    return '${kMinPickupDisplayKm.toStringAsFixed(1)} km';
  }
  final clamped = km < kMinPickupDisplayKm
      ? kMinPickupDisplayKm
      : (km > kMaxPickupDisplayKm ? kMaxPickupDisplayKm : km);
  return '${clamped.toStringAsFixed(1)} km';
}

class ChefWithPickupDistance {
  final ChefDocModel chef;
  final double? distanceKm;

  const ChefWithPickupDistance(this.chef, this.distanceKm);
}

/// Cooks accepting storefront orders (vacation / hours / open-now): within [kMaxPickupRadiusKm]
/// sorted nearest first;
/// then cooks without coordinates (demo / legacy rows).
List<ChefWithPickupDistance> buildPickupSortedChefs(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
) {
  final within = <ChefWithPickupDistance>[];
  final noCoord = <ChefWithPickupDistance>[];
  for (final c in chefs) {
    if (!c.storefrontEvaluation.isAcceptingOrders) continue;
    final lat = c.kitchenLatitude;
    final lng = c.kitchenLongitude;
    if (lat != null && lng != null) {
      final d = haversineKm(customerLat, customerLng, lat, lng);
      if (d <= kMaxPickupRadiusKm) {
        within.add(ChefWithPickupDistance(c, d));
      }
    } else {
      noCoord.add(ChefWithPickupDistance(c, null));
    }
  }
  within.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
  return [...within, ...noCoord];
}

/// Chef ids visible in the same scope as the home "nearby" list.
Set<String> pickupVisibleChefIds(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
) {
  return buildPickupSortedChefs(chefs, customerLat, customerLng)
      .map((e) => e.chef.chefId)
      .whereType<String>()
      .toSet();
}

/// Distance from customer pin to [chef]'s kitchen; null if cook has no coordinates.
String? pickupDistanceLabelForChef(
  ChefDocModel chef,
  double customerLat,
  double customerLng,
) {
  final lat = chef.kitchenLatitude;
  final lng = chef.kitchenLongitude;
  if (lat == null || lng == null) return null;
  final km = haversineKm(customerLat, customerLng, lat, lng);
  return formatPickupDistanceKm(km);
}

/// Chef id → formatted distance for dish cards / lists.
Map<String, String> pickupDistanceLabelsByChefId(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
) {
  final m = <String, String>{};
  for (final e in buildPickupSortedChefs(chefs, customerLat, customerLng)) {
    final id = e.chef.chefId;
    if (id != null && e.distanceKm != null) {
      m[id] = formatPickupDistanceKm(e.distanceKm!);
    }
  }
  return m;
}
