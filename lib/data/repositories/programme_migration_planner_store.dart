import '../../models/programme_assignment.dart';
import '../../models/programme_slot_outcome.dart';

/// Read-only persistence boundary for migration planning (M10.3).
abstract class ProgrammeMigrationPlannerStore {
  const ProgrammeMigrationPlannerStore();

  Future<List<ProgrammeAssignment>> listAssignmentsForPlanning({
    required String programmeVersionId,
    List<String>? assignmentIds,
  });

  Future<Map<String, List<ProgrammeSlotOutcome>>> listOutcomesForAssignments(
    List<String> assignmentIds,
  );
}

class ProgrammeMigrationPlannerStoreException implements Exception {
  const ProgrammeMigrationPlannerStoreException(this.message);

  final String message;

  @override
  String toString() => 'ProgrammeMigrationPlannerStoreException: $message';
}
