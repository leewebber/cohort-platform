import '../models/programme_assignment_operation_result.dart';
import '../../../models/programme_assignment.dart';

/// Production entry point for athlete programme assignment lifecycle.
///
/// Home and Coach Studio must call this service — never [ProgrammeAssignmentStore]
/// directly for assignment mutations.
///
/// Development reset tooling lives in [ProgrammeAssignmentDevelopmentService].
/// See `43_Programme_Engine_Service_Contracts.md` §3.3.
abstract class ProgrammeAssignmentService {
  /// Returns the athlete's current active assignment, or null.
  Future<ProgrammeAssignment?> getCurrentAssignment({
    required String athleteId,
  });

  Future<ProgrammeAssignmentOperationResult> assignProgramme({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  });

  Future<ProgrammeAssignmentOperationResult> assignByLineageVersion({
    required String athleteId,
    required String lineageCode,
    required int versionNumber,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  });

  Future<ProgrammeAssignmentOperationResult> pauseAssignment({
    required String assignmentId,
    String? reason,
  });

  Future<ProgrammeAssignmentOperationResult> resumeAssignment({
    required String assignmentId,
  });

  Future<ProgrammeAssignmentOperationResult> completeAssignment({
    required String assignmentId,
  });

  Future<ProgrammeAssignmentOperationResult> cancelOrReplaceActiveAssignment({
    required String athleteId,
    required String newProgrammeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool allowUnpublishedVersion = false,
  });
}
