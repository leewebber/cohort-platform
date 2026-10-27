import 'structured_running_execution.dart';
import 'steady_state_timer_cursor.dart';

/// Versioned production UI cursor. Never changes athletic result semantics.
class ProductionSessionUiCursor {
  const ProductionSessionUiCursor({
    required this.schemaVersion,
    required this.athleteId,
    required this.assignmentId,
    required this.trainingSessionId,
    this.occurrenceId,
    this.activeBlockId,
    this.activeBlockIndex,
    this.activeExerciseId,
    this.activeExerciseIndex,
    this.activeIntervalId,
    this.expandedBlockIds = const {},
    this.capturePage,
    this.savedAt,
    this.structuredRunning,
    this.steadyStateTimers = const {},
    this.timedRunning = const {},
  });

  static const currentSchemaVersion = 4;

  final int schemaVersion;
  final String athleteId;
  final String assignmentId;
  final int trainingSessionId;
  final String? occurrenceId;
  final String? activeBlockId;
  final int? activeBlockIndex;
  final String? activeExerciseId;
  final int? activeExerciseIndex;
  final String? activeIntervalId;
  final Set<String> expandedBlockIds;
  final String? capturePage;
  final DateTime? savedAt;
  final StructuredRunningCursor? structuredRunning;
  final Map<String, SteadyStateTimerCursor> steadyStateTimers;
  final Map<String, StructuredRunningCursor> timedRunning;

  bool get isUnsupportedFutureVersion => schemaVersion > currentSchemaVersion;

  bool get hasInvalidStructuredScope =>
      structuredRunning != null &&
      (schemaVersion < 2 ||
          isUnsupportedFutureVersion ||
          activeBlockId != structuredRunning!.sessionBlockId);

  bool get hasInvalidSteadyStateScope =>
      steadyStateTimers.isNotEmpty &&
      (schemaVersion < 3 ||
          isUnsupportedFutureVersion ||
          activeBlockId?.isNotEmpty != true);

  bool get hasInvalidTimedRunningScope =>
      timedRunning.isNotEmpty &&
      (schemaVersion != currentSchemaVersion ||
          activeBlockId?.isNotEmpty != true ||
          timedRunning.keys.any(steadyStateTimers.containsKey) ||
          timedRunning.entries.any(
            (entry) => entry.key != entry.value.sessionBlockId,
          ) ||
          timedRunning.containsKey(structuredRunning?.sessionBlockId));

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'athlete_id': athleteId,
      'assignment_id': assignmentId,
      'training_session_id': trainingSessionId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (activeBlockId != null) 'active_block_id': activeBlockId,
      if (activeBlockIndex != null) 'active_block_index': activeBlockIndex,
      if (activeExerciseId != null) 'active_exercise_id': activeExerciseId,
      if (activeExerciseIndex != null)
        'active_exercise_index': activeExerciseIndex,
      if (activeIntervalId != null) 'active_interval_id': activeIntervalId,
      'expanded_block_ids': expandedBlockIds.toList()..sort(),
      if (capturePage != null) 'capture_page': capturePage,
      if (savedAt != null) 'saved_at': savedAt!.toUtc().toIso8601String(),
      if (structuredRunning != null)
        'structured_running': structuredRunning!.toJson(),
      if (steadyStateTimers.isNotEmpty)
        'steady_state_timers': [
          for (final timer in steadyStateTimers.values) timer.toJson(),
        ],
      if (timedRunning.isNotEmpty)
        'authored_timed_runs': [
          for (final cursor in timedRunning.values) cursor.toJson(),
        ],
    };
  }

  factory ProductionSessionUiCursor.fromJson(Map<String, dynamic> json) {
    final expandedRaw = json['expanded_block_ids'];
    final structuredRaw = json['structured_running'];
    final steadyRaw = json['steady_state_timers'];
    final steadyTimers = <String, SteadyStateTimerCursor>{};
    if (json.containsKey('steady_state_timers')) {
      if (steadyRaw is! List ||
          (json['schema_version'] != 3 &&
              json['schema_version'] != currentSchemaVersion)) {
        throw const FormatException('Invalid steady-state timer scope.');
      }
      for (final raw in steadyRaw) {
        if (raw is! Map) {
          throw const FormatException('Invalid steady-state timer.');
        }
        final timer = SteadyStateTimerCursor.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (steadyTimers.containsKey(timer.blockId)) {
          throw const FormatException('Duplicate steady-state timer.');
        }
        steadyTimers[timer.blockId] = timer;
      }
    }
    final timed = <String, StructuredRunningCursor>{};
    if (json.containsKey('authored_timed_runs')) {
      final raw = json['authored_timed_runs'];
      if (json['schema_version'] != currentSchemaVersion || raw is! List) {
        throw const FormatException('Invalid authored timed run scope.');
      }
      for (final value in raw) {
        if (value is! Map) {
          throw const FormatException('Invalid authored timed run.');
        }
        final cursor = StructuredRunningCursor.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (timed.containsKey(cursor.sessionBlockId)) {
          throw const FormatException('Duplicate authored timed run.');
        }
        timed[cursor.sessionBlockId] = cursor;
      }
    }
    if (json.containsKey('structured_running') && structuredRaw is! Map) {
      throw const FormatException('invalid structured running cursor payload');
    }
    final cursor = ProductionSessionUiCursor(
      schemaVersion: json['schema_version'] as int? ?? 0,
      athleteId: json['athlete_id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      trainingSessionId: json['training_session_id'] as int? ?? 0,
      occurrenceId: json['occurrence_id'] as String?,
      activeBlockId: json['active_block_id'] as String?,
      activeBlockIndex: json['active_block_index'] as int?,
      activeExerciseId: json['active_exercise_id'] as String?,
      activeExerciseIndex: json['active_exercise_index'] as int?,
      activeIntervalId: json['active_interval_id'] as String?,
      expandedBlockIds: expandedRaw is List
          ? expandedRaw.map((e) => e.toString()).toSet()
          : const {},
      capturePage: json['capture_page'] as String?,
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? ''),
      structuredRunning: structuredRaw is Map
          ? StructuredRunningCursor.fromJson(
              Map<String, dynamic>.from(structuredRaw),
            )
          : null,
      steadyStateTimers: Map.unmodifiable(steadyTimers),
      timedRunning: Map.unmodifiable(timed),
    );
    if (cursor.hasInvalidStructuredScope ||
        cursor.hasInvalidSteadyStateScope ||
        cursor.hasInvalidTimedRunningScope) {
      throw const FormatException('invalid structured running cursor scope');
    }
    return cursor;
  }
}
