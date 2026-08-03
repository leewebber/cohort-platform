import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';

/// Read boundary for the bounded scheduling operation log (Undo eligibility).
abstract class ProgrammeScheduleOperationsStore {
  /// Latest successful undoable mutation for [assignmentId], if any.
  Future<ProgrammeSchedulingUndoableOperation?> latestUndoableOperation({
    required String assignmentId,
  });
}
