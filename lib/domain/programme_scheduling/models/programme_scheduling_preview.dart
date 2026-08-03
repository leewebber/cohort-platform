import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../vocabulary/programme_schedule_disposition.dart';
import '../vocabulary/programme_scheduling_operation_type.dart';
import '../vocabulary/programme_scheduling_preview_code.dart';
import '../value_objects/scheduled_occurrence_identity.dart';
import 'programme_schedule_projection.dart';

/// One proposed change for athlete review.
class ProgrammeSchedulingOccurrenceChange {
  const ProgrammeSchedulingOccurrenceChange({
    required this.identity,
    required this.originalDate,
    required this.proposedDate,
    required this.originalDisposition,
    required this.proposedDisposition,
  });

  final ScheduledOccurrenceIdentity identity;
  final SessionOccurrenceDate originalDate;
  final SessionOccurrenceDate proposedDate;
  final ProgrammeScheduleDisposition originalDisposition;
  final ProgrammeScheduleDisposition proposedDisposition;

  Map<String, Object?> toCanonicalMap() => {
    'identity': identity.toCanonicalMap(),
    'originalDate': originalDate.toString(),
    'proposedDate': proposedDate.toString(),
    'originalDisposition': originalDisposition.name,
    'proposedDisposition': proposedDisposition.name,
  };
}

/// Non-mutating impact surfaced by preview.
enum ProgrammeSchedulingImpactKind {
  multiSessionDateCollision,
  preparedOccurrenceAffected,
  adaptedPreparedOccurrenceAffected,
  pendingAdaptationProposalWouldBeDiscarded,
  consumedProposalIdsRemainConsumed,
  skipDispositionProposed,
  cursorWouldAdvanceTo,
  becomesOverdue,
  undoPolicyNote,
}

class ProgrammeSchedulingImpact {
  const ProgrammeSchedulingImpact({
    required this.kind,
    required this.message,
    this.sessionSlotId,
    this.date,
    this.relatedSlotIds = const [],
  });

  final ProgrammeSchedulingImpactKind kind;
  final String message;
  final String? sessionSlotId;
  final SessionOccurrenceDate? date;
  final List<String> relatedSlotIds;

  Map<String, Object?> toCanonicalMap() => {
    'kind': kind.name,
    'message': message,
    'sessionSlotId': sessionSlotId,
    'date': date?.toString(),
    'relatedSlotIds': relatedSlotIds,
  };
}

/// Successful compute-only preview.
class ProgrammeSchedulingPreview {
  const ProgrammeSchedulingPreview({
    required this.operationType,
    required this.fingerprint,
    required this.proposedProjection,
    required this.changes,
    required this.impacts,
    required this.collidingDates,
  });

  final ProgrammeSchedulingOperationType operationType;
  final String fingerprint;
  final ProgrammeScheduleProjection proposedProjection;
  final List<ProgrammeSchedulingOccurrenceChange> changes;
  final List<ProgrammeSchedulingImpact> impacts;

  /// Dates that would hold more than one uncompleted occurrence after apply.
  final List<SessionOccurrenceDate> collidingDates;
}

/// Typed compute-only preview result (no exceptions for business outcomes).
class ProgrammeSchedulingPreviewResult {
  const ProgrammeSchedulingPreviewResult._({
    required this.code,
    this.preview,
    this.detail,
  });

  factory ProgrammeSchedulingPreviewResult.ready(
    ProgrammeSchedulingPreview preview,
  ) {
    return ProgrammeSchedulingPreviewResult._(
      code: ProgrammeSchedulingPreviewCode.previewReady,
      preview: preview,
    );
  }

  factory ProgrammeSchedulingPreviewResult.ineligible(
    ProgrammeSchedulingPreviewCode code, {
    String? detail,
  }) {
    assert(code != ProgrammeSchedulingPreviewCode.previewReady);
    return ProgrammeSchedulingPreviewResult._(code: code, detail: detail);
  }

  final ProgrammeSchedulingPreviewCode code;
  final ProgrammeSchedulingPreview? preview;
  final String? detail;

  bool get isReady =>
      code == ProgrammeSchedulingPreviewCode.previewReady && preview != null;
}
