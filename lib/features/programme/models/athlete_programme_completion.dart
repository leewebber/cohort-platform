import '../../../models/programme_assignment.dart';
import '../../performance/models/training_session_record.dart';

/// Stable outcomes from Sprint 1.5A atomic completion + advancement.
enum AthleteProgrammeCompletionStatus {
  committed,
  alreadyCommitted,
  submitting,
  recovering,
  assignmentMissing,
  assignmentInactive,
  assignmentNotMaterialised,
  exactVersionMissing,
  packageHashMismatch,
  invalidCurrentCursor,
  authoredProtocolMismatch,
  programmeKeyMismatch,
  preparedProvenanceMismatch,
  completionValidationFailure,
  staleCursor,
  idempotencyPayloadConflict,
  logicalCompletionPayloadConflict,
  terminalUnsupported,
  crossAthleteAssignment,
  authenticationRequired,
  networkUncertain,
  failure,
}

class AthleteProgrammeCompletionResult {
  const AthleteProgrammeCompletionResult({
    required this.status,
    this.code,
    this.message,
    this.record,
    this.assignment,
    this.logicalCompletionKey,
    this.programmedSessionKey,
    this.idempotencyKey,
    this.terminalProgramme = false,
    this.nextWeek,
    this.nextDayKey,
    this.nextSlotOrder,
    this.nextProtocolId,
  });

  final AthleteProgrammeCompletionStatus status;
  final String? code;
  final String? message;
  final TrainingSessionRecord? record;
  final ProgrammeAssignment? assignment;
  final String? logicalCompletionKey;
  final String? programmedSessionKey;
  final String? idempotencyKey;
  final bool terminalProgramme;
  final int? nextWeek;
  final String? nextDayKey;
  final int? nextSlotOrder;
  final String? nextProtocolId;

  bool get isSuccess =>
      status == AthleteProgrammeCompletionStatus.committed ||
      status == AthleteProgrammeCompletionStatus.alreadyCommitted;

  bool get isConflict =>
      status == AthleteProgrammeCompletionStatus.staleCursor ||
      status == AthleteProgrammeCompletionStatus.idempotencyPayloadConflict ||
      status ==
          AthleteProgrammeCompletionStatus.logicalCompletionPayloadConflict ||
      status == AthleteProgrammeCompletionStatus.programmeKeyMismatch ||
      status == AthleteProgrammeCompletionStatus.authoredProtocolMismatch ||
      status == AthleteProgrammeCompletionStatus.packageHashMismatch;

  bool get isRecoverable =>
      status == AthleteProgrammeCompletionStatus.networkUncertain ||
      status == AthleteProgrammeCompletionStatus.recovering;

  factory AthleteProgrammeCompletionResult.fromRpc(Map<String, dynamic> map) {
    final status = (map['status']?.toString() ?? '').trim();
    final code = map['code']?.toString();
    final assignmentMap = map['assignment'];
    ProgrammeAssignment? assignment;
    if (assignmentMap is Map) {
      final raw = Map<String, dynamic>.from(assignmentMap);
      // RPC assignment projection omits athlete_id/lineage; reconcile later.
      raw.putIfAbsent('athlete_id', () => '');
      raw.putIfAbsent('lineage_code', () => '');
      try {
        assignment = ProgrammeAssignment.fromMap(raw);
      } catch (_) {
        assignment = null;
      }
    }

    TrainingSessionRecord? record;
    final recordMap = map['completion_record'];
    if (recordMap is Map) {
      record = TrainingSessionRecord.fromMap(
        Map<String, dynamic>.from(recordMap),
      );
    }

    final next = map['next_cursor'];
    Map<String, dynamic>? nextMap;
    if (next is Map) {
      nextMap = Map<String, dynamic>.from(next);
    }

    return AthleteProgrammeCompletionResult(
      status: _mapStatus(status, code),
      code: code,
      message: map['message']?.toString(),
      record: record,
      assignment: assignment,
      logicalCompletionKey: map['logical_completion_key']?.toString(),
      programmedSessionKey: map['programmed_session_key']?.toString(),
      terminalProgramme: map['terminal_programme'] == true,
      nextWeek: nextMap == null
          ? null
          : (nextMap['week_number'] as num?)?.toInt(),
      nextDayKey: nextMap?['day_key']?.toString(),
      nextSlotOrder: nextMap == null
          ? null
          : (nextMap['slot_order'] as num?)?.toInt(),
      nextProtocolId: nextMap?['protocol_id']?.toString(),
    );
  }

  static AthleteProgrammeCompletionStatus _mapStatus(
    String status,
    String? code,
  ) {
    switch (status) {
      case 'committed':
        return AthleteProgrammeCompletionStatus.committed;
      case 'already_committed':
        return AthleteProgrammeCompletionStatus.alreadyCommitted;
      case 'authorization_failure':
        if (code == 'cross_athlete_assignment') {
          return AthleteProgrammeCompletionStatus.crossAthleteAssignment;
        }
        return AthleteProgrammeCompletionStatus.authenticationRequired;
      case 'conflict':
        return switch (code) {
          'stale_cursor' => AthleteProgrammeCompletionStatus.staleCursor,
          'idempotency_payload_conflict' =>
            AthleteProgrammeCompletionStatus.idempotencyPayloadConflict,
          'logical_completion_payload_conflict' =>
            AthleteProgrammeCompletionStatus.logicalCompletionPayloadConflict,
          _ => AthleteProgrammeCompletionStatus.failure,
        };
      case 'validation_failure':
        return switch (code) {
          'assignment_missing' =>
            AthleteProgrammeCompletionStatus.assignmentMissing,
          'assignment_inactive' =>
            AthleteProgrammeCompletionStatus.assignmentInactive,
          'assignment_not_materialised' =>
            AthleteProgrammeCompletionStatus.assignmentNotMaterialised,
          'exact_version_missing' =>
            AthleteProgrammeCompletionStatus.exactVersionMissing,
          'package_hash_mismatch' =>
            AthleteProgrammeCompletionStatus.packageHashMismatch,
          'invalid_current_cursor' =>
            AthleteProgrammeCompletionStatus.invalidCurrentCursor,
          'authored_protocol_mismatch' =>
            AthleteProgrammeCompletionStatus.authoredProtocolMismatch,
          'programme_key_mismatch' =>
            AthleteProgrammeCompletionStatus.programmeKeyMismatch,
          'prepared_provenance_mismatch' =>
            AthleteProgrammeCompletionStatus.preparedProvenanceMismatch,
          'terminal_cursor_unsupported' =>
            AthleteProgrammeCompletionStatus.terminalUnsupported,
          'completion_validation_failure' =>
            AthleteProgrammeCompletionStatus.completionValidationFailure,
          'client_nominated_authority_forbidden' =>
            AthleteProgrammeCompletionStatus.completionValidationFailure,
          _ => AthleteProgrammeCompletionStatus.failure,
        };
      default:
        return AthleteProgrammeCompletionStatus.failure;
    }
  }
}
