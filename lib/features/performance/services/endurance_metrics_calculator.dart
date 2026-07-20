/// Derived endurance metrics and athlete-friendly duration formatting.
class EnduranceDurationParseResult {
  const EnduranceDurationParseResult._({
    this.seconds,
    required this.state,
  });

  const EnduranceDurationParseResult.valid(int? seconds)
      : this._(seconds: seconds, state: EnduranceDurationParseState.valid);

  const EnduranceDurationParseResult.partial()
      : this._(seconds: null, state: EnduranceDurationParseState.partial);

  const EnduranceDurationParseResult.invalid()
      : this._(seconds: null, state: EnduranceDurationParseState.invalid);

  final int? seconds;
  final EnduranceDurationParseState state;

  bool get isValid => state == EnduranceDurationParseState.valid;
  bool get isPartial => state == EnduranceDurationParseState.partial;
  bool get isInvalid => state == EnduranceDurationParseState.invalid;
}

enum EnduranceDurationParseState { valid, partial, invalid }

class EnduranceLiveMetric {
  const EnduranceLiveMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class EnduranceMetricsCalculator {
  const EnduranceMetricsCalculator._();

  static const _paceUnits = {'km', 'mi', 'm'};
  static const _speedUnits = {'km/h', 'kph', 'mph'};

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
    if (_paceUnits.contains(unit)) {
      final paceSeconds = durationSeconds / distance;
      return 'Avg pace ${_formatPaceClock(paceSeconds)}/$unit';
    }

    if (_speedUnits.contains(unit)) {
      final speed = distance / (durationSeconds / 3600);
      return 'Avg speed ${speed.toStringAsFixed(1)} $unit';
    }

    return null;
  }

  static EnduranceLiveMetric? liveMetric({
    required double? distance,
    required String distanceUnit,
    required int? durationSeconds,
  }) {
    final formatted = formatPaceOrSpeed(
      distance: distance,
      distanceUnit: distanceUnit,
      durationSeconds: durationSeconds,
    );
    if (formatted == null) return null;

    if (formatted.startsWith('Avg pace ')) {
      final remainder = formatted.substring('Avg pace '.length);
      final slashIndex = remainder.indexOf('/');
      if (slashIndex <= 0) return null;
      return EnduranceLiveMetric(
        label: 'Average pace',
        value:
            '${remainder.substring(0, slashIndex).trim()} /${remainder.substring(slashIndex + 1)}',
      );
    }

    if (formatted.startsWith('Avg speed ')) {
      return EnduranceLiveMetric(
        label: 'Average speed',
        value: formatted.substring('Avg speed '.length),
      );
    }

    return null;
  }

  static String formatDuration(int? durationSeconds) {
    return formatAthleteDuration(durationSeconds);
  }

  static String formatAthleteDuration(int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) return '';

    final total = durationSeconds;
    if (total >= 3600) {
      final hours = total ~/ 3600;
      final minutes = (total % 3600) ~/ 60;
      final seconds = total % 60;
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static EnduranceDurationParseResult parseAthleteDuration(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const EnduranceDurationParseResult.valid(null);
    }

    if (!RegExp(r'^[0-9:]*$').hasMatch(input)) {
      return const EnduranceDurationParseResult.invalid();
    }

    if (!input.contains(':')) {
      return const EnduranceDurationParseResult.partial();
    }

    final segments = input.split(':');
    if (segments.length > 3) {
      return const EnduranceDurationParseResult.invalid();
    }

    if (segments.length == 2) {
      return _parseMinuteSecondDuration(segments[0], segments[1]);
    }

    return _parseHourMinuteSecondDuration(
      segments[0],
      segments[1],
      segments[2],
    );
  }

  static EnduranceDurationParseResult _parseMinuteSecondDuration(
    String minutesPart,
    String secondsPart,
  ) {
    if (minutesPart.isEmpty || secondsPart.isEmpty) {
      return const EnduranceDurationParseResult.partial();
    }

    if (secondsPart.length < 2) {
      return const EnduranceDurationParseResult.partial();
    }

    if (secondsPart.length > 2) {
      return const EnduranceDurationParseResult.invalid();
    }

    final minutes = int.tryParse(minutesPart);
    final seconds = int.tryParse(secondsPart);
    if (minutes == null || seconds == null || seconds >= 60) {
      return const EnduranceDurationParseResult.invalid();
    }

    return EnduranceDurationParseResult.valid(minutes * 60 + seconds);
  }

  static EnduranceDurationParseResult _parseHourMinuteSecondDuration(
    String hoursPart,
    String minutesPart,
    String secondsPart,
  ) {
    if (hoursPart.isEmpty ||
        minutesPart.isEmpty ||
        secondsPart.isEmpty ||
        minutesPart.length < 2 ||
        secondsPart.length < 2) {
      return const EnduranceDurationParseResult.partial();
    }

    if (minutesPart.length > 2 || secondsPart.length > 2) {
      return const EnduranceDurationParseResult.invalid();
    }

    final hours = int.tryParse(hoursPart);
    final minutes = int.tryParse(minutesPart);
    final seconds = int.tryParse(secondsPart);
    if (hours == null ||
        minutes == null ||
        seconds == null ||
        minutes >= 60 ||
        seconds >= 60) {
      return const EnduranceDurationParseResult.invalid();
    }

    return EnduranceDurationParseResult.valid(
      hours * 3600 + minutes * 60 + seconds,
    );
  }

  static String _formatPaceClock(double totalSeconds) {
    final seconds = totalSeconds.round();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }
}
