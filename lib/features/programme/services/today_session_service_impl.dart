import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/resolved_today_session.dart';
import 'programme_schedule_resolver.dart';
import 'today_session_service.dart';

/// Resolves today's programme session from assignment + template tree.
class TodaySessionServiceImpl implements TodaySessionService {
  const TodaySessionServiceImpl({
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeVersionStore versionStore,
    required ProgrammeSlotOutcomeStore slotOutcomeStore,
    required ProgrammeScheduleResolver scheduleResolver,
  })  : _assignmentStore = assignmentStore,
        _versionStore = versionStore,
        _slotOutcomeStore = slotOutcomeStore,
        _scheduleResolver = scheduleResolver;

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeScheduleResolver _scheduleResolver;

  @override
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId) async {
    // programme_assignments is the sole cursor source of truth.
    final assignment = await _assignmentStore.getActiveAssignment(athleteId);
    if (assignment == null) {
      return ResolvedTodaySession.noActiveProgramme();
    }

    return _resolveFromAssignment(assignment);
  }

  Future<ResolvedTodaySession> _resolveFromAssignment(
    ProgrammeAssignment assignment,
  ) async {
    final tree = await _versionStore.loadTemplateTree(
      assignment.programmeVersionId,
    );
    if (tree == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.emptyProgrammeStructure,
        'Pinned programme version ${assignment.programmeVersionId} could not be loaded',
      );
    }

    if (assignment.isPaused) {
      return ResolvedTodaySession.paused(
        assignment: assignment,
        programmeName: tree.template.version.name,
        versionNumber: tree.template.version.versionNumber,
      );
    }

    final outcomes = await _slotOutcomeStore.listForAssignment(assignment.id);
    final resolution = _scheduleResolver.resolve(
      assignment: assignment,
      tree: tree,
      outcomes: outcomes,
    );

    return ResolvedTodaySession.fromResolution(resolution);
  }
}
