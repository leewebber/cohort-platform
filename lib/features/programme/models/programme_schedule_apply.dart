import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'programme_schedule_persistence.dart';

/// Closed Move/Swap command envelope for exact-preview apply (Sprint 1.7D).
sealed class ProgrammeScheduleApplyCommand {
  const ProgrammeScheduleApplyCommand({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.expectedScheduleRevision,
    required this.previewFingerprint,
    required this.idempotencyKey,
    this.policyVersion = ProgrammeSchedulingApplyFingerprint.policyVersion,
  });

  final String assignmentId;
  final String programmeVersionId;
  final String packageContentHash;
  final int expectedScheduleRevision;
  final String previewFingerprint;
  final String idempotencyKey;
  final String policyVersion;

  String get operationType;

  Map<String, Object?> toRpcPayload();
}

class ProgrammeScheduleMoveCommand extends ProgrammeScheduleApplyCommand {
  const ProgrammeScheduleMoveCommand({
    required super.assignmentId,
    required super.programmeVersionId,
    required super.packageContentHash,
    required super.expectedScheduleRevision,
    required super.previewFingerprint,
    required super.idempotencyKey,
    required this.sessionSlotId,
    required this.targetDate,
    super.policyVersion,
  });

  final String sessionSlotId;
  final SessionOccurrenceDate targetDate;

  @override
  String get operationType => 'move';

  @override
  Map<String, Object?> toRpcPayload() => {
    'operation_type': operationType,
    'assignment_id': assignmentId,
    'programme_version_id': programmeVersionId,
    'package_content_hash': packageContentHash,
    'expected_schedule_revision': expectedScheduleRevision,
    'policy_version': policyVersion,
    'preview_fingerprint': previewFingerprint,
    'idempotency_key': idempotencyKey,
    'session_slot_id': sessionSlotId,
    'target_date': targetDate.toString(),
  };
}

class ProgrammeScheduleSwapCommand extends ProgrammeScheduleApplyCommand {
  const ProgrammeScheduleSwapCommand({
    required super.assignmentId,
    required super.programmeVersionId,
    required super.packageContentHash,
    required super.expectedScheduleRevision,
    required super.previewFingerprint,
    required super.idempotencyKey,
    required this.sessionSlotIdA,
    required this.sessionSlotIdB,
    super.policyVersion,
  });

  final String sessionSlotIdA;
  final String sessionSlotIdB;

  @override
  String get operationType => 'swap';

  @override
  Map<String, Object?> toRpcPayload() => {
    'operation_type': operationType,
    'assignment_id': assignmentId,
    'programme_version_id': programmeVersionId,
    'package_content_hash': packageContentHash,
    'expected_schedule_revision': expectedScheduleRevision,
    'policy_version': policyVersion,
    'preview_fingerprint': previewFingerprint,
    'idempotency_key': idempotencyKey,
    'session_slot_id_a': sessionSlotIdA,
    'session_slot_id_b': sessionSlotIdB,
  };
}

enum ProgrammeScheduleApplyStatus {
  applied,
  alreadyApplied,
  noChange,
  assignmentNotFound,
  assignmentNotOwned,
  assignmentPaused,
  assignmentIneligible,
  occurrenceNotFound,
  provenanceMismatch,
  occurrenceCompleted,
  occurrenceAlreadySkipped,
  inFlightExecution,
  invalidDate,
  beforeAssignmentStart,
  horizonExceeded,
  swapRequiresDistinctOccurrences,
  crossAssignmentOrVersionSwap,
  staleScheduleRevision,
  stalePreviewFingerprint,
  idempotencyKeyConflict,
  malformedRequest,
  unsupportedOperation,
  inconsistentProjection,
  persistenceUnavailable,
  authoritativeReloadRequired,
  projectionAbsent,
  conflict,
  failed,
}

class ProgrammeScheduleApplyResult {
  const ProgrammeScheduleApplyResult({
    required this.status,
    this.code,
    this.message,
    this.assignmentId,
    this.scheduleRevision,
    this.operationType,
    this.previewFingerprint,
    this.clearedProgrammedSessionKeys = const [],
    this.projection,
    this.undoExpiresAt,
  });

  final ProgrammeScheduleApplyStatus status;
  final String? code;
  final String? message;
  final String? assignmentId;
  final int? scheduleRevision;
  final String? operationType;
  final String? previewFingerprint;
  final List<String> clearedProgrammedSessionKeys;
  final PersistedProgrammeScheduleProjection? projection;
  final DateTime? undoExpiresAt;

