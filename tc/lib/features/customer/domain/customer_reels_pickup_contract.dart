/// Matches [CustomerReelsSupabaseDatasource.watchReels] — no feed without pickup coordinates.
bool customerReelsRequirePickupCoordinates(double? lat, double? lng) {
  return lat == null || lng == null;
}
