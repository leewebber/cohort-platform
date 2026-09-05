class IntervalPaceFormat {
  const IntervalPaceFormat._();

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
    final trimmed = raw.trim().toLowerCase().replaceAll('/km', '').trim();
    if (trimmed.isEmpty) return null;
    final colon = trimmed.split(':');
    if (colon.length == 2) {
      final minutes = int.tryParse(colon[0]);
      final seconds = int.tryParse(colon[1]);
      if (minutes == null || seconds == null || seconds >= 60 || minutes < 0) {
        return null;
      }
      final total = minutes * 60 + seconds;
      return total > 0 ? total.toDouble() : null;
    }
    if (trimmed.contains('.')) {
      final minutes = int.tryParse(trimmed.split('.').first);
      final fraction = trimmed.split('.').last.padRight(2, '0').substring(0, 2);
      final seconds = int.tryParse(fraction);
      if (minutes == null || seconds == null || seconds >= 60) return null;
      final total = minutes * 60 + seconds;
      return total > 0 ? total.toDouble() : null;
    }
    final whole = int.tryParse(trimmed);
    if (whole == null || whole <= 0) return null;
    return whole.toDouble();
  }

  static bool isPlausible(double? secondsPerKm) {
    if (secondsPerKm == null) return false;
    return secondsPerKm >= 90 && secondsPerKm <= 1200;
  }
}
