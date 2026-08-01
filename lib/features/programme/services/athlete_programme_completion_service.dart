import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/persistence/athlete_local_repository.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../models/programme_vocabulary.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/mappers/performance_record_mapper.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/repositories/performance_record_store.dart';
import '../../plans/models/programmed_session_key.dart';
import '../models/athlete_programme_completion.dart';
import '../models/programme_execution_context.dart';
import 'athlete_programme_completion_store.dart';
import 'athlete_programme_completion_supabase_store.dart';

/// Explicit athlete submission → atomic completion + authored cursor advance.
///
/// Does not prepare the next session. Sprint 1.4B reconciles after commit.
class AthleteProgrammeCompletionService {
  AthleteProgrammeCompletionService({
    AthleteProgrammeCompletionStore? store,
    ProgrammeAssignmentStore? assignmentStore,
    PerformanceRecordStore? performanceStore,
    AthleteLocalRepository? localRepository,
    PerformanceRecordMapper mapper = const PerformanceRecordMapper(),
  }) : _store = store ?? const AthleteProgrammeCompletionSupabaseStore(),
       _assignmentStore =
           assignmentStore ?? const ProgrammeAssignmentSupabaseStore(),
       _performanceStore = performanceStore,
       _localRepository = localRepository,
       _mapper = mapper;

  final AthleteProgrammeCompletionStore _store;
  final ProgrammeAssignmentStore _assignmentStore;
  final PerformanceRecordStore? _performanceStore;
  final AthleteLocalRepository? _localRepository;
  final PerformanceRecordMapper _mapper;

  String buildIdempotencyKey({
    required String logicalCompletionKey,
    required String requestNonce,
  }) {
    return 'idem:$logicalCompletionKey:$requestNonce';
  }

  String buildLogicalCompletionKey(ProgrammeExecutionContext context) {
    final existing = context.programmedSessionKey?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    return ProgrammedSessionKey(
      planId: context.lineageCode ?? 'prog',
      planVersion: context.programmeVersionId,
      week: context.weekNumber,
      day: _dayNumber(context.dayKey),
      dayKey: context.dayKey,
      slotOrder: context.sessionOrder,
      protocolId: context.plannedProtocolId,
      programmeAssignmentId: context.assignmentId,
      packageContentHash: context.packageContentHash,
    ).value;
  }

  String fingerprintActuals(TrainingSessionRecord record) {
    final payload = <String, Object?>{
      'status': record.status.dbValue,
      'note': record.athleteNote,
      'rpe': record.overallRpe,
      'blocks': [
        for (final b in record.blockResults)
          {
            'id': b.blockResultId,
            'exercises': [
              for (final e in b.exerciseResults)
                {
                  'id': e.exerciseResultId,
                  'sets': [
                    for (final s in e.setResults)
                      {
                        'id': s.setResultId,
                        'reps': s.reps,
                        'load': s.load,
                        'load_unit': s.loadUnit,
                        'distance': s.distance,
                        'distance_unit': s.distanceUnit,
                        'duration_seconds': s.durationSeconds,
                        'completed': s.completed,
                        'rpe': s.rpe,
                        'note': s.note,
                      },
                  ],
                },
            ],
          },
      ],
    };
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Future<AthleteProgrammeCompletionResult> submit({
    required PerformanceCaptureController controller,
    required ProgrammeExecutionContext programmeContext,
    required int trainingSessionId,
    required String idempotencyKey,
    String? frozenLogicalKey,
    String? frozenActualsFingerprint,
  }) async {
    final validation = controller.validateForCompletion();
    if (!validation.isValid) {
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.completionValidationFailure,
        code: 'completion_validation_failure',
        message: validation.fieldErrors.values.first,
        idempotencyKey: idempotencyKey,
      );
    }

    final hash = programmeContext.packageContentHash?.trim();
    final key =
        (frozenLogicalKey ?? buildLogicalCompletionKey(programmeContext))
            .trim();
    if (hash == null || hash.isEmpty || key.isEmpty) {
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.preparedProvenanceMismatch,
        code: 'prepared_provenance_mismatch',
        idempotencyKey: idempotencyKey,
      );
    }

