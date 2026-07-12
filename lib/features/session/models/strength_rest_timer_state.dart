/// Local UI state for an in-session strength rest countdown.
class StrengthRestTimerState {
  const StrengthRestTimerState({
    required this.exerciseLocalId,
    required this.setLocalId,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.isPaused,
    required this.finished,
    this.prescribedRestLabel,
    this.nextTargetLabel,
  });

  final String exerciseLocalId;
  final String setLocalId;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool finished;
  final String? prescribedRestLabel;
  final String? nextTargetLabel;

  String get remainingLabel => _formatDuration(remainingSeconds);

  String get totalLabel => _formatDuration(totalSeconds);

  StrengthRestTimerState copyWith({
    String? exerciseLocalId,
    String? setLocalId,
    int? totalSeconds,
    int? remainingSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? finished,
    String? prescribedRestLabel,
    String? nextTargetLabel,
  }) {
    return StrengthRestTimerState(
      exerciseLocalId: exerciseLocalId ?? this.exerciseLocalId,
      setLocalId: setLocalId ?? this.setLocalId,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      finished: finished ?? this.finished,
      prescribedRestLabel: prescribedRestLabel ?? this.prescribedRestLabel,
      nextTargetLabel: nextTargetLabel ?? this.nextTargetLabel,
    );
  }

  static String exerciseLocalIdForStep(int stepNumber) => 'exercise-$stepNumber';

  static String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if (minutes == 0) {
      return '${seconds}s';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Parsed prescribed rest duration for timer startup.
class ParsedPrescribedRest {
  const ParsedPrescribedRest({
    required this.totalSeconds,
    required this.displayLabel,
  });

  final int totalSeconds;
  final String displayLabel;
}

/// Defensive parser for common prescribed rest strings.
class StrengthRestParser {
  StrengthRestParser._();

  static final _rangeMinutesPattern = RegExp(
    r'^(\d+)\s*[–\-]\s*(\d+)\s*min(?:ute)?s?$',
    caseSensitive: false,
  );
  static final _minutesPattern = RegExp(
    r'^(\d+)\s*min(?:ute)?s?$',
    caseSensitive: false,
  );
  static final _secondsPattern = RegExp(
    r'^(\d+)\s*sec(?:ond)?s?$',
    caseSensitive: false,
  );

  static ParsedPrescribedRest? parse(String? raw) {
    if (raw == null) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    final rangeMatch = _rangeMinutesPattern.firstMatch(normalized);
    if (rangeMatch != null) {
      final lowerMinutes = int.tryParse(rangeMatch.group(1) ?? '');
      if (lowerMinutes == null || lowerMinutes <= 0) {
        return null;
      }

      return ParsedPrescribedRest(
        totalSeconds: lowerMinutes * 60,
        displayLabel: trimmed,
      );
    }

    final minutesMatch = _minutesPattern.firstMatch(normalized);
    if (minutesMatch != null) {
      final minutes = int.tryParse(minutesMatch.group(1) ?? '');
      if (minutes == null || minutes <= 0) {
        return null;
      }

      return ParsedPrescribedRest(
        totalSeconds: minutes * 60,
        displayLabel: trimmed,
      );
    }

    final secondsMatch = _secondsPattern.firstMatch(normalized);
    if (secondsMatch != null) {
      final seconds = int.tryParse(secondsMatch.group(1) ?? '');
      if (seconds == null || seconds <= 0) {
        return null;
      }

      return ParsedPrescribedRest(
        totalSeconds: seconds,
        displayLabel: trimmed,
      );
    }

    return null;
  }
}
