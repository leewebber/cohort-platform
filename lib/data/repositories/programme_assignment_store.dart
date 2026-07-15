import '../../models/programme_assignment.dart';

/// Persistence boundary for athlete programme assignments.
///
/// See `43_Programme_Engine_Service_Contracts.md` §2.2.
abstract class ProgrammeAssignmentStore {
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId);

  Future<ProgrammeAssignment?> getById(String assignmentId);

  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment);

  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment);

  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId);
}
