import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_version_day.dart';
import '../../../models/programme_version_session_slot.dart';
import '../../../models/programme_vocabulary.dart';
import 'programme_suggested_cursor.dart';
import 'programme_template.dart';

/// Read-only schedule resolution for an assignment cursor.
enum ProgrammeScheduleResolutionKind {
  executableSlot,
  restDay,
  dayComplete,
  programmeComplete,
}

class ProgrammeScheduleResolution {
  const ProgrammeScheduleResolution({
    required this.kind,
    required this.assignment,
    required this.tree,
    required this.weekNumber,
    required this.dayKey,
    this.day,
    this.slot,
    this.slotOutcome,
    this.outcomeStatus,
    this.plannedProtocolId,
    this.effectiveProtocolId,
    this.isOptional = false,
    this.suggestedNextCursor,
    this.optionalUnresolvedSlots = const [],
  });

  final ProgrammeScheduleResolutionKind kind;
  final ProgrammeAssignment assignment;
  final ProgrammeTemplateTree tree;
  final int weekNumber;
  final String dayKey;
  final ProgrammeVersionDay? day;
  final ProgrammeVersionSessionSlot? slot;
  final ProgrammeSlotOutcome? slotOutcome;
  final ProgrammeSlotOutcomeStatus? outcomeStatus;
  final String? plannedProtocolId;
  final String? effectiveProtocolId;
  final bool isOptional;
  final ProgrammeSuggestedCursor? suggestedNextCursor;
  final List<ProgrammeVersionSessionSlot> optionalUnresolvedSlots;

  String get programmeName => tree.template.version.name;

  String get lineageCode => assignment.lineageCode;

  String get programmeVersionId => assignment.programmeVersionId;

  int get versionNumber => tree.template.version.versionNumber;

  bool get isRestDay => kind == ProgrammeScheduleResolutionKind.restDay;

  bool get isProgrammeComplete =>
      kind == ProgrammeScheduleResolutionKind.programmeComplete;

  bool get isDayComplete => kind == ProgrammeScheduleResolutionKind.dayComplete;

  bool get hasExecutableSlot =>
      kind == ProgrammeScheduleResolutionKind.executableSlot &&
      effectiveProtocolId != null;
}
