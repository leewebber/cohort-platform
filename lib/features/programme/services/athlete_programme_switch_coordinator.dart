import '../models/athlete_programme_switch_result.dart';
import 'programme_assignment_service.dart';

/// Orchestrates athlete-initiated programme switches without duplicating assignment rules.
class AthleteProgrammeSwitchCoordinator {
  const AthleteProgrammeSwitchCoordinator({
    required ProgrammeAssignmentService assignmentService,
  }) : _assignmentService = assignmentService;

  final ProgrammeAssignmentService _assignmentService;

  Future<AthleteProgrammeSwitchResult> switchToProgramme({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
  }) async {
    final trimmedAthleteId = athleteId.trim();
    final trimmedVersionId = programmeVersionId.trim();

    final current = await _assignmentService.getCurrentAssignment(
      athleteId: trimmedAthleteId,
    );

    if (current != null &&
        current.programmeVersionId.trim() == trimmedVersionId) {
      return AthleteProgrammeSwitchResult.alreadyActive();
    }

    final result = current == null
        ? await _assignmentService.assignProgramme(
            athleteId: trimmedAthleteId,
            programmeVersionId: trimmedVersionId,
            startedAt: startedAt,
            timezone: timezone,
          )
        : await _assignmentService.cancelOrReplaceActiveAssignment(
            athleteId: trimmedAthleteId,
            newProgrammeVersionId: trimmedVersionId,
            startedAt: startedAt,
            timezone: timezone,
          );

    return AthleteProgrammeSwitchResult.fromAssignmentOperation(result);
  }
}
