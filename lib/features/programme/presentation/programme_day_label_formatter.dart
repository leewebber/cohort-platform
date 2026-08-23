/// Athlete-facing labels for stable programme day keys.
///
/// Persistence continues to use deterministic keys such as `day_1`; this
/// formatter is deliberately presentation-only so those identifiers never
/// leak into Home or Plans.
abstract final class ProgrammeDayLabelFormatter {
  static final RegExp _canonicalDayKey = RegExp(r'^day_([1-9][0-9]*)$');

  static String format({required String dayKey, String? authoredLabel}) {
    final authored = authoredLabel?.trim();
    if (authored != null && authored.isNotEmpty) return authored;

    final normalized = dayKey.trim();
    final canonical = _canonicalDayKey.firstMatch(normalized);
    if (canonical != null) return 'Day ${canonical.group(1)}';

    return normalized
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
