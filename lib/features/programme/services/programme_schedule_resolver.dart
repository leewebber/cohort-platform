import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../models/programme_schedule_resolution.dart';
import '../models/programme_suggested_cursor.dart';
import '../models/programme_template.dart';

/// Pure read-only programme schedule resolver contract.
abstract class ProgrammeScheduleResolver {
  ProgrammeScheduleResolution resolve({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
  });

  /// Resolves the initial assignment cursor from programme structure.
  ///
  /// Never assumes week 1 / day_1 / slot 1 exists.
  ProgrammeSuggestedCursor resolveInitialCursor({
    required ProgrammeTemplateTree tree,
  });
}
