import '../athlete_daily/athlete_session_occurrence_index.dart';
import '../session_occurrence.dart';
import '../value_objects/session_occurrence_audit_entry.dart';
import '../vocabulary/session_occurrence_completion_status.dart';
import '../vocabulary/session_occurrence_lifecycle_state.dart';
import 'programme_scheduled_slot_input.dart';
import 'programme_session_occurrence_creation_result.dart';
import 'programme_session_occurrence_registry.dart';
import 'session_occurrence_id.dart';

/// Creates [SessionOccurrence] instances from programme scheduling inputs.
class ProgrammeSessionOccurrenceFactory {
  const ProgrammeSessionOccurrenceFactory();

  ProgrammeSessionOccurrenceCreationResult createFromScheduledSlot({
    required ProgrammeScheduledSlotInput input,
    required DateTime recordedAt,
    required ProgrammeSessionOccurrenceRegistry registry,
    AthleteSessionOccurrenceIndex? athleteIndex,
  }) {
    final validation = _validateInput(input);
    if (validation != null) return validation;

    final key = input.slotKey;
    final existing = registry.occurrenceForSlot(key);
    if (existing != null) {
      if (existing.sourceSessionId.trim() != input.sourceSessionId.trim()) {
        return ProgrammeSessionOccurrenceCreationResult.singleFailure(
          ProgrammeSessionOccurrenceCreationIssueCode.sourceSessionConflict,
          detail: existing.sourceSessionId,
        );
      }
      return ProgrammeSessionOccurrenceCreationResult.singleFailure(
        ProgrammeSessionOccurrenceCreationIssueCode.duplicateSlotOccurrence,
      );
    }

    final occurrenceId = SessionOccurrenceId.forProgrammeSlot(key);
    final occurrence = SessionOccurrence(
      occurrenceId: occurrenceId,
      sourceSessionId: input.sourceSessionId.trim(),
      programmeAssignmentId: input.programmeAssignmentId.trim(),
      programmeSessionSlotId: input.programmeSessionSlotId.trim(),
      originalPlannedDate: input.plannedDate,
      plannedDate: input.plannedDate,
      currentDate: input.plannedDate,
      lifecycleState: SessionOccurrenceLifecycleState.scheduled,
      completionStatus: SessionOccurrenceCompletionStatus.pending,
      rescheduleHistory: const [],
      auditTrail: [
        SessionOccurrenceAuditEntry(
          eventType: SessionOccurrenceAuditEventType.scheduled,
          recordedAt: recordedAt,
          detail: 'programme_slot',
        ),
      ],
    );

    registry.register(occurrence);
    athleteIndex?.register(
      athleteId: input.athleteId.trim(),
      occurrence: occurrence,
    );
    return ProgrammeSessionOccurrenceCreationResult.success(occurrence);
  }

  /// Idempotent materialization — returns existing occurrence when slot already registered.
  ProgrammeSessionOccurrenceCreationResult ensureFromScheduledSlot({
    required ProgrammeScheduledSlotInput input,
    required DateTime recordedAt,
    required ProgrammeSessionOccurrenceRegistry registry,
    AthleteSessionOccurrenceIndex? athleteIndex,
  }) {
    final key = input.slotKey;
    final existing = registry.occurrenceForSlot(key);
    if (existing != null) {
      if (existing.sourceSessionId.trim() != input.sourceSessionId.trim()) {
        return ProgrammeSessionOccurrenceCreationResult.singleFailure(
          ProgrammeSessionOccurrenceCreationIssueCode.sourceSessionConflict,
        );
      }
      return ProgrammeSessionOccurrenceCreationResult.success(existing);
    }
    return createFromScheduledSlot(
      input: input,
      recordedAt: recordedAt,
      registry: registry,
      athleteIndex: athleteIndex,
    );
  }

  ProgrammeSessionOccurrenceCreationResult? _validateInput(
    ProgrammeScheduledSlotInput input,
  ) {
    if (input.programmeAssignmentId.trim().isEmpty) {
      return ProgrammeSessionOccurrenceCreationResult.singleFailure(
        ProgrammeSessionOccurrenceCreationIssueCode.invalidAssignmentId,
      );
    }
    if (input.programmeSessionSlotId.trim().isEmpty) {
      return ProgrammeSessionOccurrenceCreationResult.singleFailure(
        ProgrammeSessionOccurrenceCreationIssueCode.invalidSessionSlotId,
      );
    }
    if (input.athleteId.trim().isEmpty) {
      return ProgrammeSessionOccurrenceCreationResult.singleFailure(
        ProgrammeSessionOccurrenceCreationIssueCode.invalidAthleteId,
      );
    }
    if (input.sourceSessionId.trim().isEmpty) {
      return ProgrammeSessionOccurrenceCreationResult.singleFailure(
        ProgrammeSessionOccurrenceCreationIssueCode.invalidSourceSessionId,
      );
    }
    return null;
  }
}
