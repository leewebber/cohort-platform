import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../models/programme_schedule_projection.dart';
import '../models/scheduled_programme_occurrence.dart';
import '../vocabulary/programme_schedule_disposition.dart';
import '../value_objects/scheduled_occurrence_identity.dart';
import 'session_occurrence_date_arithmetic.dart';

/// Authored slot descriptor used to derive a baseline projection in tests.
class BaselineAuthoredSlot {
  const BaselineAuthoredSlot({
    required this.sessionSlotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.protocolId,
    required this.programmedSessionKey,
  });

  final String sessionSlotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String protocolId;
  final String programmedSessionKey;
}

/// Builds the contract baseline projection:
/// walk authored order from [startedAt], one executable slot per local day.
class BaselineProgrammeScheduleProjection {
  const BaselineProgrammeScheduleProjection._();

  static ProgrammeScheduleProjection build({
    required String assignmentId,
    required String programmeVersionId,
    required String packageContentHash,
    required SessionOccurrenceDate startedAt,
    required List<BaselineAuthoredSlot> authoredSlots,
    int scheduleRevision = 0,
    Set<String> completedSessionSlotIds = const {},
    Set<String> skippedSessionSlotIds = const {},
  }) {
    final sorted = List<BaselineAuthoredSlot>.from(authoredSlots)
      ..sort((a, b) {
        final ka = ScheduledOccurrenceIdentity(
          assignmentId: assignmentId,
          programmeVersionId: programmeVersionId,
          packageContentHash: packageContentHash,
          sessionSlotId: a.sessionSlotId,
          weekNumber: a.weekNumber,
          dayKey: a.dayKey,
          sessionOrder: a.sessionOrder,
          protocolId: a.protocolId,
          programmedSessionKey: a.programmedSessionKey,
        ).authoredOrderKey;
        final kb = ScheduledOccurrenceIdentity(
          assignmentId: assignmentId,
          programmeVersionId: programmeVersionId,
          packageContentHash: packageContentHash,
          sessionSlotId: b.sessionSlotId,
          weekNumber: b.weekNumber,
          dayKey: b.dayKey,
          sessionOrder: b.sessionOrder,
          protocolId: b.protocolId,
          programmedSessionKey: b.programmedSessionKey,
        ).authoredOrderKey;
        return ka.compareTo(kb);
      });

    final occurrences = <ScheduledProgrammeOccurrence>[];
    var cursor = startedAt;
    for (final slot in sorted) {
      final identity = ScheduledOccurrenceIdentity(
        assignmentId: assignmentId,
        programmeVersionId: programmeVersionId,
        packageContentHash: packageContentHash,
        sessionSlotId: slot.sessionSlotId,
        weekNumber: slot.weekNumber,
        dayKey: slot.dayKey,
        sessionOrder: slot.sessionOrder,
        protocolId: slot.protocolId,
        programmedSessionKey: slot.programmedSessionKey,
      );
      final disposition = completedSessionSlotIds.contains(slot.sessionSlotId)
          ? ProgrammeScheduleDisposition.completed
          : skippedSessionSlotIds.contains(slot.sessionSlotId)
          ? ProgrammeScheduleDisposition.skipped
          : ProgrammeScheduleDisposition.scheduled;
      occurrences.add(
        ScheduledProgrammeOccurrence(
          identity: identity,
          scheduledDate: cursor,
          disposition: disposition,
        ),
      );
      cursor = cursor.addCalendarDays(1);
    }

    return ProgrammeScheduleProjection(
      occurrences: occurrences,
      scheduleRevision: scheduleRevision,
    );
  }
}
