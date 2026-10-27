/// UI progress only. Never evidence that a run or a programme block completed.
class SteadyStateTimerCursor {
  const SteadyStateTimerCursor({
    required this.blockId,
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.state,
  });

  final String blockId;
  final int durationSeconds;
  final int remainingSeconds;
  final SteadyStateTimerStatus state;

  void validate({String? expectedBlockId, int? expectedDurationSeconds}) {
    if (blockId.trim().isEmpty ||
        durationSeconds <= 0 ||
        remainingSeconds < 0 ||
        remainingSeconds > durationSeconds ||
        (state == SteadyStateTimerStatus.finished) != (remainingSeconds == 0) ||
        (expectedBlockId != null && blockId != expectedBlockId) ||
        (expectedDurationSeconds != null &&
            durationSeconds != expectedDurationSeconds)) {
      throw const FormatException('Invalid saved steady-state timer.');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'schema_version': 1,
      'block_id': blockId,
      'duration_seconds': durationSeconds,
      'remaining_seconds': remainingSeconds,
      'state': state.name,
    };
  }

  factory SteadyStateTimerCursor.fromJson(Map<String, dynamic> json) {
    const keys = {
      'schema_version',
      'block_id',
      'duration_seconds',
      'remaining_seconds',
      'state',
    };
    final state = SteadyStateTimerStatus.values.asNameMap()[json['state']];
    if (json.length != keys.length ||
        !json.keys.toSet().containsAll(keys) ||
        json['schema_version'] is! int ||
        json['schema_version'] != 1 ||
        json['block_id'] is! String ||
        json['duration_seconds'] is! int ||
        json['remaining_seconds'] is! int ||
        state == null) {
      throw const FormatException('Invalid saved steady-state timer.');
    }
    final cursor = SteadyStateTimerCursor(
      blockId: json['block_id'] as String,
      durationSeconds: json['duration_seconds'] as int,
      remainingSeconds: json['remaining_seconds'] as int,
      state: state,
    );
    cursor.validate();
    return cursor;
  }
}

enum SteadyStateTimerStatus { running, paused, finished }
