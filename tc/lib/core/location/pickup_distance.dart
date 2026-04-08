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

/// Same as [formatPickupDistanceKm] but does not cap at [kMaxPickupRadiusKm] (for "whole city" browse).
String formatDistanceKmNatural(double km) {
  if (km.isNaN || km < 0) {
    return '${kMinPickupDisplayKm.toStringAsFixed(1)} km';
  }
  final clamped = km < kMinPickupDisplayKm ? kMinPickupDisplayKm : km;
  return '${clamped.toStringAsFixed(1)} km';
}

/// Straight-line distance for chef cards / lists (e.g. "3.2 km away").
String formatDistanceKmAway(double km) => '${formatDistanceKmNatural(km)} away';

int _compareKitchenName(ChefDocModel a, ChefDocModel b) {
  final na = (a.kitchenName ?? '').toLowerCase();
  final nb = (b.kitchenName ?? '').toLowerCase();
  return na.compareTo(nb);
}

String normalizeKitchenCityKey(String? s) => (s ?? '').trim().toLowerCase();

/// Maps geocode / DB city strings to a comparable key (matches [chef_profiles.kitchen_city] variants).
String normalizeSaudiCityKey(String? s) {
  final t = normalizeKitchenCityKey(s);
  if (t.isEmpty) return '';
  if (t.contains('riyadh')) return 'riyadh';
  if (t.contains('jeddah') || t.contains('jiddah')) return 'jeddah';
  if (t.contains('dammam')) return 'dammam';
  if (t.contains('makkah') || t.contains('mecca')) return 'makkah';
  if (t.contains('madinah') || t.contains('medina')) return 'madinah';
  if (t.contains('khobar') || t.contains('al khobar')) return 'khobar';
  return t;
}

/// Cooks in the same city as [userCity] ([chef_profiles.kitchen_city]), sorted by distance from pickup when coords exist.
List<ChefWithPickupDistance> buildCityScopeChefs(
  List<ChefDocModel> chefs,
  String? userCity,
  double customerLat,
  double customerLng,
) {
  final target = normalizeSaudiCityKey(userCity);
  if (target.isEmpty) return [];
  final withDist = <ChefWithPickupDistance>[];
  final noCoord = <ChefWithPickupDistance>[];
  for (final c in chefs) {
    if (!c.storefrontEvaluation.isAcceptingOrders) continue;
    final kc = normalizeSaudiCityKey(c.kitchenCity);
    if (kc.isEmpty || kc != target) continue;
    final lat = c.kitchenLatitude;
    final lng = c.kitchenLongitude;
    if (lat != null && lng != null) {
      final d = haversineKm(customerLat, customerLng, lat, lng);
      withDist.add(ChefWithPickupDistance(c, d));
    } else {
      noCoord.add(ChefWithPickupDistance(c, null));
    }
  }
  withDist.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
  noCoord.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  return [...withDist, ...noCoord];
}

/// Home browse: prefer kitchens in the same city as the pickup pin (reverse-geocode), nearest first.
/// If no city could be resolved or no chefs match that city, falls back to [kMaxPickupRadiusKm] radius sort.
List<ChefWithPickupDistance> buildHomeSortedChefs(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  final cityKey = normalizeSaudiCityKey(pickupLocalityCity);
  if (cityKey.isNotEmpty) {
    final byCity = buildCityScopeChefs(chefs, pickupLocalityCity, customerLat, customerLng);
    if (byCity.isNotEmpty) return byCity;
  }
  return buildPickupSortedChefs(
    chefs,
    customerLat,
    customerLng,
    pickupLocalityCity: pickupLocalityCity,
  );
}

/// Same visibility rules as [buildHomeSortedChefs] for a single chef (cross-checks).
///
/// [pickupLocalityCity] must come from the customer’s pickup pin (e.g. reverse-geocode
/// [CustomerPickupOrigin.localityCity]), **not** from `profiles.city`.
bool chefVisibleForCustomerHome(
  ChefDocModel chef,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  return buildHomeSortedChefs([chef], customerLat, customerLng, pickupLocalityCity).isNotEmpty;
}

