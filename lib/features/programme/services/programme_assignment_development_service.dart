import '../models/programme_assignment_operation_result.dart';

/// Temporary development-only assignment tooling.
///
/// Never used by Home, Coach Studio, onboarding, or athlete flows.
/// See `43_Programme_Engine_Service_Contracts.md` §3.3.1.
abstract class ProgrammeAssignmentDevelopmentService {
  Future<ProgrammeAssignmentOperationResult> resetAssignment({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
    required int slotOrder,
    bool clearOutcomes = false,
  });
}
