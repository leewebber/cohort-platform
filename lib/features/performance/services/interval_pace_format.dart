class IntervalPaceFormat {
  const IntervalPaceFormat._();

  static final RegExp _completePattern = RegExp(r'^(\d{1,3}):([0-5]\d)$');

  static const helperCopy = 'Type 410 for 4:10 /km';
  static const invalidPaceMessage = 'Enter pace as MM:SS /km';

  static String normalize(String raw) {
    return raw.trim().toLowerCase().replaceAll('/km', '').trim();
  }

  static String digitsOnly(String raw) {
    return normalize(raw).replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String applySmartDraft(String raw) {
    final trimmed = normalize(raw);
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(':')) {
      return _sanitizeColonDraft(trimmed);
    }
    return _formatDigitDraft(digitsOnly(trimmed));
  }

  static String _formatDigitDraft(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length > 5) {
      digits = digits.substring(0, 5);
    }
    if (digits.length <= 2) return digits;
    final seconds = digits.substring(digits.length - 2);
    final minutes = digits.substring(0, digits.length - 2);
    final secondValue = int.tryParse(seconds);
    if (secondValue == null || secondValue > 59) {
      return digits;
    }
    return '$minutes:$seconds';
  }

  static String _sanitizeColonDraft(String raw) {
    final parts = raw.split(':');
    if (parts.length == 1) {
      return _formatDigitDraft(digitsOnly(raw));
    }
    final minutes = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    final seconds = parts.sublist(1).join().replaceAll(RegExp(r'[^0-9]'), '');
    if (minutes.isEmpty && seconds.isEmpty) return '';
    if (seconds.isEmpty) return '$minutes:';
    return '$minutes:${seconds.length > 2 ? seconds.substring(0, 2) : seconds}';
  }

  static bool isComplete(String raw) {
    return _completePattern.hasMatch(applySmartDraft(raw));
  }

  static bool hasInvalidSeconds(String raw) {
    final trimmed = normalize(raw);
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      if (parts.length != 2 || parts[1].length != 2) return false;
      final seconds = int.tryParse(parts[1]);
      return seconds != null && seconds > 59;
    }
    final digits = digitsOnly(trimmed);
    if (digits.length < 3) return false;
    final seconds = int.tryParse(digits.substring(digits.length - 2));
    return seconds != null && seconds > 59;
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
    final formatted = applySmartDraft(raw);
    if (formatted.isEmpty) return null;
    final match = _completePattern.firstMatch(formatted);
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