/// Same as [chefVisibleForCustomerHome] — used by Reels so they share **exactly** the same scope as Home.
bool chefVisibleForHomeAndReels(
  ChefDocModel chef,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) =>
    chefVisibleForCustomerHome(chef, customerLat, customerLng, pickupLocalityCity);

// ─── Customer reels feed (region + chef standing; NOT storefront hours/online) ───

/// Public reels: approved, not suspended, not in an active freeze (matches DB guard on reels SELECT).
bool chefReelAccountEligibleForPublicFeed(ChefDocModel chef) {
  if (chef.suspended) return false;
  if ((chef.approvalStatus ?? '').toLowerCase().trim() != 'approved') return false;
  if (chef.isFreezeActive) return false;
  return true;
}

/// Same city / radius rules as [buildHomeSortedChefs] but **without** [ChefStorefrontEvaluation.isAcceptingOrders]
/// (reels follow kitchen location even when the storefront is closed).
List<ChefWithPickupDistance> buildCityScopeChefsForReels(
  List<ChefDocModel> chefs,
  String? userCity,
  double customerLat,
  double customerLng,
) {
  final target = normalizeSaudiCityKey(userCity);
  if (target.isEmpty) return [];
  final withDist = <ChefWithPickupDistance>[];
  final noCoord = <ChefWithPickupDistance>[];
  for (final c in chefs) {
    final kc = normalizeSaudiCityKey(c.kitchenCity);
    if (kc.isEmpty || kc != target) continue;
    final lat = c.kitchenLatitude;
    final lng = c.kitchenLongitude;
    if (lat != null && lng != null) {
      final d = haversineKm(customerLat, customerLng, lat, lng);
      withDist.add(ChefWithPickupDistance(c, d));
    } else {
      noCoord.add(ChefWithPickupDistance(c, null));
    }
  }
  withDist.sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
  noCoord.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  return [...withDist, ...noCoord];
}

