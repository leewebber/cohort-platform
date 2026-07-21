import '../../core/services/supabase_service.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_slot_outcome.dart';
import '../../models/programme_vocabulary.dart';
import 'programme_migration_planner_store.dart';
import 'programme_store_exception.dart';

class ProgrammeMigrationPlannerSupabaseStore
    extends ProgrammeMigrationPlannerStore {
  const ProgrammeMigrationPlannerSupabaseStore();

  static const _assignmentsTable = 'programme_assignments';
  static const _outcomesTable = 'programme_slot_outcomes';

  @override
  Future<List<ProgrammeAssignment>> listAssignmentsForPlanning({
    required String programmeVersionId,
    List<String>? assignmentIds,
  }) async {
    try {
      if (assignmentIds != null && assignmentIds.isNotEmpty) {
        final normalizedIds = assignmentIds.map((id) => id.trim()).toList();
        final response = await SupabaseService.client
            .from(_assignmentsTable)
            .select()
            .inFilter('id', normalizedIds)
            .eq('programme_version_id', programmeVersionId.trim());

        return response
            .map(
              (row) => ProgrammeAssignment.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      }

      final response = await SupabaseService.client
          .from(_assignmentsTable)
          .select()
          .eq('programme_version_id', programmeVersionId.trim())
          .eq('status', ProgrammeAssignmentStatus.active.dbValue)
          .order('id');

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
        fallbackMessage: 'Failed to load assignments for migration planning',
      );
    }
  }

  @override
  Future<Map<String, List<ProgrammeSlotOutcome>>> listOutcomesForAssignments(
    List<String> assignmentIds,
  ) async {
    if (assignmentIds.isEmpty) return const {};

    try {
      final response = await SupabaseService.client
          .from(_outcomesTable)
          .select()
          .inFilter('assignment_id', assignmentIds);

      final grouped = <String, List<ProgrammeSlotOutcome>>{};
      for (final row in List<Map<String, dynamic>>.from(response as List)) {
        final outcome = ProgrammeSlotOutcome.fromMap(row);
        grouped.putIfAbsent(outcome.assignmentId, () => []).add(outcome);
      }

      for (final outcomes in grouped.values) {
        outcomes.sort((a, b) {
          final weekCompare = a.weekNumber.compareTo(b.weekNumber);
          if (weekCompare != 0) return weekCompare;
          final dayCompare = a.dayKey.compareTo(b.dayKey);
          if (dayCompare != 0) return dayCompare;
          return a.sessionOrder.compareTo(b.sessionOrder);
        });
      }

      return grouped;
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load slot outcomes for migration planning',
      );
    }
  }
}
