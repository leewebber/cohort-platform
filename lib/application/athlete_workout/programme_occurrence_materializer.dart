import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';

/// Maps programme [ResolvedTodaySession] into domain occurrences (bridge only).
class ProgrammeOccurrenceMaterializer {
  const ProgrammeOccurrenceMaterializer({
    ProgrammeSessionOccurrenceFactory? factory,
  }) : _factory = factory ?? const ProgrammeSessionOccurrenceFactory();

  final ProgrammeSessionOccurrenceFactory _factory;

  /// Ensures a [SessionOccurrence] exists for an executable programme slot.
  ///
  /// Returns null when the resolution lacks required slot metadata.
  SessionOccurrence? materializeExecutable({
    required String athleteId,
    required ResolvedTodaySession programmeSession,
    required SessionOccurrenceDate calendarDate,
    required DateTime recordedAt,
    required ProgrammeSessionOccurrenceRegistry slotRegistry,
    required SessionOccurrenceRepository occurrenceRepository,
  }) {
    if (programmeSession.kind != ResolvedTodaySessionKind.executable) {
      return null;
    }

    final assignmentId = programmeSession.assignmentId?.trim();
    final slotId = programmeSession.slotId?.trim();
    final protocolId = programmeSession.effectiveProtocolId?.trim();
    if (assignmentId == null ||
        assignmentId.isEmpty ||
        slotId == null ||
        slotId.isEmpty ||
        protocolId == null ||
        protocolId.isEmpty) {
      return null;
    }

    final result = _factory.ensureFromScheduledSlot(
      input: ProgrammeScheduledSlotInput(
        programmeAssignmentId: assignmentId,
        programmeSessionSlotId: slotId,
        athleteId: athleteId.trim(),
        sourceSessionId: protocolId,
        plannedDate: calendarDate,
      ),
      recordedAt: recordedAt,
      registry: slotRegistry,
      occurrenceRepository: occurrenceRepository,
    );

    return result.isSuccess ? result.occurrence : null;
  }
}
