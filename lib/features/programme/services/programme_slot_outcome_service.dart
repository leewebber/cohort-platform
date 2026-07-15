import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/resolved_today_session.dart';

/// Bridges Execution Engine events to programme slot outcomes.
///
/// Slot outcomes are separate from `training_sessions.status`.
/// See `43_Programme_Engine_Service_Contracts.md` §3.6.
abstract class ProgrammeSlotOutcomeService {
  /// Upserts a slot outcome with full cursor context from [resolution].
  Future<ProgrammeSlotOutcome> upsertFromResolution({
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    DateTime? resolvedAt,
  });
}
