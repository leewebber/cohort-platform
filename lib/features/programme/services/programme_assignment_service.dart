import '../../../models/programme_assignment.dart';

/// Athlete enrolment and assignment lifecycle.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.3.
abstract class ProgrammeAssignmentService {
  Future<ProgrammeAssignment> assignAthlete({
    required String athleteId,
    required String publishedVersionId,
    required DateTime startedAt,
    String? timezone,
  });

  Future<ProgrammeAssignment> pauseAssignment(String assignmentId);

  Future<ProgrammeAssignment> resumeAssignment(String assignmentId);

  Future<ProgrammeAssignment> completeAssignment(String assignmentId);

  Future<ProgrammeAssignment> reassignAthlete({
    required String athleteId,
    required String newPublishedVersionId,
    required DateTime startedAt,
    String? timezone,
  });
}
