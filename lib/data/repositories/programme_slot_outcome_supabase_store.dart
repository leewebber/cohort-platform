import '../../core/services/supabase_service.dart';
import '../../models/programme_slot_outcome.dart';
import 'programme_slot_outcome_store.dart';
import 'programme_store_exception.dart';

/// Supabase implementation of [ProgrammeSlotOutcomeStore].
class ProgrammeSlotOutcomeSupabaseStore implements ProgrammeSlotOutcomeStore {
  const ProgrammeSlotOutcomeSupabaseStore();

  static const _tableName = 'programme_slot_outcomes';
  static const _upsertConflict = 'assignment_id,session_slot_id';

  @override
  Future<ProgrammeSlotOutcome?> getForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .eq('session_slot_id', sessionSlotId.trim())
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeSlotOutcome.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme slot outcome',
      );
    }
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForAssignment(
    String assignmentId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .order('week_number', ascending: true)
          .order('session_order', ascending: true);

      return response
          .map(
            (row) => ProgrammeSlotOutcome.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to list programme slot outcomes',
      );
    }
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForDay({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
  }) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .eq('week_number', weekNumber)
          .eq('day_key', dayKey.trim())
          .order('session_order', ascending: true);

      return response
          .map(
            (row) => ProgrammeSlotOutcome.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to list programme slot outcomes for day',
      );
    }
  }

  @override
  Future<ProgrammeSlotOutcome> upsert(ProgrammeSlotOutcome outcome) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .upsert(
            outcome.toUpsertMap(),
            onConflict: _upsertConflict,
          )
          .select()
          .single();

      return ProgrammeSlotOutcome.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to upsert programme slot outcome',
      );
    }
  }
}
