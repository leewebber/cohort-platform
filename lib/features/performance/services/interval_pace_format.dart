class IntervalPaceFormat {
  const IntervalPaceFormat._();

  static final RegExp _completePattern = RegExp(r'^(\d{1,3}):([0-5]\d)$');

  static String normalize(String raw) {
    return raw.trim().toLowerCase().replaceAll('/km', '').trim();
  }

  static bool isComplete(String raw) {
    return _completePattern.hasMatch(normalize(raw));
  }

  static String formatSecondsPerKm(double? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0) return '';
    final rounded = secondsPerKm.round();
    final minutes = rounded ~/ 60;
    final seconds = rounded % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String display(double? secondsPerKm) {
    final formatted = formatSecondsPerKm(secondsPerKm);
    return formatted.isEmpty ? '' : '$formatted /km';
  }

  static double? parse(String raw) {
    final trimmed = normalize(raw);
    if (trimmed.isEmpty) return null;
    final match = _completePattern.firstMatch(trimmed);
    if (match == null) return null;
    final minutes = int.parse(match[1]!);
    final seconds = int.parse(match[2]!);
    final total = minutes * 60 + seconds;
    return total > 0 ? total.toDouble() : null;
  }

  static bool isPlausible(double? secondsPerKm) {
    if (secondsPerKm == null) return false;
    return secondsPerKm >= 90 && secondsPerKm <= 1200;
  }
}
