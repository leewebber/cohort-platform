import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import 'resolved_today_session.dart';

/// Typed progression workflow status.
enum ProgrammeProgressionStatus {
  completed,
  partialSuccess,
  staleResolution,
  programmeComplete,
  noActiveProgramme,
}

/// Result of a programme progression workflow.
class ProgrammeProgressionResult {
  const ProgrammeProgressionResult({
    required this.status,
    this.outcome,
    this.updatedAssignment,
    this.nextResolvedSession,
    this.athleteStateSynced = false,
    this.warnings = const [],
  });

  final ProgrammeProgressionStatus status;
  final ProgrammeSlotOutcome? outcome;
  final ProgrammeAssignment? updatedAssignment;
  final ResolvedTodaySession? nextResolvedSession;
  final bool athleteStateSynced;
  final List<String> warnings;

  bool get isSuccess =>
      status == ProgrammeProgressionStatus.completed ||
      status == ProgrammeProgressionStatus.programmeComplete;

  factory ProgrammeProgressionResult.noActiveProgramme() {
    return const ProgrammeProgressionResult(
      status: ProgrammeProgressionStatus.noActiveProgramme,
    );
  }

  factory ProgrammeProgressionResult.staleResolution({
    required String message,
  }) {
    return ProgrammeProgressionResult(
      status: ProgrammeProgressionStatus.staleResolution,
      warnings: [message],
    );
  }

  factory ProgrammeProgressionResult.completed({
    required ProgrammeSlotOutcome outcome,
    required ProgrammeAssignment updatedAssignment,
    required ResolvedTodaySession nextResolvedSession,
    required bool athleteStateSynced,
    List<String> warnings = const [],
  }) {
    final status = nextResolvedSession.kind ==
            ResolvedTodaySessionKind.programmeComplete
        ? ProgrammeProgressionStatus.programmeComplete
        : ProgrammeProgressionStatus.completed;

    return ProgrammeProgressionResult(
      status: status,
      outcome: outcome,
      updatedAssignment: updatedAssignment,
      nextResolvedSession: nextResolvedSession,
      athleteStateSynced: athleteStateSynced,
      warnings: warnings,
    );
  }

  factory ProgrammeProgressionResult.partialSuccess({
    required ProgrammeSlotOutcome outcome,
    ProgrammeAssignment? updatedAssignment,
    ResolvedTodaySession? nextResolvedSession,
    required List<String> warnings,
  }) {
    return ProgrammeProgressionResult(
      status: ProgrammeProgressionStatus.partialSuccess,
      outcome: outcome,
      updatedAssignment: updatedAssignment,
      nextResolvedSession: nextResolvedSession,
      warnings: warnings,
    );
  }

  @override
  String toString() {
    return 'ProgrammeProgressionResult(status: $status, outcome: $outcome, '
        'assignment: ${updatedAssignment?.currentWeek}/'
        '${updatedAssignment?.currentDayKey}/'
        '${updatedAssignment?.currentSessionOrder}, '
        'next: $nextResolvedSession, synced: $athleteStateSynced, '
        'warnings: $warnings)';
  }
}
