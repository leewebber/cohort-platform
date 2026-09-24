/// Validated IANA training-timezone authority for enrolment.
///
/// Abbreviations, offsets, and `Etc/` aliases are never stored or inferred.
abstract final class EnrolmentIanaTimezone {
  static const bali = 'Asia/Makassar';
  static const unitedKingdom = 'Europe/London';

  static final _ianaPath = RegExp(
    r'^[A-Za-z_]+/[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$',
  );
  static final _offset = RegExp(
    r'^(UTC)?[+-]\d{1,2}(:\d{2})?$',
    caseSensitive: false,
  );

  static bool isValidIdentifier(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    if (_offset.hasMatch(value)) return false;
    if (value.toUpperCase() == 'UTC' || value.toUpperCase() == 'GMT') {
      return false;
    }
    if (value.startsWith('Etc/') ||
        value.startsWith('posix/') ||
        value.startsWith('right/')) {
      return false;
    }
    if (!_ianaPath.hasMatch(value)) return false;
    return true;
  }

  static String? canonicalize(String? raw) {
    final value = raw?.trim() ?? '';
    return isValidIdentifier(value) ? value : null;
  }
}

/// Human labels for known training zones. Unknown valid IANA names use the
/// identifier itself.
abstract final class EnrolmentIanaLabels {
  static const labels = <String, String>{
    EnrolmentIanaTimezone.bali: 'Central Indonesia Time',
    EnrolmentIanaTimezone.unitedKingdom: 'United Kingdom',
    'Europe/Dublin': 'Ireland',
    'Europe/Paris': 'France',
    'Europe/Berlin': 'Germany',
    'Europe/Madrid': 'Spain',
    'Europe/Lisbon': 'Portugal',
    'Atlantic/Canary': 'Canary Islands',
    'America/New_York': 'US Eastern',
    'America/Chicago': 'US Central',
    'America/Denver': 'US Mountain',
    'America/Los_Angeles': 'US Pacific',
    'America/Toronto': 'Canada Eastern',
    'America/Vancouver': 'Canada Pacific',
    'Australia/Sydney': 'Australia Eastern',
    'Australia/Perth': 'Australia Western',
    'Pacific/Auckland': 'New Zealand',
    'Asia/Singapore': 'Singapore',
    'Asia/Jakarta': 'Western Indonesia Time',
    'Asia/Tokyo': 'Japan',
    'Asia/Seoul': 'South Korea',
    'Asia/Dubai': 'Gulf',
    'Africa/Johannesburg': 'South Africa',
  };

  static String labelFor(String iana) => labels[iana] ?? iana;

  static String display(String iana) {
    final label = labels[iana];
    if (label == null) return iana;
    return '$label ($iana)';
  }
}

/// Searchable grouped picker catalog. Not the PostgreSQL authority.
abstract final class EnrolmentIanaCatalog {
  static const groups = <String, List<String>>{
    'Asia': [
      EnrolmentIanaTimezone.bali,
      'Asia/Jakarta',
      'Asia/Singapore',
      'Asia/Tokyo',
      'Asia/Seoul',
      'Asia/Dubai',
    ],
    'Europe': [
      EnrolmentIanaTimezone.unitedKingdom,
      'Europe/Dublin',
      'Europe/Paris',
      'Europe/Berlin',
      'Europe/Madrid',
      'Europe/Lisbon',
    ],
    'Americas': [
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'America/Toronto',
      'America/Vancouver',
    ],
    'Pacific': [
      'Australia/Sydney',
      'Australia/Perth',
      'Pacific/Auckland',
      'Atlantic/Canary',
    ],
    'Africa': ['Africa/Johannesburg'],
  };

  static const aliases = <String, List<String>>{
    EnrolmentIanaTimezone.bali: ['bali', 'makassar', 'indonesia'],
    EnrolmentIanaTimezone.unitedKingdom: [
      'london',
      'uk',
      'united kingdom',
      'britain',
    ],
    'Europe/Dublin': ['dublin', 'ireland'],
    'Europe/Paris': ['paris', 'france'],
    'Europe/Berlin': ['berlin', 'germany'],
    'Europe/Madrid': ['madrid', 'spain'],
    'Europe/Lisbon': ['lisbon', 'portugal'],
    'Atlantic/Canary': ['canary', 'tenerife'],
    'America/New_York': ['new york', 'nyc', 'eastern'],
    'America/Chicago': ['chicago', 'central'],
    'America/Denver': ['denver', 'mountain'],
    'America/Los_Angeles': ['los angeles', 'la', 'pacific'],
    'America/Toronto': ['toronto', 'canada'],
    'America/Vancouver': ['vancouver'],
    'Australia/Sydney': ['sydney', 'australia'],
    'Australia/Perth': ['perth'],
    'Pacific/Auckland': ['auckland', 'new zealand'],
    'Asia/Singapore': ['singapore'],
    'Asia/Jakarta': ['jakarta'],
    'Asia/Tokyo': ['tokyo', 'japan'],
    'Asia/Seoul': ['seoul', 'korea'],
    'Asia/Dubai': ['dubai'],
    'Africa/Johannesburg': ['johannesburg', 'south africa'],
  };

  static List<(String group, String iana)> search(String query) {
    final needle = query.trim().toLowerCase();
    final hits = <(String, String)>[];
    groups.forEach((group, zones) {
      for (final iana in zones) {
        final label = EnrolmentIanaLabels.display(iana).toLowerCase();
        final extra = (aliases[iana] ?? const <String>[]).join(' ');
        if (needle.isEmpty ||
            iana.toLowerCase().contains(needle) ||
            label.contains(needle) ||
            extra.contains(needle) ||
            group.toLowerCase().contains(needle)) {
          hits.add((group, iana));
        }
      }
    });
    return hits;
  }

  static String? suggestedValidIana(String? raw) =>
      EnrolmentIanaTimezone.canonicalize(raw);
}
