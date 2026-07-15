import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/programme_schedule_resolution.dart';
import '../models/programme_suggested_cursor.dart';

/// Resolved Today's Session view for programme-driven Home entry.
enum ResolvedTodaySessionKind {
  noActiveProgramme,
  paused,
  executable,
  restDay,
  dayComplete,
  programmeComplete,
}

class ResolvedTodaySession {
  const ResolvedTodaySession({
    required this.kind,
    this.assignmentId,
    this.programmeVersionId,
    this.lineageCode,
    this.programmeName,
    this.versionNumber,
    this.weekNumber,
    this.dayKey,
    this.dayTitle,
    this.dayType,
    this.dayIntent,
    this.slotId,
    this.slotOrder,
    this.slotTitle,
    this.plannedProtocolId,
    this.effectiveProtocolId,
    this.outcomeStatus,
    this.isOptional = false,
    this.isRestDay = false,
    this.programmeComplete = false,
    this.suggestedNextCursor,
    this.optionalUnresolvedSlotCount = 0,
    this.assignment,
    this.slotOutcome,
  });

  final ResolvedTodaySessionKind kind;
  final String? assignmentId;
  final String? programmeVersionId;
  final String? lineageCode;
  final String? programmeName;
  final int? versionNumber;
  final int? weekNumber;
  final String? dayKey;
  final String? dayTitle;
  final ProgrammeDayType? dayType;
  final ProgrammeIntent? dayIntent;
  final String? slotId;
  final int? slotOrder;
  final String? slotTitle;
  final String? plannedProtocolId;
  final String? effectiveProtocolId;
  final ProgrammeSlotOutcomeStatus? outcomeStatus;
  final bool isOptional;
  final bool isRestDay;
  final bool programmeComplete;
  final ProgrammeSuggestedCursor? suggestedNextCursor;
  final int optionalUnresolvedSlotCount;

  /// Retained for debug/sync convenience.
  final ProgrammeAssignment? assignment;
  final ProgrammeSlotOutcome? slotOutcome;

  bool get hasExecutableSession =>
      kind == ResolvedTodaySessionKind.executable &&
      effectiveProtocolId != null;

  factory ResolvedTodaySession.noActiveProgramme() {
    return const ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.noActiveProgramme,
    );
  }

  factory ResolvedTodaySession.paused({
    required ProgrammeAssignment assignment,
    required String programmeName,
    required int versionNumber,
  }) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.paused,
      assignment: assignment,
      assignmentId: assignment.id,
      programmeVersionId: assignment.programmeVersionId,
      lineageCode: assignment.lineageCode,
      programmeName: programmeName,
      versionNumber: versionNumber,
      weekNumber: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
    );
  }

  factory ResolvedTodaySession.fromResolution(
    ProgrammeScheduleResolution resolution,
  ) {
    final day = resolution.day;
    final slot = resolution.slot;

    final kind = switch (resolution.kind) {
      ProgrammeScheduleResolutionKind.executableSlot =>
        ResolvedTodaySessionKind.executable,
      ProgrammeScheduleResolutionKind.restDay =>
        ResolvedTodaySessionKind.restDay,
      ProgrammeScheduleResolutionKind.dayComplete =>
        ResolvedTodaySessionKind.dayComplete,
      ProgrammeScheduleResolutionKind.programmeComplete =>
        ResolvedTodaySessionKind.programmeComplete,
    };

    return ResolvedTodaySession(
      kind: kind,
      assignment: resolution.assignment,
      assignmentId: resolution.assignment.id,
      programmeVersionId: resolution.programmeVersionId,
      lineageCode: resolution.lineageCode,
      programmeName: resolution.programmeName,
      versionNumber: resolution.versionNumber,
      weekNumber: resolution.weekNumber,
      dayKey: resolution.dayKey,
      dayTitle: day?.title,
      dayType: day?.dayType,
      dayIntent: day?.intent,
      slotId: slot?.id,
      slotOrder: slot?.sessionOrder,
      slotTitle: slot?.displayTitle,
      plannedProtocolId: resolution.plannedProtocolId,
      effectiveProtocolId: resolution.effectiveProtocolId,
      outcomeStatus: resolution.outcomeStatus,
      isOptional: resolution.isOptional,
      isRestDay: resolution.isRestDay,
      programmeComplete: resolution.isProgrammeComplete,
      suggestedNextCursor: resolution.suggestedNextCursor,
      optionalUnresolvedSlotCount: resolution.optionalUnresolvedSlots.length,
      slotOutcome: resolution.slotOutcome,
    );
  }

  @override
  String toString() {
    return 'ResolvedTodaySession(kind: $kind, lineage: $lineageCode, '
        'week: $weekNumber, day: $dayKey, slot: $slotOrder, '
        'planned: $plannedProtocolId, effective: $effectiveProtocolId, '
        'outcome: $outcomeStatus, suggestedNext: $suggestedNextCursor)';
  }
}
