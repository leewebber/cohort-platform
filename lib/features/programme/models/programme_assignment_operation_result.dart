import '../../../models/programme_assignment.dart';
import 'resolved_today_session.dart';

/// Typed assignment workflow status.
enum ProgrammeAssignmentOperationStatus {
  assigned,
  partialSuccess,
  alreadyActiveConflict,
  replaced,
  paused,
  resumed,
  completed,
  invalidProgrammeVersion,
  noAssignment,
  failed,
}

/// Result of a programme assignment lifecycle operation.
class ProgrammeAssignmentOperationResult {
  const ProgrammeAssignmentOperationResult({
    required this.status,
    this.assignment,
    this.resolvedTodaySession,
    this.athleteStateSynced = false,
    this.warnings = const [],
    this.replacedAssignmentId,
  });

  final ProgrammeAssignmentOperationStatus status;
  final ProgrammeAssignment? assignment;
  final ResolvedTodaySession? resolvedTodaySession;
  final bool athleteStateSynced;
  final List<String> warnings;
  final String? replacedAssignmentId;

  bool get isSuccess =>
      status == ProgrammeAssignmentOperationStatus.assigned ||
      status == ProgrammeAssignmentOperationStatus.replaced ||
      status == ProgrammeAssignmentOperationStatus.paused ||
      status == ProgrammeAssignmentOperationStatus.resumed ||
      status == ProgrammeAssignmentOperationStatus.completed ||
      status == ProgrammeAssignmentOperationStatus.partialSuccess;

  factory ProgrammeAssignmentOperationResult.conflict({
    required ProgrammeAssignment existing,
  }) {
    return ProgrammeAssignmentOperationResult(
      status: ProgrammeAssignmentOperationStatus.alreadyActiveConflict,
      assignment: existing,
      warnings: [
        'Athlete already has active assignment ${existing.id}',
      ],
    );
  }

  factory ProgrammeAssignmentOperationResult.invalidVersion({
    required String message,
  }) {
    return ProgrammeAssignmentOperationResult(
      status: ProgrammeAssignmentOperationStatus.invalidProgrammeVersion,
      warnings: [message],
    );
  }

  factory ProgrammeAssignmentOperationResult.noAssignment({
    String? message,
  }) {
    return ProgrammeAssignmentOperationResult(
      status: ProgrammeAssignmentOperationStatus.noAssignment,
      warnings: message == null ? const [] : [message],
    );
  }

  factory ProgrammeAssignmentOperationResult.failed({
    required String message,
  }) {
    return ProgrammeAssignmentOperationResult(
      status: ProgrammeAssignmentOperationStatus.failed,
      warnings: [message],
    );
  }

  @override
  String toString() {
    return 'ProgrammeAssignmentOperationResult(status: $status, '
        'assignment: ${assignment?.id}, '
        'resolved: ${resolvedTodaySession?.kind}, '
        'synced: $athleteStateSynced, '
        'replacedAssignmentId: $replacedAssignmentId, '
        'warnings: $warnings)';
  }
}
