import '../../programme/models/programme_assignment_operation_result.dart';
import '../../programme/models/programme_progression_result.dart';

/// Typed rules for when DEBUG programme mutations should refresh Home Today.
class HomeDebugProgrammeRefreshPolicy {
  const HomeDebugProgrammeRefreshPolicy._();

  static bool shouldRefreshAfterAssign(
    ProgrammeAssignmentOperationResult result,
  ) {
    return switch (result.status) {
      ProgrammeAssignmentOperationStatus.assigned ||
      ProgrammeAssignmentOperationStatus.replaced ||
      ProgrammeAssignmentOperationStatus.partialSuccess =>
        result.assignment != null,
      ProgrammeAssignmentOperationStatus.alreadyActiveConflict =>
        false,
      _ => false,
    };
  }

  static bool shouldRefreshAfterReset(
    ProgrammeAssignmentOperationResult result,
  ) {
    return switch (result.status) {
      ProgrammeAssignmentOperationStatus.assigned ||
      ProgrammeAssignmentOperationStatus.partialSuccess =>
        result.assignment != null,
      _ => false,
    };
  }

  static bool shouldRefreshAfterProgression(ProgrammeProgressionResult result) {
    return switch (result.status) {
      ProgrammeProgressionStatus.completed ||
      ProgrammeProgressionStatus.programmeComplete =>
        true,
      ProgrammeProgressionStatus.partialSuccess =>
        result.updatedAssignment != null,
      _ => false,
    };
  }
}
