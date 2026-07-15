import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_version_session_slot.dart';

/// Bridges Execution Engine events to programme slot outcomes.
///
/// Slot outcomes are separate from `training_sessions.status`.
/// See `43_Programme_Engine_Service_Contracts.md` §3.6.
abstract class ProgrammeSlotOutcomeService {
  Future<ProgrammeSlotOutcome> markScheduled({
    required String assignmentId,
    required ProgrammeVersionSessionSlot slot,
    required int weekNumber,
    required String dayKey,
  });

  Future<ProgrammeSlotOutcome> markInProgress({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  Future<ProgrammeSlotOutcome> markCompleted({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  /// Session ended early — does not advance programme day.
  Future<ProgrammeSlotOutcome> markCompletedPartial({
    required String assignmentId,
    required String sessionSlotId,
    required int trainingSessionId,
  });

  Future<ProgrammeSlotOutcome> markSkipped({
    required String assignmentId,
    required String sessionSlotId,
  });

  Future<ProgrammeSlotOutcome> markReplaced({
    required String assignmentId,
    required String sessionSlotId,
    required String resolvedProtocolId,
    int? trainingSessionId,
  });
}
