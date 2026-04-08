import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/providers/customer_providers.dart';

/// Persists the customer's pickup point (GPS or map pin) across app restarts.
class CustomerPickupStorage {
  static const _kLat = 'customer_pickup_lat';
  static const _kLng = 'customer_pickup_lng';
  static const _kLabel = 'customer_pickup_label';
  static const _kDetail = 'customer_pickup_detail';
  static const _kLocalityCity = 'customer_pickup_locality_city';

  static Future<CustomerPickupOrigin?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    final label = prefs.getString(_kLabel);
    final detail = prefs.getString(_kDetail);
    final locality = prefs.getString(_kLocalityCity);
    if (lat == null || lng == null) return null;
    return CustomerPickupOrigin(
      latitude: lat,
      longitude: lng,
      label: (label == null || label.isEmpty) ? 'Saved pickup point' : label,
      detailLabel: detail ?? '',
      localityCity: (locality != null && locality.isNotEmpty) ? locality : null,
    );
  }

  static Future<void> save(CustomerPickupOrigin origin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, origin.latitude);
    await prefs.setDouble(_kLng, origin.longitude);
    await prefs.setString(_kLabel, origin.label);
    await prefs.setString(_kDetail, origin.detailLabel);
    final lc = origin.localityCity?.trim();
    if (lc != null && lc.isNotEmpty) {
      await prefs.setString(_kLocalityCity, lc);
    } else {
      await prefs.remove(_kLocalityCity);
    }
  }
}
