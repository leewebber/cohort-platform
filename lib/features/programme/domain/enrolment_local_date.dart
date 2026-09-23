import 'enrolment_iana_timezone.dart';

/// Provisional athlete-local civil date. Server persist is authoritative.
abstract final class EnrolmentLocalDate {
  static DateTime? civilDate({
    required String iana,
    required DateTime utcNow,
  }) {
    if (!EnrolmentIanaTimezone.isValidIdentifier(iana)) return null;
    final offset = EnrolmentIanaOffsets.offsetHours(iana, utcNow.toUtc());
    if (offset == null) return null;
    final local = utcNow.toUtc().add(Duration(hours: offset));
    return DateTime(local.year, local.month, local.day);
  }

  static String? isoDate({required String iana, required DateTime utcNow}) {
    final date = civilDate(iana: iana, utcNow: utcNow);
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Known-zone offsets for enrolment preview only. Unknown zones fail closed.
abstract final class EnrolmentIanaOffsets {
  static int? offsetHours(String iana, DateTime utc) {
    switch (iana) {
      case EnrolmentIanaTimezone.bali:
      case 'Asia/Singapore':
      case 'Asia/Jakarta':
      case 'Australia/Perth':
        return 8;
      case 'Asia/Tokyo':
      case 'Asia/Seoul':
        return 9;
      case 'Asia/Kolkata':
        return null;
      case 'Asia/Dubai':
        return 4;
      case EnrolmentIanaTimezone.unitedKingdom:
      case 'Europe/Dublin':
      case 'Europe/Lisbon':
      case 'Atlantic/Canary':
        return _euSummer(utc) ? 1 : 0;
      case 'Europe/Paris':
      case 'Europe/Berlin':
      case 'Europe/Madrid':
        return _euSummer(utc) ? 2 : 1;
      case 'America/New_York':
      case 'America/Toronto':
        return _usSummer(utc) ? -4 : -5;
      case 'America/Chicago':
        return _usSummer(utc) ? -5 : -6;
      case 'America/Denver':
        return _usSummer(utc) ? -6 : -7;
      case 'America/Los_Angeles':
      case 'America/Vancouver':
        return _usSummer(utc) ? -7 : -8;
      case 'Australia/Sydney':
        return _auSummer(utc) ? 11 : 10;
      case 'Pacific/Auckland':
        return _nzSummer(utc) ? 13 : 12;
      case 'Africa/Johannesburg':
        return 2;
      default:
        return null;
    }
  }

  static bool _euSummer(DateTime utc) {
    final start = _lastSundayUtc(utc.year, 3, 1);
    final end = _lastSundayUtc(utc.year, 10, 1);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static bool _usSummer(DateTime utc) {
    final start = DateTime.utc(utc.year, 3, _nthSunday(utc.year, 3, 2), 7);
    final end = DateTime.utc(utc.year, 11, _nthSunday(utc.year, 11, 1), 6);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static bool _auSummer(DateTime utc) {
    final start = _firstSundayUtc(utc.year, 10, 16);
    final end = _firstSundayUtc(utc.year + 1, 4, 16);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static bool _nzSummer(DateTime utc) {
    final start = _lastSundayUtc(utc.year, 9, 14);
    final end = _firstSundayUtc(utc.year + 1, 4, 14);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static DateTime _lastSundayUtc(int year, int month, int hour) {
    final last = DateTime.utc(year, month + 1, 0, hour);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  static DateTime _firstSundayUtc(int year, int month, int hour) {
    final first = DateTime.utc(year, month, 1, hour);
    final add = (7 - first.weekday % 7) % 7;
    return first.add(Duration(days: add));
  }

  static int _nthSunday(int year, int month, int n) {
    final first = DateTime.utc(year, month, 1);
    final add = (7 - first.weekday % 7) % 7;
    return 1 + add + (n - 1) * 7;
  }
}
