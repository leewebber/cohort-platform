import '../../models/programme_slot_outcome.dart';
import 'programme_slot_outcome_delete_result.dart';

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

  /// Deletes all outcomes for [assignmentId] and returns how many rows were removed.
  ///
  /// Callers that expect existing rows must verify [ProgrammeSlotOutcomeDeleteResult.deletedCount]
  /// matches the pre-delete count — RLS may block DELETE without raising an error.
  Future<ProgrammeSlotOutcomeDeleteResult> deleteOutcomesForAssignment({
    required String assignmentId,
  });
}