  bool get isSuccess =>
      status == ProgrammeScheduleApplyStatus.applied ||
      status == ProgrammeScheduleApplyStatus.alreadyApplied;

  bool get requiresReload =>
      status == ProgrammeScheduleApplyStatus.staleScheduleRevision ||
      status == ProgrammeScheduleApplyStatus.stalePreviewFingerprint ||
      status == ProgrammeScheduleApplyStatus.authoritativeReloadRequired;

  factory ProgrammeScheduleApplyResult.fromRpcMap(Map<String, dynamic> map) {
    final statusRaw = map['status']?.toString() ?? 'failed';
    final code = map['code']?.toString();
    PersistedProgrammeScheduleProjection? projection;
    final projRaw = map['projection'];
    if (projRaw is Map<String, dynamic>) {
      projection = PersistedProgrammeScheduleProjection.fromMap(projRaw);
    } else if (projRaw is Map) {
      projection = PersistedProgrammeScheduleProjection.fromMap(
        Map<String, dynamic>.from(projRaw),
      );
    }
    final cleared = <String>[];
    final clearedRaw = map['cleared_programmed_session_keys'];
    if (clearedRaw is List) {
      for (final item in clearedRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) cleared.add(text);
      }
    }
    return ProgrammeScheduleApplyResult(
      status: _statusFromRpc(statusRaw, code),
      code: code,
      message: map['message']?.toString(),
      assignmentId: map['assignment_id']?.toString(),
      scheduleRevision: _nullableInt(map['schedule_revision']),
      operationType: map['operation_type']?.toString(),
      previewFingerprint: map['preview_fingerprint']?.toString(),
      clearedProgrammedSessionKeys: List.unmodifiable(cleared),
      projection: projection,
      undoExpiresAt: DateTime.tryParse(map['undo_expires_at']?.toString() ?? ''),
    );
  }
}

ProgrammeScheduleApplyStatus _statusFromRpc(String status, String? code) {
  switch (status) {
    case 'applied':
      return ProgrammeScheduleApplyStatus.applied;
    case 'already_applied':
      return ProgrammeScheduleApplyStatus.alreadyApplied;
    case 'no_change':
      return ProgrammeScheduleApplyStatus.noChange;
    case 'unsupported':
      return ProgrammeScheduleApplyStatus.unsupportedOperation;
    case 'authorization_failure':
      if (code == 'assignment_not_found') {
        return ProgrammeScheduleApplyStatus.assignmentNotFound;
      }
      return ProgrammeScheduleApplyStatus.assignmentNotOwned;
    case 'ineligible':
      switch (code) {
        case 'assignment_paused':
          return ProgrammeScheduleApplyStatus.assignmentPaused;
        case 'occurrence_not_found':
          return ProgrammeScheduleApplyStatus.occurrenceNotFound;
        case 'occurrence_completed':
          return ProgrammeScheduleApplyStatus.occurrenceCompleted;
        case 'occurrence_already_skipped':
          return ProgrammeScheduleApplyStatus.occurrenceAlreadySkipped;
        case 'before_assignment_start':
          return ProgrammeScheduleApplyStatus.beforeAssignmentStart;
        case 'swap_requires_distinct_occurrences':
          return ProgrammeScheduleApplyStatus.swapRequiresDistinctOccurrences;
        default:
          return ProgrammeScheduleApplyStatus.assignmentIneligible;
      }
    case 'conflict':
      switch (code) {
        case 'stale_schedule_revision':
          return ProgrammeScheduleApplyStatus.staleScheduleRevision;
        case 'stale_preview_fingerprint':
          return ProgrammeScheduleApplyStatus.stalePreviewFingerprint;
        case 'idempotency_key_conflict':
          return ProgrammeScheduleApplyStatus.idempotencyKeyConflict;
        case 'provenance_mismatch':
          return ProgrammeScheduleApplyStatus.provenanceMismatch;
        case 'cross_assignment_or_version_swap':
          return ProgrammeScheduleApplyStatus.crossAssignmentOrVersionSwap;
        default:
          return ProgrammeScheduleApplyStatus.conflict;
      }
    case 'validation_failure':
      if (code == 'projection_absent') {
        return ProgrammeScheduleApplyStatus.projectionAbsent;
      }
      return ProgrammeScheduleApplyStatus.malformedRequest;
    default:
      return ProgrammeScheduleApplyStatus.failed;
  }
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
