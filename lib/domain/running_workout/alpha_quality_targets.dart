import 'dart:math' as math;

const alphaFiveKRuleId = 'alpha_5k_8w_riegel_1_06_v1';
const alphaManualThresholdRuleId = 'alpha_manual_threshold_pm2_v1';
const authoredRpeRuleId = 'authored_rpe_v1';
const alphaQualityCategories = {'threshold', '10k_specific', 'short_5k'};
const alphaQualitySources = {'five_k', 'manual_threshold', 'authored_rpe'};

/// Positive pace in seconds/km, nearest integer, exact halves toward +infinity.
int roundAlphaPace(num secondsPerKm) {
  if (!secondsPerKm.isFinite || secondsPerKm <= 0) {
    throw const FormatException('Invalid pace in seconds per kilometre.');
  }
  return (secondsPerKm + 0.5).floor();
}

({int lower, int upper}) alphaQualityPaceWindow({
  required int seconds,
  required String category,
  bool manualThreshold = false,
}) {
  if (seconds < 1 ||
      seconds > 86400 ||
      !alphaQualityCategories.contains(category) ||
      (manualThreshold && category != 'threshold')) {
    throw const FormatException(
      'Invalid alpha quality input or source selection.',
    );
  }
  int ratio(int numerator, int denominator) =>
      (2 * numerator + denominator) ~/ (2 * denominator);
  if (manualThreshold || category == 'short_5k') {
    final lower = manualThreshold
        ? ratio(seconds * 98, 100)
        : ratio(seconds, 5);
    final upper = manualThreshold
        ? ratio(seconds * 102, 100)
        : ratio(seconds * 103, 500);
    if (lower < 1 || lower >= upper) {
      throw const FormatException(
        'The input does not produce a supported ordered pace window.',
      );
    }
    return (lower: lower, upper: upper);
  }
  final p10 = seconds * math.pow(2, 1.06) / 10;
  final (num low, num high) = category == 'threshold'
      ? (p10 * 1.02, p10 * 1.06)
      : (p10 * 0.99, p10 * 1.02);
  final lower = roundAlphaPace(low), upper = roundAlphaPace(high);
  if (lower < 1 || lower >= upper) {
    throw const FormatException(
      'The input does not produce a supported ordered pace window.',
    );
  }
  return (lower: lower, upper: upper);
}

/// Date-only athlete evidence is interpreted in its confirmed training timezone.
/// 0..56 local civil days inclusive qualifies; no rolling UTC-hour cutoff.
bool alphaFiveKDateEligible(String resultDate, String today) {
  DateTime parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Use a real YYYY-MM-DD date.');
    }
    final value = DateTime.tryParse('${text}T00:00:00Z');
    if (value == null || value.toIso8601String().substring(0, 10) != text) {
      throw const FormatException('Use a real YYYY-MM-DD date.');
    }
    return value;
  }

  final days = parse(today).difference(parse(resultDate)).inDays;
  return days >= 0 && days <= 56;
}
