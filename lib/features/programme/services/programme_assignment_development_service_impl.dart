import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_vocabulary.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/programme_assignment_operation_result.dart';
import '../models/programme_template.dart';
import 'athlete_state_sync_service.dart';
import 'programme_assignment_development_service.dart';
import 'programme_schedule_resolver.dart';
import 'today_session_service.dart';

/// Development-only assignment reset tooling.
///
/// Never used by Home, Coach Studio, onboarding, or athlete flows.
class ProgrammeAssignmentDevelopmentServiceImpl
    implements ProgrammeAssignmentDevelopmentService {
  ProgrammeAssignmentDevelopmentServiceImpl({
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeSlotOutcomeStore slotOutcomeStore,
    required ProgrammeVersionStore versionStore,
    required ProgrammeScheduleResolver scheduleResolver,
    required TodaySessionService todaySessionService,
    required AthleteStateSyncService athleteStateSyncService,
  })  : _assignmentStore = assignmentStore,
        _slotOutcomeStore = slotOutcomeStore,
        _versionStore = versionStore,
        _scheduleResolver = scheduleResolver,
        _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService;

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeScheduleResolver _scheduleResolver;
  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;

  @override
  Future<ProgrammeAssignmentOperationResult> resetAssignment({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
    required int slotOrder,
    bool clearOutcomes = false,
  }) async {
    debugPrint(
      '[ProgrammeAssignmentDev] operation=resetAssignment '
      'assignment=$assignmentId week=$weekNumber day=$dayKey slot=$slotOrder '
      'clearOutcomes=$clearOutcomes',
    );

    try {
      final assignment = await _assignmentStore.getById(assignmentId.trim());
      if (assignment == null) {
        return ProgrammeAssignmentOperationResult.noAssignment(
          message: 'Assignment $assignmentId not found',
        );
      }

      final tree = await _versionStore.loadTemplateTree(
        assignment.programmeVersionId,
      );
      if (tree == null) {
        return ProgrammeAssignmentOperationResult.failed(
          message: 'Pinned programme version could not be loaded',
        );
      }

      final cursorValidation = _validateCursorAgainstTree(
        assignment: assignment,
        tree: tree,
        weekNumber: weekNumber,
        dayKey: dayKey,
        slotOrder: slotOrder,
      );
      if (cursorValidation != null) {
        return cursorValidation;
      }

      if (clearOutcomes) {
        final outcomesBefore =
            await _slotOutcomeStore.listForAssignment(assignment.id);
        debugPrint(
          '[ProgrammeAssignmentDev] outcomes before delete: '
          '${outcomesBefore.length}',
        );

        final deleteResult =
            await _slotOutcomeStore.deleteOutcomesForAssignment(
          assignmentId: assignment.id,
        );
        debugPrint(
          '[ProgrammeAssignmentDev] outcomes deleted: '
          '${deleteResult.deletedCount}',
        );

        final outcomesAfter =
            await _slotOutcomeStore.listForAssignment(assignment.id);
        debugPrint(
          '[ProgrammeAssignmentDev] outcomes after delete: '
          '${outcomesAfter.length}',
        );

        if (outcomesBefore.isNotEmpty && deleteResult.deletedCount == 0) {
          return ProgrammeAssignmentOperationResult.failed(
            message: 'Reset aborted: ${outcomesBefore.length} slot outcome(s) '
                'were visible before delete but DELETE removed 0 rows',
          );
        }

        if (outcomesAfter.isNotEmpty) {
          return ProgrammeAssignmentOperationResult.failed(
            message: 'Reset aborted: ${outcomesAfter.length} slot outcome(s) '
                'remain after delete for assignment ${assignment.id}',
          );
        }
      }

      final updated = await _assignmentStore.update(
        assignment.copyWith(
          currentWeek: weekNumber,
          currentDayKey: dayKey,
          currentSessionOrder: slotOrder,
          status: ProgrammeAssignmentStatus.active,
          clearCompletedAt: true,
          clearLastProgressedTrainingSessionId: true,
        ),
      );

      final resolution =
          await _todaySessionService.resolveForAthlete(updated.athleteId);

      var synced = false;
      try {
        await _athleteStateSyncService.syncFromResolvedSession(
          athleteId: updated.athleteId,
          resolution: resolution,
        );
        synced = true;
      } catch (error) {
        debugPrint(
          '[ProgrammeAssignmentDev] projectionSynced=false error=$error',
        );
      }

      return ProgrammeAssignmentOperationResult(
        status: synced
            ? ProgrammeAssignmentOperationStatus.assigned
            : ProgrammeAssignmentOperationStatus.partialSuccess,
        assignment: updated,
        resolvedTodaySession: resolution,
        athleteStateSynced: synced,
        warnings: synced
            ? const []
            : const ['athlete_state projection sync failed after reset'],
      );
    } on ProgrammeStoreException catch (error) {
      return ProgrammeAssignmentOperationResult.failed(message: error.message);
    } on ProgrammeScheduleException catch (error) {
      return ProgrammeAssignmentOperationResult.failed(message: error.message);
    }
  }

  ProgrammeAssignmentOperationResult? _validateCursorAgainstTree({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required int weekNumber,
    required String dayKey,
    required int slotOrder,
  }) {
    try {
      _scheduleResolver.resolve(
        assignment: assignment.copyWith(
          currentWeek: weekNumber,
          currentDayKey: dayKey,
          currentSessionOrder: slotOrder,
        ),
        tree: tree,
        outcomes: const [],
      );
      return null;
    } on ProgrammeScheduleException catch (error) {
      return ProgrammeAssignmentOperationResult.failed(
        message: 'Invalid reset cursor: ${error.message}',
      );
    }
  }
}
