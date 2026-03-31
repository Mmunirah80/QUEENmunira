/// Maps the device's **local** calendar day to UTC instants for querying
/// `timestamptz` columns stored in UTC (e.g. `orders.created_at`).
abstract final class LocalCalendarDayUtcBounds {
  LocalCalendarDayUtcBounds._();

  /// Inclusive start and exclusive end in UTC.
  static ({DateTime startUtc, DateTime endUtc}) forInstant(DateTime clock) {
    final startLocal = DateTime(clock.year, clock.month, clock.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (startUtc: startLocal.toUtc(), endUtc: endLocal.toUtc());
  }

  static ({DateTime startUtc, DateTime endUtc}) forNow() => forInstant(DateTime.now());
}
