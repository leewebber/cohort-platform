import '../../../models/programme_vocabulary.dart';
import 'resolved_today_session.dart';

/// Lightweight programme slot context passed into execution views.
///
/// Contains only the fields required to link a [TrainingSession] back to
/// a programme assignment slot without re-resolving at session start.
class ProgrammeExecutionContext {
  const ProgrammeExecutionContext({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.sessionSlotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.plannedProtocolId,
    required this.effectiveProtocolId,
    this.lineageCode,
    this.programmeName,
  });

  final String assignmentId;
  final String programmeVersionId;
  final String sessionSlotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String plannedProtocolId;
  final String effectiveProtocolId;
  final String? lineageCode;
  final String? programmeName;

  bool get isProgrammeBacked =>
      assignmentId.isNotEmpty && sessionSlotId.isNotEmpty;

  factory ProgrammeExecutionContext.fromResolvedSession(
    ResolvedTodaySession resolution,
  ) {
    final assignmentId = resolution.assignmentId;
    final slotId = resolution.slotId;
    final versionId = resolution.programmeVersionId;
    final planned = resolution.plannedProtocolId;
    final effective = resolution.effectiveProtocolId;
    final week = resolution.weekNumber;
    final day = resolution.dayKey;
    final order = resolution.slotOrder;

    if (assignmentId == null ||
        slotId == null ||
        versionId == null ||
        planned == null ||
        effective == null ||
        week == null ||
        day == null ||
        order == null) {
      throw ArgumentError(
        'ResolvedTodaySession is missing programme execution context fields',
      );
    }

    return ProgrammeExecutionContext(
      assignmentId: assignmentId,
      programmeVersionId: versionId,
      sessionSlotId: slotId,
      weekNumber: week,
      dayKey: day,
      sessionOrder: order,
      plannedProtocolId: planned,
      effectiveProtocolId: effective,
      lineageCode: resolution.lineageCode,
      programmeName: resolution.programmeName,
    );
  }

  ResolvedTodaySession toResolvedSession() {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      lineageCode: lineageCode,
      programmeName: programmeName,
      weekNumber: weekNumber,
      dayKey: dayKey,
      slotId: sessionSlotId,
      slotOrder: sessionOrder,
      plannedProtocolId: plannedProtocolId,
      effectiveProtocolId: effectiveProtocolId,
      outcomeStatus: ProgrammeSlotOutcomeStatus.scheduled,
    );
  }
}
