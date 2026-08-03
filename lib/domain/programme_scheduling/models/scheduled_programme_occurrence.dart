import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../vocabulary/programme_schedule_disposition.dart';
import '../value_objects/scheduled_occurrence_identity.dart';

/// One authored occurrence with athlete-intended calendar placement.
class ScheduledProgrammeOccurrence {
  const ScheduledProgrammeOccurrence({
    required this.identity,
    required this.scheduledDate,
    required this.disposition,
    this.hasInFlightExecution = false,
  });

  final ScheduledOccurrenceIdentity identity;
  final SessionOccurrenceDate scheduledDate;
  final ProgrammeScheduleDisposition disposition;
  final bool hasInFlightExecution;

  bool get isUncompleted =>
      disposition == ProgrammeScheduleDisposition.scheduled;

  bool get isSkipped => disposition == ProgrammeScheduleDisposition.skipped;

  bool get isCompleted =>
      disposition == ProgrammeScheduleDisposition.completed;

  ScheduledProgrammeOccurrence copyWith({
    SessionOccurrenceDate? scheduledDate,
    ProgrammeScheduleDisposition? disposition,
    bool? hasInFlightExecution,
  }) {
    return ScheduledProgrammeOccurrence(
      identity: identity,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      disposition: disposition ?? this.disposition,
      hasInFlightExecution: hasInFlightExecution ?? this.hasInFlightExecution,
    );
  }

  Map<String, Object?> toCanonicalMap() => {
    'identity': identity.toCanonicalMap(),
    'scheduledDate': scheduledDate.toString(),
    'disposition': disposition.name,
    'hasInFlightExecution': hasInFlightExecution,
  };

  @override
  bool operator ==(Object other) {
    return other is ScheduledProgrammeOccurrence &&
        other.identity == identity &&
        other.scheduledDate == scheduledDate &&
        other.disposition == disposition &&
        other.hasInFlightExecution == hasInFlightExecution;
  }

  @override
  int get hashCode => Object.hash(
    identity,
    scheduledDate,
    disposition,
    hasInFlightExecution,
  );
}
