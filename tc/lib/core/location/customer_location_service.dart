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
  static Future<({String shortLabel, String detailLine})> pickupGeocodeLabels(double lat, double lng) async {
    if (kIsWeb) {
      final region = _webRegionHint(lat, lng);
      return (
        shortLabel: region,
        detailLine: '$region · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} (browser — drag the map pin to refine)',
      );
    }
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) {
        return (shortLabel: 'Your area', detailLine: 'Location saved · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');
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
      final shortLabel = shortParts.isEmpty ? 'Your area' : shortParts.join(', ');

      final detailParts = <String>[];
      if (sub.isNotEmpty) detailParts.add(sub);
      if (loc.isNotEmpty && !detailParts.contains(loc)) detailParts.add(loc);
      if (adm.isNotEmpty) detailParts.add(adm);
      if (country.isNotEmpty) detailParts.add(country);
      var detailLine = detailParts.isEmpty ? shortLabel : detailParts.join(' · ');
      if (detailLine == shortLabel && country.isEmpty && adm.isNotEmpty) {
        detailLine = '$shortLabel · $adm';
      }
      return (shortLabel: shortLabel, detailLine: detailLine);
    } catch (_) {
      return (
        shortLabel: 'Your area',
        detailLine: 'Location saved · ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      );
    }
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
