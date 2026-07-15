import '../../../models/programme_vocabulary.dart';
import '../models/programme_progression_result.dart';
import '../models/resolved_today_session.dart';

/// Advances assignment cursor after slot and day resolution.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.7.
abstract class ProgrammeProgressionService {
  Future<ProgrammeProgressionResult> markSessionStarted({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
  });

  Future<ProgrammeProgressionResult> completeSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  });

  Future<ProgrammeProgressionResult> completeSessionPartial({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  });

  Future<ProgrammeProgressionResult> skipSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    String? resolutionNote,
  });

  Future<ProgrammeProgressionResult> replaceSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required String replacementProtocolId,
    int? trainingSessionId,
    String? resolutionNote,
  });

  Future<ProgrammeProgressionResult> resolveAfterOutcome({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    bool advanceCursor = true,
  });
}
