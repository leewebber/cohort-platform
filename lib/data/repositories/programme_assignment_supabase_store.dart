import '../../core/services/supabase_service.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_vocabulary.dart';
import 'programme_assignment_store.dart';
import 'programme_store_exception.dart';

/// Supabase implementation of [ProgrammeAssignmentStore].
class ProgrammeAssignmentSupabaseStore implements ProgrammeAssignmentStore {
  const ProgrammeAssignmentSupabaseStore();

  static const _tableName = 'programme_assignments';

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('athlete_id', athleteId.trim())
          .eq('status', ProgrammeAssignmentStatus.active.dbValue)
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeAssignment.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch active programme assignment',
      );
    }
  }

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('id', assignmentId.trim())
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeAssignment.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme assignment',
      );
    }
  }

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) async {
    if (assignment.isActive) {
      final existingActive = await getActiveAssignment(assignment.athleteId);
      if (existingActive != null) {
        throw ProgrammeStoreException(
          'Athlete already has an active programme assignment',
          code: '23505',
        );
      }
    }

    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .insert(assignment.toInsertMap())
          .select()
          .single();

      return ProgrammeAssignment.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to create programme assignment',
      );
    }
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) async {
    if (assignment.isActive) {
      final existingActive = await getActiveAssignment(assignment.athleteId);
      if (existingActive != null && existingActive.id != assignment.id) {
        throw ProgrammeStoreException(
          'Athlete already has a different active programme assignment',
          code: '23505',
        );
      }
    }

    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .update(assignment.toInsertMap())
          .eq('id', assignment.id)
          .select()
          .single();

      return ProgrammeAssignment.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to update programme assignment',
      );
    }
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('athlete_id', athleteId.trim())
          .order('created_at', ascending: false);

      return response
          .map(
            (row) => ProgrammeAssignment.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to list programme assignments',
      );
    }
  }
}
