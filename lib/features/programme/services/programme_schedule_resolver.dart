import '../../../models/programme_assignment.dart';
import '../../../models/programme_version_day.dart';
import '../../../models/programme_version_session_slot.dart';
import '../models/programme_template.dart';

/// Pure resolution over template + assignment cursor.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.4.
abstract class ProgrammeScheduleResolver {
  Future<ProgrammeTemplateTree> loadTemplateForAssignment(
    ProgrammeAssignment assignment,
  );

  ProgrammeTemplateDayNode? dayNodeForCursor({
    required ProgrammeTemplateTree tree,
    required int weekNumber,
    required String dayKey,
  });

  List<ProgrammeVersionSessionSlot> slotsForDay({
    required ProgrammeTemplateTree tree,
    required int weekNumber,
    required String dayKey,
  });

  ProgrammeVersionSessionSlot? slotForCursor({
    required ProgrammeTemplateTree tree,
    required ProgrammeAssignment assignment,
  });

  String? weekdayLabelForCursor({
    required ProgrammeAssignment assignment,
    required ProgrammeVersionDay day,
  });

  ProgrammeTemplateDayNode? nextDay({
    required ProgrammeTemplateTree tree,
    required int weekNumber,
    required String dayKey,
  });
}
