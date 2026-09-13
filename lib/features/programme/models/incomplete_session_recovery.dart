import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import 'fixed_programme_occurrence_projection.dart';

/// Eligibility for Train today / Backfill / Reschedule on a past unfinished session.
abstract final class IncompleteSessionRecovery {
  static bool belongsToActiveAssignment({
    required FixedProgrammeOccurrenceProjection occurrence,
    required FixedProgrammeCalendarProjection calendar,
    required String athleteAssignmentId,
  }) {
    return occurrence.assignmentId == calendar.assignmentId &&
        occurrence.assignmentId == athleteAssignmentId;
  }

  static bool isPastUnfinished({
    required FixedProgrammeOccurrenceProjection occurrence,
    required FixedProgrammeCalendarProjection calendar,
  }) {
    return occurrence.scheduledDate.compareTo(calendar.today) < 0 &&
        occurrence.isDateDerivedUnfinished;
  }

  static bool hasValidCompletedResult(TrainingSessionRecord? record) {
    return record != null &&
        record.status == TrainingSessionRecordStatus.completed;
  }

  static bool isInProgress(FixedProgrammeOccurrenceProjection occurrence) {
    return occurrence.isResumable;
  }

  static bool canTrainToday({
    required FixedProgrammeOccurrenceProjection occurrence,
    required FixedProgrammeCalendarProjection calendar,
    required String athleteAssignmentId,
    TrainingSessionRecord? existingRecord,
  }) {
    if (!belongsToActiveAssignment(
      occurrence: occurrence,
      calendar: calendar,
      athleteAssignmentId: athleteAssignmentId,
    )) {
      return false;
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.skipped) {
      return false;
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.completed) {
      return false;
    }
    if (hasValidCompletedResult(existingRecord)) return false;
    if (isInProgress(occurrence)) return false;
    return isPastUnfinished(occurrence: occurrence, calendar: calendar) &&
        occurrence.isExecutable;
  }

  static bool canBackfill({
    required FixedProgrammeOccurrenceProjection occurrence,
    required FixedProgrammeCalendarProjection calendar,
    required String athleteAssignmentId,
    required bool backendSupported,
    TrainingSessionRecord? existingRecord,
  }) {
    if (!backendSupported) return false;
    if (!belongsToActiveAssignment(
      occurrence: occurrence,
      calendar: calendar,
      athleteAssignmentId: athleteAssignmentId,
    )) {
      return false;
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.skipped) {
      return false;
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.completed) {
      return false;
    }
    if (hasValidCompletedResult(existingRecord)) return false;
    if (isInProgress(occurrence)) return false;
    return isPastUnfinished(occurrence: occurrence, calendar: calendar) &&
        occurrence.canOfferHistoricalBackfill;
  }

  static bool canReschedule({
    required FixedProgrammeOccurrenceProjection occurrence,
    required FixedProgrammeCalendarProjection calendar,
    required String athleteAssignmentId,
    TrainingSessionRecord? existingRecord,
  }) {
    return canTrainToday(
      occurrence: occurrence,
      calendar: calendar,
      athleteAssignmentId: athleteAssignmentId,
      existingRecord: existingRecord,
    );
  }
}
