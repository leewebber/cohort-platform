import '../../models/athlete_state.dart';

/// Persistence boundary for denormalised athlete read model.
///
/// See `43_Programme_Engine_Service_Contracts.md` §2.4.
abstract class AthleteStateStore {
  Future<AthleteState?> getByAthleteId(String athleteId);

  Future<void> upsertProjection(AthleteState projection);

  Future<void> clearProgrammeProjection(String athleteId);
}
