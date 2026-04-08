import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// GPS permission + current position + short address label for the pickup header.
class CustomerLocationService {
  static Future<bool> ensureLocationPermission() async {
    if (kIsWeb) {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    }
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Real device GPS (when permission granted and location services are on).
  /// Not a hardcoded city — [Position] comes from the OS location stack.
  static Future<Position?> tryCurrentPosition() async {
    final ok = await ensureLocationPermission();
    if (!ok) return null;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<String> labelForCoordinates(double lat, double lng) async {
    final g = await pickupGeocodeLabels(lat, lng);
    return g.shortLabel;
  }

  /// Rich labels for pickup header: [shortLabel] compact, [detailLine] broader (region / country).
  /// [localityCity] is used to match [chef_profiles.kitchen_city] (same logic as [normalizeSaudiCityKey] in pickup_distance).
  static Future<({String shortLabel, String detailLine, String? localityCity})> pickupGeocodeLabels(double lat, double lng) async {
    if (kIsWeb) {
      final region = _webRegionHint(lat, lng);
      final city = _parseCityHintFromWebRegion(region);
      return (
        shortLabel: region,
        detailLine: '$region · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} (browser — drag the map pin to refine)',
        localityCity: city,
      );
    }
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) {
        return (
          shortLabel: 'Saved pin',
          detailLine: 'Location saved · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          localityCity: null,
        );
      }
      final p = marks.first;
      final sub = (p.subLocality ?? '').trim();
      final loc = (p.locality ?? '').trim();
      final adm = (p.administrativeArea ?? '').trim();
      final country = (p.country ?? '').trim();
      final name = (p.name ?? '').trim();

      final shortParts = <String>[];
      if (sub.isNotEmpty) shortParts.add(sub);
      if (loc.isNotEmpty) shortParts.add(loc);
      if (shortParts.isEmpty && name.isNotEmpty) shortParts.add(name);
      if (shortParts.isEmpty && adm.isNotEmpty) shortParts.add(adm);
      final shortLabel = shortParts.isEmpty ? 'Saved pin' : shortParts.join(', ');

      final detailParts = <String>[];
      if (sub.isNotEmpty) detailParts.add(sub);
      if (loc.isNotEmpty && !detailParts.contains(loc)) detailParts.add(loc);
      if (adm.isNotEmpty) detailParts.add(adm);
      if (country.isNotEmpty) detailParts.add(country);
      var detailLine = detailParts.isEmpty ? shortLabel : detailParts.join(' · ');
      if (detailLine == shortLabel && country.isEmpty && adm.isNotEmpty) {
        detailLine = '$shortLabel · $adm';
      }
      final localityCity = loc.isNotEmpty ? loc : (adm.isNotEmpty ? adm : null);
      return (shortLabel: shortLabel, detailLine: detailLine, localityCity: localityCity);
    } catch (_) {
      return (
        shortLabel: 'Saved pin',
        detailLine: 'Location saved · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
        localityCity: null,
      );
    }
  }

  /// Rough city hint for web when only [region] string is available.
  static String? _parseCityHintFromWebRegion(String region) {
    final r = region.toLowerCase();
    if (r.contains('riyadh')) return 'Riyadh';
    if (r.contains('makkah') || r.contains('taif')) return 'Jeddah';
    if (r.contains('eastern')) return 'Dammam';
    return null;
  }

  /// Coarse hint when reverse-geocode is unavailable on web (Chrome, etc.).
  static String _webRegionHint(double lat, double lng) {
    if (lat >= 16 && lat <= 33 && lng >= 34 && lng <= 56) {
      if (lat >= 23.4 && lat <= 26.8 && lng >= 44.8 && lng <= 50.5) {
        return 'Riyadh area (approx.)';
      }
      if (lat >= 21 && lat <= 25.5 && lng >= 38 && lng <= 43.5) {
        return 'Makkah / Taif area (approx.)';
      }
      if (lat >= 21 && lat <= 24.5 && lng >= 50 && lng <= 56) {
        return 'Eastern Province (approx.)';
      }
      return 'Saudi Arabia (approx.)';
    }
    return 'Map pin';
  }
}
