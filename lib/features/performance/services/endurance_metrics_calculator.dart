class EnduranceMetricsCalculator {
  const EnduranceMetricsCalculator._();

  static String? formatPaceOrSpeed({
    required double? distance,
    required String distanceUnit,
    required int? durationSeconds,
  }) {
    if (distance == null ||
        durationSeconds == null ||
        distance <= 0 ||
        durationSeconds <= 0) {
      return null;
    }

    final unit = distanceUnit.trim().toLowerCase();
    if (unit == 'km' || unit == 'mi' || unit == 'm') {
      final paceSeconds = durationSeconds / distance;
      return 'Avg pace ${_formatClock(paceSeconds)}/$unit';
    }

    if (unit == 'cal') {
      return null;
    }

    final speed = distance / (durationSeconds / 3600);
    return 'Avg speed ${speed.toStringAsFixed(1)} $unit/h';
  }

  static String formatDuration(int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) return '';
    return _formatClock(durationSeconds.toDouble());
  }

  static String _formatClock(double totalSeconds) {
    final seconds = totalSeconds.round();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
