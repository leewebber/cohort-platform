import '../models/programme_scheduling_snapshot.dart';
import '../models/scheduled_programme_occurrence.dart';
import '../support/session_occurrence_date_arithmetic.dart';
import '../vocabulary/programme_scheduling_assignment_status.dart';
import '../vocabulary/programme_scheduling_operation_type.dart';
import '../vocabulary/programme_scheduling_preview_code.dart';
import '../../session_occurrence/value_objects/session_occurrence_date.dart';

/// Typed policy decision for scheduling eligibility.
class ProgrammeSchedulingPolicyDecision {
  const ProgrammeSchedulingPolicyDecision.allow()
    : code = ProgrammeSchedulingPreviewCode.previewReady,
      detail = null;

  const ProgrammeSchedulingPolicyDecision.reject(
    this.code, {
    this.detail,
  }) : assert(code != ProgrammeSchedulingPreviewCode.previewReady);

  final ProgrammeSchedulingPreviewCode code;
  final String? detail;

  bool get isAllowed => code == ProgrammeSchedulingPreviewCode.previewReady;
}

/// Central scheduling policy boundary (default-allow; no package permission fields).
///
/// Plan Package remains prescription authority, not scheduling-permission authority.
/// Future restrictions can plug into this boundary without changing preview semantics.
class ProgrammeSchedulingPolicy {
  const ProgrammeSchedulingPolicy({
    this.version = ProgrammeSchedulingSnapshot.defaultPolicyVersion,
    this.undoTtlAthleteLocalHours = defaultUndoTtlAthleteLocalHours,
  });

  static const defaultUndoTtlAthleteLocalHours = 72;

  final String version;

  /// Default undo eligibility window (modelled only in Sprint 1.7B).
  final int undoTtlAthleteLocalHours;

  /// Default Phase 1: Move/Swap/Push/Skip are allowed when eligibility holds.
  bool isOperationDefaultAllowed(ProgrammeSchedulingOperationType type) {
    switch (type) {
      case ProgrammeSchedulingOperationType.move:
      case ProgrammeSchedulingOperationType.swap:
      case ProgrammeSchedulingOperationType.push:
      case ProgrammeSchedulingOperationType.skip:
        return true;
    }
  }

  ProgrammeSchedulingPolicyDecision evaluateAssignment(
    ProgrammeSchedulingSnapshot snapshot,
  ) {
    if (snapshot.assignmentStatus ==
        ProgrammeSchedulingAssignmentStatus.paused) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.assignmentPaused,
        detail: 'Paused assignments block scheduling preview and mutation.',
      );
    }
    if (snapshot.assignmentStatus ==
        ProgrammeSchedulingAssignmentStatus.completed) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.unsupportedOrMalformedRequest,
        detail: 'Completed assignments are not eligible for scheduling ops.',
      );
    }
    return const ProgrammeSchedulingPolicyDecision.allow();
  }

  ProgrammeSchedulingPolicyDecision evaluateOccurrenceEligibility(
    ScheduledProgrammeOccurrence occurrence, {
    required bool allowSkipped,
  }) {
    if (occurrence.hasInFlightExecution) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.inFlightExecution,
      );
    }
    if (occurrence.isCompleted) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.occurrenceCompleted,
      );
    }
    if (occurrence.isSkipped && !allowSkipped) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.occurrenceAlreadySkipped,
      );
    }
    return const ProgrammeSchedulingPolicyDecision.allow();
  }

  ProgrammeSchedulingPolicyDecision evaluateTargetDate({
    required SessionOccurrenceDate targetDate,
    required SessionOccurrenceDate startedAt,
  }) {
    if (targetDate.isBefore(startedAt)) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.beforeAssignmentStart,
      );
    }
    return const ProgrammeSchedulingPolicyDecision.allow();
  }

  ProgrammeSchedulingPolicyDecision evaluatePushDistance(int dayDelta) {
    if (dayDelta <= 0) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.invalidPushDistance,
        detail: 'Push requires a positive calendar-day delta.',
      );
    }
    return const ProgrammeSchedulingPolicyDecision.allow();
  }

  ProgrammeSchedulingPolicyDecision evaluateHorizon({
    required SessionOccurrenceDate proposedDate,
    required SessionOccurrenceDate? horizonEnd,
  }) {
    if (horizonEnd != null && proposedDate.isAfter(horizonEnd)) {
      return const ProgrammeSchedulingPolicyDecision.reject(
        ProgrammeSchedulingPreviewCode.horizonExceeded,
      );
    }
    return const ProgrammeSchedulingPolicyDecision.allow();
  }

  /// Undo eligibility inputs for later persistence/undo sprints.
  ///
  /// Sprint 1.7B models policy only; it does not restore snapshots.
  bool isWithinUndoTtl({
    required DateTime operationCompletedAt,
    required DateTime nowAthleteLocal,
  }) {
    final elapsed = nowAthleteLocal.difference(operationCompletedAt);
    return !elapsed.isNegative &&
        elapsed.inHours < undoTtlAthleteLocalHours;
  }
}
