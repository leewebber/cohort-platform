import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_version_session_slot.dart';

/// Resolved Today's Session view for Home and session entry.
///
/// See `43_Programme_Engine_Service_Contracts.md` §4.2.
enum ResolvedTodaySessionKind {
  planned,
  inProgress,
  completed,
  completedPartial,
  restDay,
  paused,
  noAssignment,
}

class ResolvedTodaySession {
  const ResolvedTodaySession({
    required this.kind,
    this.assignment,
    this.lineageCode,
    this.versionNumber,
    this.weekNumber,
    this.dayKey,
    this.weekdayLabel,
    this.slot,
    this.effectiveProtocolId,
    this.slotOutcome,
    this.trainingSessionId,
  });

  final ResolvedTodaySessionKind kind;
  final ProgrammeAssignment? assignment;
  final String? lineageCode;
  final int? versionNumber;
  final int? weekNumber;
  final String? dayKey;
  final String? weekdayLabel;
  final ProgrammeVersionSessionSlot? slot;
  final String? effectiveProtocolId;
  final ProgrammeSlotOutcome? slotOutcome;
  final int? trainingSessionId;

  bool get hasExecutableSession {
    return kind == ResolvedTodaySessionKind.planned ||
        kind == ResolvedTodaySessionKind.inProgress ||
        kind == ResolvedTodaySessionKind.completedPartial;
  }

  factory ResolvedTodaySession.noAssignment() {
    return const ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.noAssignment,
    );
  }

  factory ResolvedTodaySession.paused({
    required ProgrammeAssignment assignment,
  }) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.paused,
      assignment: assignment,
      lineageCode: assignment.lineageCode,
      weekNumber: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
    );
  }

  factory ResolvedTodaySession.restDay({
    required ProgrammeAssignment assignment,
    required int versionNumber,
    required String weekdayLabel,
  }) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.restDay,
      assignment: assignment,
      lineageCode: assignment.lineageCode,
      versionNumber: versionNumber,
      weekNumber: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
      weekdayLabel: weekdayLabel,
    );
  }
}
