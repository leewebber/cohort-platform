import '../models/programme_schedule_apply.dart';

/// Persistence port for confirmed Move/Swap apply only.
abstract class ProgrammeScheduleApplyStore {
  Future<ProgrammeScheduleApplyResult> apply(
    ProgrammeScheduleApplyCommand command,
  );
}
