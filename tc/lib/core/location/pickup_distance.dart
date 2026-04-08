import 'dart:math' as math;

import '../../features/cook/data/models/chef_doc_model.dart';

/// When reverse-geocode did not yield a city, only kitchens within this straight-line
/// distance (km) from the pickup pin are listed (pickup-only safety net).
const double kFallbackBrowseRadiusWhenCityUnknownKm = 100.0;

/// Min distance shown in UI (500 m) — avoids tiny "34 m" labels; still real Haversine underneath.
const double kMinPickupDisplayKm = 0.5;

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

/// Kilometers, one decimal; floors at [kMinPickupDisplayKm] only (no upper cap — same-city kitchens can be >20 km away).
String formatPickupDistanceKm(double km) {
  if (km.isNaN || km < 0) {
    return '${kMinPickupDisplayKm.toStringAsFixed(1)} km';
  }
  final clamped = km < kMinPickupDisplayKm ? kMinPickupDisplayKm : km;
  return '${clamped.toStringAsFixed(1)} km';
}

/// Same as [formatPickupDistanceKm] (kept for call sites that want explicit "natural" naming).
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
  // Arabic + English + common district strings (e.g. "شمال الرياض" → Riyadh).
  if (t.contains('riyadh') || t.contains('الرياض')) return 'riyadh';
  if (t.contains('jeddah') || t.contains('jiddah') || t.contains('جدة') || t.contains('جده')) {
    return 'jeddah';
  }
  if (t.contains('dammam') || t.contains('الدمام')) return 'dammam';
  if (t.contains('makkah') || t.contains('mecca') || t.contains('مكة')) return 'makkah';
  if (t.contains('madinah') || t.contains('medina') || t.contains('المدينة')) return 'madinah';
  if (t.contains('khobar') || t.contains('al khobar') || t.contains('الخبر') || t.contains('خبر')) {
    return 'khobar';
  }
  if (t.contains('taif') || t.contains('الطائف')) return 'taif';
  return t;
}

/// Pickup pin is in greater Riyadh (covers district-only geocodes like "Al Olaya" that do not contain "Riyadh").
bool pickupCoordinatesLikelyRiyadh(double lat, double lng) {
  return lat >= 24.15 && lat <= 25.75 && lng >= 45.95 && lng <= 47.45;
}

/// Riyadh home browse: match [chef_profiles.kitchen_city] by substring (not only normalized equality).
bool kitchenCityTextIndicatesRiyadh(String? kitchenCity) {
  final s = (kitchenCity ?? '').trim();
  if (s.isEmpty) return false;
  if (s.toLowerCase().contains('riyadh')) return true;
  return s.contains('الرياض');
}

/// Geography match for home lists when customer browse resolves to [customerCityKey] ([normalizeSaudiCityKey]).
bool homeKitchenMatchesBrowseCity(String? kitchenCity, String customerCityKey) {
  if (customerCityKey.isEmpty) return false;
  if (customerCityKey == 'riyadh') {
    return kitchenCityTextIndicatesRiyadh(kitchenCity);
  }
  final kc = normalizeSaudiCityKey(kitchenCity);
  return kc.isNotEmpty && kc == customerCityKey;
}

/// Locality string used only for **home browse** matching against [chef_profiles.kitchen_city].
/// When the pin is in the Riyadh metro, always treat as Riyadh so Arabic `kitchen_city` rows match.
String? effectiveLocalityCityForHomeBrowse(
  String? pickupLocalityCity,
  double customerLat,
  double customerLng,
) {
  if (normalizeSaudiCityKey(pickupLocalityCity) == 'riyadh') {
    final raw = pickupLocalityCity?.trim();
    return (raw != null && raw.isNotEmpty) ? raw : 'Riyadh';
  }
  if (pickupCoordinatesLikelyRiyadh(customerLat, customerLng)) {
    return 'Riyadh';
  }
  return pickupLocalityCity;
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
    if (!homeKitchenMatchesBrowseCity(c.kitchenCity, target)) continue;
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

/// Home browse: kitchens in the same city as the pickup pin (reverse-geocode), **all distances**, nearest first.
/// Riyadh metro pins use [effectiveLocalityCityForHomeBrowse] so district-only geocodes still match `الرياض` kitchens.
/// If no city is resolved from the pin, falls back to [kFallbackBrowseRadiusWhenCityUnknownKm] radius.
List<ChefWithPickupDistance> buildHomeSortedChefs(
  List<ChefDocModel> chefs,
  double customerLat,
  double customerLng,
  String? pickupLocalityCity,
) {
  final locality = effectiveLocalityCityForHomeBrowse(
    pickupLocalityCity,
    customerLat,
    customerLng,
  );
  final cityKey = normalizeSaudiCityKey(locality);
  if (cityKey.isNotEmpty) {
    final byCity = buildCityScopeChefs(chefs, locality, customerLat, customerLng);
    if (byCity.isNotEmpty) return byCity;
  }
  return buildPickupSortedChefs(
    chefs,
    customerLat,
    customerLng,
    pickupLocalityCity: locality,
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

/// Same-city (no distance cap) or [kFallbackBrowseRadiusWhenCityUnknownKm] when city unknown.
/// No storefront / online filter (reels only).
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
    final kc = normalizeSaudiCityKey(c.kitchenCity);
    if (cityKey.isNotEmpty && (kc.isEmpty || kc != cityKey)) {
      continue;
    }
    final lat = c.kitchenLatitude;
    final lng = c.kitchenLongitude;
    if (lat != null && lng != null) {
      final d = haversineKm(customerLat, customerLng, lat, lng);
      if (cityKey.isEmpty && d > kFallbackBrowseRadiusWhenCityUnknownKm) {
        continue;
      }
      within.add(ChefWithPickupDistance(c, d));
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
    final nk = normalizeSaudiCityKey(e.chef.kitchenCity);
    if (nk.isEmpty || nk == cityKey) {
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

/// When [pickupLocalityCity] normalizes to a city: **all** accepting kitchens in that city (by
/// [chef_profiles.kitchen_city]), sorted by distance (nearest first) — no max distance within the city.
/// When city is unknown: kitchens within [kFallbackBrowseRadiusWhenCityUnknownKm] only.
/// Kitchens without coordinates are listed after coordinate kitchens (name order).
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
    if (cityKey.isNotEmpty && !homeKitchenMatchesBrowseCity(c.kitchenCity, cityKey)) {
      continue;
    }
    final lat = c.kitchenLatitude;
    final lng = c.kitchenLongitude;
    if (lat != null && lng != null) {
      final d = haversineKm(customerLat, customerLng, lat, lng);
      if (cityKey.isEmpty && d > kFallbackBrowseRadiusWhenCityUnknownKm) {
        continue;
      }
      within.add(ChefWithPickupDistance(c, d));
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
    final nk = normalizeSaudiCityKey(e.chef.kitchenCity);
    final bool sameArea;
    if (cityKey == 'riyadh') {
      sameArea = nk.isEmpty || kitchenCityTextIndicatesRiyadh(e.chef.kitchenCity);
    } else {
      sameArea = nk.isEmpty || nk == cityKey;
    }
    if (sameArea) {
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
