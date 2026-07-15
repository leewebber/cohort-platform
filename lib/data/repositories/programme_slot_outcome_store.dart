import '../../models/programme_slot_outcome.dart';

/// Persistence boundary for per-assignment slot outcomes.
///
/// See `43_Programme_Engine_Service_Contracts.md` §2.3.
abstract class ProgrammeSlotOutcomeStore {
  Future<ProgrammeSlotOutcome?> getForSlot({
    required String assignmentId,
    required String sessionSlotId,
  });

  Future<List<ProgrammeSlotOutcome>> listForAssignment(String assignmentId);

  Future<List<ProgrammeSlotOutcome>> listForDay({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
  });

  Future<ProgrammeSlotOutcome> upsert(ProgrammeSlotOutcome outcome);
}
