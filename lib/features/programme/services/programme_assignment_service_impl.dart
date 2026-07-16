import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_version.dart';
import '../../../models/programme_vocabulary.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/programme_assignment_operation_result.dart';
import '../models/resolved_today_session.dart';
import 'athlete_state_sync_service.dart';
import 'programme_assignment_service.dart';
import 'programme_schedule_resolver.dart';
import 'today_session_service.dart';

/// Production implementation of [ProgrammeAssignmentService].
class ProgrammeAssignmentServiceImpl implements ProgrammeAssignmentService {
  ProgrammeAssignmentServiceImpl({
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeVersionStore versionStore,
    required ProgrammeScheduleResolver scheduleResolver,
    required TodaySessionService todaySessionService,
    required AthleteStateSyncService athleteStateSyncService,
  })  : _assignmentStore = assignmentStore,
        _versionStore = versionStore,
        _scheduleResolver = scheduleResolver,
        _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService;

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeScheduleResolver _scheduleResolver;
  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;

  @override
  Future<ProgrammeAssignment?> getCurrentAssignment({
    required String athleteId,
  }) {
    return _assignmentStore.getActiveAssignment(athleteId.trim());
  }

  @override
  Future<ProgrammeAssignmentOperationResult> assignProgramme({
    required String athleteId,
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  }) async {
    final trimmedAthleteId = athleteId.trim();
    final trimmedVersionId = programmeVersionId.trim();

    _log(
      'operation=assignProgramme athlete=$trimmedAthleteId '
      'version=$trimmedVersionId',
    );

    try {
      final existingActive =
          await _assignmentStore.getActiveAssignment(trimmedAthleteId);
      _log('existingActive=${existingActive?.id ?? 'none'}');

      if (existingActive != null && !replaceExistingActive) {
        final result = ProgrammeAssignmentOperationResult.conflict(
          existing: existingActive,
        );
        _logResult(result);
        return result;
      }

      if (existingActive != null && replaceExistingActive) {
        return await cancelOrReplaceActiveAssignment(
          athleteId: trimmedAthleteId,
          newProgrammeVersionId: trimmedVersionId,
          startedAt: startedAt,
          timezone: timezone,
          allowUnpublishedVersion: allowUnpublishedVersion,
        );
      }

      final version = await _versionStore.getVersionById(trimmedVersionId);
      final validation = _validateVersion(
        version: version,
        allowUnpublishedVersion: allowUnpublishedVersion,
      );
      if (validation != null) {
        _logResult(validation);
        return validation;
      }

      return await _createAssignment(
        athleteId: trimmedAthleteId,
        version: version!,
        startedAt: startedAt,
        timezone: timezone.trim(),
      );
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    } on ProgrammeScheduleException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  @override
  Future<ProgrammeAssignmentOperationResult> assignByLineageVersion({
    required String athleteId,
    required String lineageCode,
    required int versionNumber,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
    bool allowUnpublishedVersion = false,
  }) async {
    final trimmedAthleteId = athleteId.trim();
    final trimmedLineageCode = lineageCode.trim();

    _log(
      'operation=assignByLineageVersion athlete=$trimmedAthleteId '
      'lineage=$trimmedLineageCode versionNumber=$versionNumber',
    );

    try {
      final version = await _versionStore.getVersionByLineageAndNumber(
        lineageCode: trimmedLineageCode,
        versionNumber: versionNumber,
      );

      if (version == null) {
        final result = ProgrammeAssignmentOperationResult.invalidVersion(
          message: 'Programme version not found for '
              '$trimmedLineageCode v$versionNumber',
        );
        _logResult(result);
        return result;
      }

      return await assignProgramme(
        athleteId: trimmedAthleteId,
        programmeVersionId: version.id,
        startedAt: startedAt,
        timezone: timezone,
        replaceExistingActive: replaceExistingActive,
        allowUnpublishedVersion: allowUnpublishedVersion,
      );
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  @override
  Future<ProgrammeAssignmentOperationResult> pauseAssignment({
    required String assignmentId,
    String? reason,
  }) async {
    _log('operation=pauseAssignment assignment=$assignmentId');

    try {
      final assignment = await _assignmentStore.getById(assignmentId.trim());
      if (assignment == null) {
        final result = ProgrammeAssignmentOperationResult.noAssignment(
          message: 'Assignment $assignmentId not found',
        );
        _logResult(result);
        return result;
      }

      if (assignment.isPaused) {
        final resolution = await _resolvePaused(assignment);
        final synced = await _syncProjectionQuietly(
          athleteId: assignment.athleteId,
          resolution: resolution,
        );

        final result = ProgrammeAssignmentOperationResult(
          status: ProgrammeAssignmentOperationStatus.paused,
          assignment: assignment,
          resolvedTodaySession: resolution,
          athleteStateSynced: synced,
          warnings: reason == null ? const [] : [reason],
        );
        _logResult(result);
        return result;
      }

      final pausedAt = DateTime.now().toUtc();
      final updated = await _assignmentStore.update(
        assignment.copyWith(
          status: ProgrammeAssignmentStatus.paused,
          pausedAt: pausedAt,
        ),
      );

      final resolution = await _resolvePaused(updated);
      final synced = await _syncProjectionQuietly(
        athleteId: updated.athleteId,
        resolution: resolution,
      );

      final warnings = <String>[];
      if (reason != null && reason.trim().isNotEmpty) {
        warnings.add(reason.trim());
      }
      if (!synced) {
        warnings.add('athlete_state projection sync failed after pause');
      }

      final result = ProgrammeAssignmentOperationResult(
        status: synced
            ? ProgrammeAssignmentOperationStatus.paused
            : ProgrammeAssignmentOperationStatus.partialSuccess,
        assignment: updated,
        resolvedTodaySession: resolution,
        athleteStateSynced: synced,
        warnings: warnings,
      );
      _logResult(result);
      return result;
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  @override
  Future<ProgrammeAssignmentOperationResult> resumeAssignment({
    required String assignmentId,
  }) async {
    _log('operation=resumeAssignment assignment=$assignmentId');

    try {
      final assignment = await _assignmentStore.getById(assignmentId.trim());
      if (assignment == null) {
        final result = ProgrammeAssignmentOperationResult.noAssignment(
          message: 'Assignment $assignmentId not found',
        );
        _logResult(result);
        return result;
      }

      final updated = await _assignmentStore.update(
        assignment.copyWith(
          status: ProgrammeAssignmentStatus.active,
          clearPausedAt: true,
        ),
      );

      return await _resolveAndSync(
        athleteId: updated.athleteId,
        assignment: updated,
        successStatus: ProgrammeAssignmentOperationStatus.resumed,
      );
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  @override
  Future<ProgrammeAssignmentOperationResult> completeAssignment({
    required String assignmentId,
  }) async {
    _log('operation=completeAssignment assignment=$assignmentId');

    try {
      final assignment = await _assignmentStore.getById(assignmentId.trim());
      if (assignment == null) {
        final result = ProgrammeAssignmentOperationResult.noAssignment(
          message: 'Assignment $assignmentId not found',
        );
        _logResult(result);
        return result;
      }

      final completedAt = DateTime.now().toUtc();
      final updated = await _assignmentStore.update(
        assignment.copyWith(
          status: ProgrammeAssignmentStatus.completed,
          completedAt: completedAt,
        ),
      );

      var synced = false;
      try {
        await _athleteStateSyncService.clearProgrammeProjection(
          updated.athleteId,
        );
        synced = true;
      } catch (error) {
        debugPrint('[ProgrammeAssignment] projectionSynced=false error=$error');
      }

      final result = ProgrammeAssignmentOperationResult(
        status: synced
            ? ProgrammeAssignmentOperationStatus.completed
            : ProgrammeAssignmentOperationStatus.partialSuccess,
        assignment: updated,
        athleteStateSynced: synced,
        warnings: synced
            ? const []
            : const ['athlete_state projection clear failed after complete'],
      );
      _logResult(result);
      return result;
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  @override
  Future<ProgrammeAssignmentOperationResult> cancelOrReplaceActiveAssignment({
    required String athleteId,
    required String newProgrammeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool allowUnpublishedVersion = false,
  }) async {
    final trimmedAthleteId = athleteId.trim();
    final trimmedVersionId = newProgrammeVersionId.trim();

    _log(
      'operation=cancelOrReplaceActiveAssignment athlete=$trimmedAthleteId '
      'version=$trimmedVersionId',
    );

    try {
      final existingActive =
          await _assignmentStore.getActiveAssignment(trimmedAthleteId);
      _log('existingActive=${existingActive?.id ?? 'none'}');

      if (existingActive == null) {
        return await assignProgramme(
          athleteId: trimmedAthleteId,
          programmeVersionId: trimmedVersionId,
          startedAt: startedAt,
          timezone: timezone,
          allowUnpublishedVersion: allowUnpublishedVersion,
        );
      }

      final version = await _versionStore.getVersionById(trimmedVersionId);
      final validation = _validateVersion(
        version: version,
        allowUnpublishedVersion: allowUnpublishedVersion,
      );
      if (validation != null) {
        _logResult(validation);
        return validation;
      }

      await _assignmentStore.update(
        existingActive.copyWith(
          status: ProgrammeAssignmentStatus.reassigned,
        ),
      );

      final createResult = await _createAssignment(
        athleteId: trimmedAthleteId,
        version: version!,
        startedAt: startedAt,
        timezone: timezone.trim(),
      );

      if (createResult.status == ProgrammeAssignmentOperationStatus.failed ||
          createResult.status ==
              ProgrammeAssignmentOperationStatus.invalidProgrammeVersion) {
        await _assignmentStore.update(
          existingActive.copyWith(
            status: ProgrammeAssignmentStatus.active,
            clearSupersededByAssignmentId: true,
          ),
        );
        _logResult(createResult);
        return createResult;
      }

      final newAssignment = createResult.assignment;
      if (newAssignment == null) {
        await _assignmentStore.update(
          existingActive.copyWith(
            status: ProgrammeAssignmentStatus.active,
            clearSupersededByAssignmentId: true,
          ),
        );
        final result = ProgrammeAssignmentOperationResult.failed(
          message: 'Replacement assignment was not created',
        );
        _logResult(result);
        return result;
      }

      await _assignmentStore.update(
        existingActive.copyWith(
          status: ProgrammeAssignmentStatus.reassigned,
          supersededByAssignmentId: newAssignment.id,
        ),
      );

      final result = ProgrammeAssignmentOperationResult(
        status: createResult.status == ProgrammeAssignmentOperationStatus.partialSuccess
            ? ProgrammeAssignmentOperationStatus.partialSuccess
            : ProgrammeAssignmentOperationStatus.replaced,
        assignment: newAssignment,
        resolvedTodaySession: createResult.resolvedTodaySession,
        athleteStateSynced: createResult.athleteStateSynced,
        warnings: createResult.warnings,
        replacedAssignmentId: existingActive.id,
      );
      _logResult(result);
      return result;
    } on ProgrammeStoreException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    } on ProgrammeScheduleException catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.message,
      );
      _logResult(result);
      return result;
    }
  }

  Future<ProgrammeAssignmentOperationResult> _createAssignment({
    required String athleteId,
    required ProgrammeVersion version,
    required DateTime startedAt,
    required String timezone,
  }) async {
    final lineage = await _versionStore.getLineageById(version.lineageId);
    if (lineage == null) {
      final result = ProgrammeAssignmentOperationResult.invalidVersion(
        message: 'Lineage ${version.lineageId} not found for version ${version.id}',
      );
      _logResult(result);
      return result;
    }

    final tree = await _versionStore.loadTemplateTree(version.id);
    if (tree == null) {
      final result = ProgrammeAssignmentOperationResult.invalidVersion(
        message: 'Programme template tree could not be loaded for ${version.id}',
      );
      _logResult(result);
      return result;
    }

    final initialCursor = _scheduleResolver.resolveInitialCursor(tree: tree);
    _log(
      'cursor=week ${initialCursor.weekNumber} ${initialCursor.dayKey} '
      'slot ${initialCursor.slotOrder}',
    );

    final assignment = ProgrammeAssignment.forCreate(
      athleteId: athleteId,
      programmeVersionId: version.id,
      lineageCode: lineage.code,
      startedAt: startedAt,
      timezone: timezone,
      currentWeek: initialCursor.weekNumber,
      currentDayKey: initialCursor.dayKey,
      currentSessionOrder: initialCursor.slotOrder,
    );

    final inserted = await _assignmentStore.insert(assignment);
    _log('inserted assignmentId=${inserted.id}');

    return await _resolveAndSync(
      athleteId: athleteId,
      assignment: inserted,
      successStatus: ProgrammeAssignmentOperationStatus.assigned,
    );
  }

  Future<ProgrammeAssignmentOperationResult> _resolveAndSync({
    required String athleteId,
    required ProgrammeAssignment assignment,
    required ProgrammeAssignmentOperationStatus successStatus,
  }) async {
    final resolution = await _todaySessionService.resolveForAthlete(athleteId);
    final synced = await _syncProjectionQuietly(
      athleteId: athleteId,
      resolution: resolution,
    );

    final warnings = <String>[];
    if (!synced) {
      warnings.add('athlete_state projection sync failed');
    }

    final result = ProgrammeAssignmentOperationResult(
      status: synced ? successStatus : ProgrammeAssignmentOperationStatus.partialSuccess,
      assignment: assignment,
      resolvedTodaySession: resolution,
      athleteStateSynced: synced,
      warnings: warnings,
    );
    _logResult(result);
    return result;
  }

  Future<ResolvedTodaySession> _resolvePaused(
    ProgrammeAssignment assignment,
  ) async {
    final tree = await _versionStore.loadTemplateTree(
      assignment.programmeVersionId,
    );

    return ResolvedTodaySession.paused(
      assignment: assignment,
      programmeName: tree?.template.version.name ?? assignment.lineageCode,
      versionNumber: tree?.template.version.versionNumber ?? 1,
    );
  }

  ProgrammeAssignmentOperationResult? _validateVersion({
    required ProgrammeVersion? version,
    required bool allowUnpublishedVersion,
  }) {
    if (version == null) {
      return ProgrammeAssignmentOperationResult.invalidVersion(
        message: 'Programme version not found',
      );
    }

    if (version.lifecycleStatus == ProgrammeLifecycleStatus.archived) {
      return ProgrammeAssignmentOperationResult.invalidVersion(
        message: 'Programme version ${version.id} is archived',
      );
    }

    if (!allowUnpublishedVersion &&
        version.lifecycleStatus != ProgrammeLifecycleStatus.published) {
      return ProgrammeAssignmentOperationResult.invalidVersion(
        message: 'Programme version ${version.id} is not published',
      );
    }

    return null;
  }

  Future<bool> _syncProjectionQuietly({
    required String athleteId,
    required ResolvedTodaySession resolution,
  }) async {
    try {
      await _athleteStateSyncService.syncFromResolvedSession(
        athleteId: athleteId,
        resolution: resolution,
      );
      _log('projectionSynced=true');
      return true;
    } catch (error) {
      debugPrint('[ProgrammeAssignment] projectionSynced=false error=$error');
      return false;
    }
  }

  void _log(String message) {
    debugPrint('[ProgrammeAssignment] $message');
  }

  void _logResult(ProgrammeAssignmentOperationResult result) {
    _log('result=${result.status}');
    _log('projectionSynced=${result.athleteStateSynced}');
  }
}
