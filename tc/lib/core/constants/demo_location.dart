/// Demo / graduation default when `kitchen_city` is unset so browse and maps stay consistent.
const String kNahamDemoDefaultCity = 'Riyadh';

/// Approx. center of Riyadh — used as default customer pickup so "nearby" cooks match demo accounts.
const double kNahamDemoRiyadhLatitude = 24.7136;
const double kNahamDemoRiyadhLongitude = 46.6753;

String effectiveKitchenCityForDisplay(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return kNahamDemoDefaultCity;
  return t;
}
