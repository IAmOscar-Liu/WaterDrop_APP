/// The preceding 7 × 24 hours, ending at the instant the preset is selected.
OrderDateRange recentWeekOrderRange(DateTime now) =>
    OrderDateRange._recent(const Duration(days: 7), now);

/// The preceding 30 × 24 hours, ending at the instant the preset is selected.
OrderDateRange recentMonthOrderRange(DateTime now) =>
    OrderDateRange._recent(const Duration(days: 30), now);

/// Custom ranges use inclusive local dates; recent presets use exact instants.
/// A missing bound leaves that side unrestricted.
class OrderDateRange {
  const OrderDateRange({this.start, this.end}) : _exactTimes = false;

  OrderDateRange._recent(Duration duration, DateTime now)
    : start = now.toLocal().subtract(duration),
      end = now.toLocal(),
      _exactTimes = true;

  final bool _exactTimes;

  final DateTime? start;
  final DateTime? end;

  DateTime? get startUtc {
    final date = start;
    if (_exactTimes) return date?.toUtc();
    return date == null
        ? null
        : DateTime(date.year, date.month, date.day).toUtc();
  }

  // Construct the next calendar midnight; a local day need not be 24 hours.
  DateTime? get endExclusiveUtc {
    final date = end;
    if (_exactTimes) return date?.toUtc();
    return date == null
        ? null
        : DateTime(date.year, date.month, date.day + 1).toUtc();
  }
}
