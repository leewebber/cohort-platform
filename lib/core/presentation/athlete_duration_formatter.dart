/// Consistent athlete-facing labels for authored and recorded durations.
class AthleteDurationFormatter {
  const AthleteDurationFormatter._();

  static String formatSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return '0 sec';

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[
      if (minutes > 0) '$minutes min',
      if (seconds > 0) '$seconds sec',
    ];
    return parts.join(' ');
  }
}
