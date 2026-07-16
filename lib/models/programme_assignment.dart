import 'programme_vocabulary.dart';

/// Athlete enrolment on a published programme version.
///
/// Source of truth for cursor position and Today's Session resolution.
/// `athlete_state` is a denormalised projection — see `AthleteStateSyncService`.
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeAssignment {
  const ProgrammeAssignment({
    required this.id,
    required this.athleteId,
    required this.programmeVersionId,
    required this.lineageCode,
    required this.status,
    required this.startedAt,
    this.currentWeek = 1,
    this.currentDayKey = 'day_1',
    this.currentSessionOrder = 1,
    this.completedAt,
    this.pausedAt,
    this.timezone,
    this.supersededByAssignmentId,
    this.lastProgressedTrainingSessionId,
    this.createdAt,
    this.updatedAt,
  });

  /// UUID primary key.
  final String id;

  final String athleteId;

  /// Pinned immutable `programme_versions.id`.
  final String programmeVersionId;

  /// Denormalised human code — matches `programme_lineages.code` and
  /// `training_sessions.programme_id`.
  final String lineageCode;

  final ProgrammeAssignmentStatus status;

  /// Calendar anchor for weekday label derivation.
  final DateTime startedAt;

  /// Cursor: current week (1-based).
  final int currentWeek;

  /// Cursor: ordinal day key — `day_1`, `day_2`, …
  final String currentDayKey;

  /// Cursor: which slot when multiple exist on the day.
  final int currentSessionOrder;

  final DateTime? completedAt;
  final DateTime? pausedAt;

  /// IANA timezone for weekday derivation.
  final String? timezone;

  /// Set when this assignment is superseded by reassignment.
  final String? supersededByAssignmentId;

  /// Idempotency guard — last session that advanced the cursor.
  final int? lastProgressedTrainingSessionId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == ProgrammeAssignmentStatus.active;

  bool get isPaused => status == ProgrammeAssignmentStatus.paused;

  /// Pre-persist assignment draft — [id] is empty until the store inserts.
  factory ProgrammeAssignment.forCreate({
    required String athleteId,
    required String programmeVersionId,
    required String lineageCode,
    required DateTime startedAt,
    String? timezone,
    int currentWeek = 1,
    String currentDayKey = 'day_1',
    int currentSessionOrder = 1,
  }) {
    return ProgrammeAssignment(
      id: '',
      athleteId: athleteId,
      programmeVersionId: programmeVersionId,
      lineageCode: lineageCode,
      status: ProgrammeAssignmentStatus.active,
      startedAt: startedAt,
      timezone: timezone,
      currentWeek: currentWeek,
      currentDayKey: currentDayKey,
      currentSessionOrder: currentSessionOrder,
    );
  }

  factory ProgrammeAssignment.fromMap(Map<String, dynamic> map) {
    return ProgrammeAssignment(
      id: _trimStringRequired(map['id']),
      athleteId: _trimStringRequired(map['athlete_id']),
      programmeVersionId: _trimStringRequired(map['programme_version_id']),
      lineageCode: _trimStringRequired(map['lineage_code']),
      status: ProgrammeAssignmentStatusDb.fromDb(map['status']?.toString()),
      startedAt: _parseDateRequired(map['started_at']),
      currentWeek: map['current_week_number'] ?? map['current_week'] ?? 1,
      currentDayKey: _trimString(map['current_day_key']) ?? 'day_1',
      currentSessionOrder:
          map['current_slot_order'] ?? map['current_session_order'] ?? 1,
      completedAt: _parseDateTime(map['completed_at']),
      pausedAt: _parseDateTime(map['paused_at']),
      timezone: _trimString(map['timezone']),
      supersededByAssignmentId: _trimString(map['superseded_by_assignment_id']),
      lastProgressedTrainingSessionId:
          _nullableInt(map['last_progressed_training_session_id']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  /// Insert payload for a new row — never includes [id].
  ///
  /// Database default `gen_random_uuid()` assigns the primary key.
  Map<String, dynamic> toInsertMap() {
    return {
      'athlete_id': athleteId,
      'programme_version_id': programmeVersionId,
      'lineage_code': lineageCode,
      'status': status.dbValue,
      'started_at': _formatDate(startedAt),
      'current_week_number': currentWeek,
      'current_day_key': currentDayKey,
      'current_slot_order': currentSessionOrder,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (pausedAt != null) 'paused_at': pausedAt!.toIso8601String(),
      if (timezone != null) 'timezone': timezone,
      if (supersededByAssignmentId != null)
        'superseded_by_assignment_id': supersededByAssignmentId,
      if (lastProgressedTrainingSessionId != null)
        'last_progressed_training_session_id': lastProgressedTrainingSessionId,
    };
  }

  /// Update payload — excludes [id]; filter updates by persisted UUID in store.
  Map<String, dynamic> toUpdateMap() => toInsertMap();

  ProgrammeAssignment copyWith({
    String? id,
    String? athleteId,
    String? programmeVersionId,
    String? lineageCode,
    ProgrammeAssignmentStatus? status,
    DateTime? startedAt,
    int? currentWeek,
    String? currentDayKey,
    int? currentSessionOrder,
    DateTime? completedAt,
    DateTime? pausedAt,
    String? timezone,
    String? supersededByAssignmentId,
    int? lastProgressedTrainingSessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCompletedAt = false,
    bool clearPausedAt = false,
    bool clearTimezone = false,
    bool clearSupersededByAssignmentId = false,
    bool clearLastProgressedTrainingSessionId = false,
  }) {
    return ProgrammeAssignment(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      programmeVersionId: programmeVersionId ?? this.programmeVersionId,
      lineageCode: lineageCode ?? this.lineageCode,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDayKey: currentDayKey ?? this.currentDayKey,
      currentSessionOrder: currentSessionOrder ?? this.currentSessionOrder,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      timezone: clearTimezone ? null : (timezone ?? this.timezone),
      supersededByAssignmentId: clearSupersededByAssignmentId
          ? null
          : (supersededByAssignmentId ?? this.supersededByAssignmentId),
      lastProgressedTrainingSessionId: clearLastProgressedTrainingSessionId
          ? null
          : (lastProgressedTrainingSessionId ??
              this.lastProgressedTrainingSessionId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }

  static DateTime _parseDateRequired(dynamic value) {
    final parsed = _parseDateTime(value);
    if (parsed != null) return parsed;

    throw FormatException('ProgrammeAssignment.started_at is required');
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
