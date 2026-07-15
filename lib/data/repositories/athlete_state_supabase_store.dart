import '../../core/services/supabase_service.dart';
import '../../models/athlete_state.dart';
import 'athlete_state_store.dart';
import 'programme_store_exception.dart';

/// Supabase implementation of [AthleteStateStore].
class AthleteStateSupabaseStore implements AthleteStateStore {
  const AthleteStateSupabaseStore();

  static const _tableName = 'athlete_state';
  static const _upsertConflict = 'athlete_id';

  @override
  Future<AthleteState?> getByAthleteId(String athleteId) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('athlete_id', athleteId.trim())
          .maybeSingle();

      if (response == null) return null;

      return AthleteState.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch athlete state projection',
        operation: 'getByAthleteId',
        tableName: _tableName,
      );
    }
  }

  @override
  Future<void> upsertProjection(AthleteState projection) async {
    try {
      await SupabaseService.client.from(_tableName).upsert(
        projection.toUpsertMap(),
        onConflict: _upsertConflict,
      );
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage:
            'Failed to upsert athlete state projection — ensure '
            'athlete_state_athlete_id_unique constraint exists',
        operation: 'upsertProjection',
        tableName: _tableName,
        conflictTarget: _upsertConflict,
      );
    }
  }

  @override
  Future<void> clearProgrammeProjection(String athleteId) async {
    try {
      await SupabaseService.client
          .from(_tableName)
          .update(AthleteState(
            athleteId: athleteId,
          ).toProgrammeProjectionClearMap())
          .eq('athlete_id', athleteId.trim());
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to clear athlete programme projection',
        operation: 'clearProgrammeProjection',
        tableName: _tableName,
      );
    }
  }
}
