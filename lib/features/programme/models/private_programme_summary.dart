/// Ownership-scoped private programme card. No hashes or engineering paths.
class PrivateProgrammeSummary {
  const PrivateProgrammeSummary({
    required this.versionId,
    required this.title,
    this.summary,
    this.durationWeeks,
    this.sessionsPerWeek,
    this.level,
    this.equipment,
    this.classification = 'private',
    this.startEligible = false,
    this.alreadyActive = false,
    this.authorisedTimezone,
    this.authorisedLocalStartDate,
  });

  final String versionId;
  final String title;
  final String? summary;
  final int? durationWeeks;
  final int? sessionsPerWeek;
  final String? level;
  final String? equipment;
  final String classification;
  final bool startEligible;
  final bool alreadyActive;
  final String? authorisedTimezone;
  final DateTime? authorisedLocalStartDate;

  bool get isPrivate => classification == 'private';

  factory PrivateProgrammeSummary.fromRpcMap(Map<String, dynamic> map) {
    return PrivateProgrammeSummary(
      versionId: (map['version_id'] ?? '').toString().trim(),
      title: (map['title'] ?? 'Private programme').toString().trim(),
      summary: _trim(map['summary']),
      durationWeeks: _int(map['duration_weeks']),
      sessionsPerWeek: _int(map['sessions_per_week']),
      level: _trim(map['level']),
      equipment: _trim(map['equipment']),
      classification: _trim(map['classification']) ?? 'private',
      startEligible: map['start_eligible'] == true,
      alreadyActive: map['already_active'] == true,
      authorisedTimezone: _trim(map['authorised_timezone']),
      authorisedLocalStartDate: _date(map['authorised_local_start_date']),
    );
  }

  static String? _trim(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