/// Pickup-radius + no-coord ordering for reels (no storefront / online filter).
List<ChefWithPickupDistance> buildPickupSortedChefsForReels(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng, {
  String? pickupLocalityCity,
}) {
  final cityKey = normalizeSaudiCityKey(pickupLocalityCity);
  final within = <ChefWithPickupDistance>[];
  final noCoord = <ChefWithPickupDistance>[];
  for (final c in chefs) {
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

  if (cityKey.isEmpty) {
    noCoord.sort((a, b) => _compareKitchenName(a.chef, b.chef));
    return [...within, ...noCoord];
  }

  final noCoordSameArea = <ChefWithPickupDistance>[];
  final noCoordOther = <ChefWithPickupDistance>[];
  for (final e in noCoord) {
    final kc = normalizeSaudiCityKey(e.chef.kitchenCity);
    if (kc.isEmpty || kc == cityKey) {
      noCoordSameArea.add(e);
    } else {
      noCoordOther.add(e);
    }
  }
  noCoordSameArea.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  noCoordOther.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  return [...within, ...noCoordSameArea, ...noCoordOther];
}

/// Geographic “region” for reels: same as Home city/radius scope, without storefront gating.
List<ChefWithPickupDistance> buildHomeSortedChefsForReels(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  final cityKey = normalizeSaudiCityKey(pickupLocalityCity);
  if (cityKey.isNotEmpty) {
    final byCity = buildCityScopeChefsForReels(chefs, pickupLocalityCity, customerLat, customerLng);
    if (byCity.isNotEmpty) return byCity;
  }
  return buildPickupSortedChefsForReels(
    chefs,
    customerLat,
    customerLng,
    pickupLocalityCity: pickupLocalityCity,
  );
}

bool chefReelGeographyMatches(
  ChefDocModel chef,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  return buildHomeSortedChefsForReels([chef], customerLat, customerLng, pickupLocalityCity).isNotEmpty;
}

/// Customer reels feed: kitchen region + approved + not frozen + reel flags handled separately.
bool chefReelVisibleToCustomer(
  ChefDocModel chef,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  if (!chef.hasKitchenMapPin) return false;
  if (!chefReelAccountEligibleForPublicFeed(chef)) return false;
  return chefReelGeographyMatches(chef, customerLat, customerLng, pickupLocalityCity);
}

class ChefWithPickupDistance {
  final ChefDocModel chef;
  final double? distanceKm;

  const ChefWithPickupDistance(this.chef, this.distanceKm);
}

/// Single line for chef/dish UI: straight-line distance, or city/area fallback when the kitchen has no pin.
String chefDistanceOrAreaLabel(ChefWithPickupDistance entry, String? pickupLocalityCity) {
  final km = entry.distanceKm;
  if (km != null) {
    return formatDistanceKmAway(km);
  }
  return chefNoDistanceLocationHint(entry.chef, pickupLocalityCity);
}

/// When [chef_profiles.kitchen_latitude/longitude] are missing — prefer same normalized city as pickup, else show city name.
String chefNoDistanceLocationHint(ChefDocModel chef, String? pickupLocalityCity) {
  final pk = normalizeSaudiCityKey(pickupLocalityCity);
  final ck = normalizeSaudiCityKey(chef.kitchenCity);
  if (pk.isNotEmpty && ck.isNotEmpty && pk == ck) {
    return 'Same area';
  }
  final raw = chef.kitchenCity?.trim() ?? '';
  if (raw.isNotEmpty) return raw;
  return 'No map location';
}

/// Cooks accepting storefront orders: those with kitchen coordinates within [kMaxPickupRadiusKm],
/// sorted by actual distance (nearest first). Cooks without coordinates are listed after, ordered by
/// [pickupLocalityCity] match ([chef_profiles.kitchen_city]) then kitchen name — so city/area is the
/// fallback when distance cannot be computed.
List<ChefWithPickupDistance> buildPickupSortedChefs(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng, {
  String? pickupLocalityCity,
}) {
  final cityKey = normalizeSaudiCityKey(pickupLocalityCity);
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

  if (cityKey.isEmpty) {
    noCoord.sort((a, b) => _compareKitchenName(a.chef, b.chef));
    return [...within, ...noCoord];
  }

  final noCoordSameArea = <ChefWithPickupDistance>[];
  final noCoordOther = <ChefWithPickupDistance>[];
  for (final e in noCoord) {
    final kc = normalizeSaudiCityKey(e.chef.kitchenCity);
    if (kc.isEmpty || kc == cityKey) {
      noCoordSameArea.add(e);
    } else {
      noCoordOther.add(e);
    }
  }
  noCoordSameArea.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  noCoordOther.sort((a, b) => _compareKitchenName(a.chef, b.chef));
  return [...within, ...noCoordSameArea, ...noCoordOther];
}

/// Chef ids visible in the same scope as Home ([buildHomeSortedChefs]).
Set<String> pickupVisibleChefIds(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng, {
  String? pickupLocalityCity,
}) {
  return buildHomeSortedChefs(chefs, customerLat, customerLng, pickupLocalityCity)
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

/// Chef id → distance/area line for dish cards / lists (same ordering as [buildHomeSortedChefs]).
Map<String, String> pickupDistanceLabelsByChefId(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng, {
  String? pickupLocalityCity,
}) {
  final m = <String, String>{};
  for (final e in buildHomeSortedChefs(chefs, customerLat, customerLng, pickupLocalityCity)) {
    final id = e.chef.chefId;
    if (id != null && id.isNotEmpty) {
      m[id] = chefDistanceOrAreaLabel(e, pickupLocalityCity);
    }
  }
  return m;
}