    final terminalStatus = controller.resolveCompletionStatus();
    // Persist athlete-entered actuals before authority transition. Keep the
    // durable row in_progress until the RPC commits terminal completion.
    if (_performanceStore != null) {
      await _performanceStore.saveDraft(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.inProgress,
        ),
      );
    }

    final draft = controller.buildPersistableDraft(status: terminalStatus);
    final record = _mapper.fromDraft(draft);
    final actualsFp = frozenActualsFingerprint ?? fingerprintActuals(record);

    final payload = <String, dynamic>{
      'assignment_id': programmeContext.assignmentId,
      'session_slot_id': programmeContext.sessionSlotId,
      'programme_version_id': programmeContext.programmeVersionId,
      'materialised_package_content_hash': hash,
      'programmed_session_key': key,
      'logical_completion_key': key,
      'idempotency_key': idempotencyKey,
      'actuals_fingerprint': actualsFp,
      'protocol_id': programmeContext.plannedProtocolId,
      'expected_week': programmeContext.weekNumber,
      'expected_day_key': programmeContext.dayKey,
      'expected_slot_order': programmeContext.sessionOrder,
      'training_session_id': trainingSessionId,
      'record_id': record.recordId,
      'status': terminalStatus.dbValue,
      'completion_record': record.toUpsertMap(),
    };

    Map<String, dynamic> response;
    try {
      response = await _store.completeAndAdvance(payload);
    } catch (error) {
      final reconciled = await reconcileAfterUncertainSubmit(
        programmeContext: programmeContext,
        logicalCompletionKey: key,
        idempotencyKey: idempotencyKey,
      );
      if (reconciled.isSuccess) return reconciled;
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.networkUncertain,
        code: 'network_uncertain',
        message: error.toString(),
        logicalCompletionKey: key,
        programmedSessionKey: key,
        idempotencyKey: idempotencyKey,
      );
    }

    var result = AthleteProgrammeCompletionResult.fromRpc(response);
    result = AthleteProgrammeCompletionResult(
      status: result.status,
      code: result.code,
      message: result.message,
      record: result.record ?? record,
      assignment: result.assignment,
      logicalCompletionKey: key,
      programmedSessionKey: key,
      idempotencyKey: idempotencyKey,
      terminalProgramme: result.terminalProgramme,
      nextWeek: result.nextWeek,
      nextDayKey: result.nextDayKey,
      nextSlotOrder: result.nextSlotOrder,
      nextProtocolId: result.nextProtocolId,
    );

    if (!result.isSuccess) return result;

    final assignment =
        result.assignment ??
        await _assignmentStore.getById(programmeContext.assignmentId);

    // Local prepared cleanup is best-effort and must not affect server commit.
    try {
      await _localRepository?.clearGeneratedSession(record.athleteId);
    } catch (_) {}

    return AthleteProgrammeCompletionResult(
      status: result.status,
      code: result.code,
      message: result.message,
      record: result.record ?? record,
      assignment: assignment,
      logicalCompletionKey: key,
      programmedSessionKey: key,
      idempotencyKey: idempotencyKey,
      terminalProgramme:
          result.terminalProgramme || assignment?.status.dbValue == 'completed',
      nextWeek: result.nextWeek ?? assignment?.currentWeek,
      nextDayKey: result.nextDayKey ?? assignment?.currentDayKey,
      nextSlotOrder: result.nextSlotOrder ?? assignment?.currentSessionOrder,
      nextProtocolId: result.nextProtocolId,
    );
  }

  /// Re-submit the same frozen payload after uncertain transport.
  Future<AthleteProgrammeCompletionResult> retrySamePayload(
    Map<String, dynamic> frozenPayload,
  ) async {
    try {
      final response = await _store.completeAndAdvance(frozenPayload);
      return AthleteProgrammeCompletionResult.fromRpc(response);
    } catch (error) {
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.networkUncertain,
        code: 'network_uncertain',
        message: error.toString(),
        logicalCompletionKey: frozenPayload['logical_completion_key']
            ?.toString(),
        programmedSessionKey: frozenPayload['programmed_session_key']
            ?.toString(),
        idempotencyKey: frozenPayload['idempotency_key']?.toString(),
      );
    }
  }

  Future<AthleteProgrammeCompletionResult> reconcileAfterUncertainSubmit({
    required ProgrammeExecutionContext programmeContext,
    required String logicalCompletionKey,
    required String idempotencyKey,
  }) async {
    final assignment = await _assignmentStore.getById(
      programmeContext.assignmentId,
    );
    if (assignment == null) {
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.assignmentMissing,
        code: 'assignment_missing',
        idempotencyKey: idempotencyKey,
      );
    }

    final cursorMoved =
        assignment.currentWeek != programmeContext.weekNumber ||
        assignment.currentDayKey != programmeContext.dayKey ||
        assignment.currentSessionOrder != programmeContext.sessionOrder ||
        assignment.status.dbValue == 'completed';

    if (cursorMoved) {
      return AthleteProgrammeCompletionResult(
        status: AthleteProgrammeCompletionStatus.alreadyCommitted,
        code: 'reconciled_after_uncertain',
        assignment: assignment,
        logicalCompletionKey: logicalCompletionKey,
        programmedSessionKey: logicalCompletionKey,
        idempotencyKey: idempotencyKey,
        nextWeek: assignment.currentWeek,
        nextDayKey: assignment.currentDayKey,
        nextSlotOrder: assignment.currentSessionOrder,
        terminalProgramme: assignment.status.dbValue == 'completed',
      );
    }

    return AthleteProgrammeCompletionResult(
      status: AthleteProgrammeCompletionStatus.recovering,
      code: 'still_recovering',
      assignment: assignment,
      logicalCompletionKey: logicalCompletionKey,
      programmedSessionKey: logicalCompletionKey,
      idempotencyKey: idempotencyKey,
    );
  }

  static int _dayNumber(String dayKey) {
    final match = RegExp(r'^day_([1-9][0-9]*)$').firstMatch(dayKey.trim());
    if (match == null) return 1;
    return int.parse(match.group(1)!);
  }
}
