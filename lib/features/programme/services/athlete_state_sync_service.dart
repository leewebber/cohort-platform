import '../../../models/programme_assignment.dart';

/// Denormalised projection writer for `athlete_state` programme fields.
///
/// `ProgrammeAssignment` remains the source of truth.
/// See `43_Programme_Engine_Service_Contracts.md` §3.8.
abstract class AthleteStateSyncService {
  Future<void> syncFromAssignment({
    required ProgrammeAssignment assignment,
    String? resolvedProtocolId,
    String? sessionStatus,
  });

  Future<void> clearProgrammeProjection(String athleteId);
}
