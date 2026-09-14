/// Time-aware athlete greeting using first name and an IANA-local clock.
abstract final class AthleteTimeAwareGreeting {
  static const fallbackPeriodOnly = true;

  static String firstName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String format({required DateTime localNow, String? displayName}) {
    final period = periodLabel(localNow.hour);
    final name = firstName(displayName);
    if (name.isEmpty) return period;
    return '$period, $name';
  }

  static String periodLabel(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Converts UTC instants into an assignment IANA timezone without using the
/// device zone when an authoritative timezone exists.
///
/// Unknown IANA names fall back to UTC rather than the device clock.
abstract final class AthleteIanaClock {
  static DateTime nowInZone(String? iana, {DateTime? utcNow}) {
    final utc = (utcNow ?? DateTime.now().toUtc()).toUtc();
    final offset = offsetFor(iana, utc);
    return utc.add(offset);
  }

  /// Assignment-local calendar date `YYYY-MM-DD`. Unknown zones use UTC.
  static String dateOnly(String? iana, {DateTime? utcNow}) {
    final local = nowInZone(iana, utcNow: utcNow);
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Duration offsetFor(String? iana, DateTime utc) {
    final zone = iana?.trim();
    if (zone == null || zone.isEmpty) return Duration.zero;
    switch (zone) {
      case 'UTC':
      case 'Etc/UTC':
      case 'Etc/GMT':
      case 'GMT':
        return Duration.zero;
      case 'Atlantic/Canary':
      case 'Europe/Lisbon':
      case 'Europe/London':
        return Duration(hours: _euSummer(utc) ? 1 : 0);
      case 'Europe/Madrid':
      case 'Europe/Paris':
      case 'Europe/Berlin':
        return Duration(hours: _euSummer(utc) ? 2 : 1);
      case 'America/New_York':
        return Duration(hours: _usSummer(utc) ? -4 : -5);
      case 'America/Chicago':
        return Duration(hours: _usSummer(utc) ? -5 : -6);
      case 'America/Los_Angeles':
        return Duration(hours: _usSummer(utc) ? -7 : -8);
      default:
        return Duration.zero;
    }
  }

  static bool _euSummer(DateTime utc) {
    final start = _lastSundayUtc(utc.year, 3);
    final end = _lastSundayUtc(utc.year, 10);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static bool _usSummer(DateTime utc) {
    final start = DateTime.utc(utc.year, 3, _nthSunday(utc.year, 3, 2), 7);
    final end = DateTime.utc(utc.year, 11, _nthSunday(utc.year, 11, 1), 6);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static DateTime _lastSundayUtc(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0, 1);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  static int _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    final firstSunday = first.day + ((7 - first.weekday % 7) % 7);
    return firstSunday + (n - 1) * 7;
  }
}
