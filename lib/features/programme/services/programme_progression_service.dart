import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_version_session_slot.dart';

/// Advances assignment cursor after slot and day resolution.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.7.
abstract class ProgrammeProgressionService {
  Future<ProgrammeAssignment> progressAfterSlotResolved({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  bool isDayComplete({
    required List<ProgrammeVersionSessionSlot> slots,
    required List<ProgrammeSlotOutcome> outcomes,
  });

  Future<ProgrammeAssignment> moveCursorTo({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
    int sessionOrder = 1,
  });
}
