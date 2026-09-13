import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/mappers/performance_record_mapper.dart';
import '../../performance/models/session_result_entry_mode.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../../core/services/supabase_service.dart';
import '../models/backfill_programme_session.dart';
import 'athlete_programme_completion_service.dart';
import 'athlete_runtime_capabilities.dart';
import 'backfill_programme_session_store.dart';

class SupabaseBackfillProgrammeSessionStore
    implements BackfillProgrammeSessionStore {
  SupabaseBackfillProgrammeSessionStore({
    AthleteRuntimeCapabilities? capabilities,
    AthleteRuntimeCapabilities Function()? capabilitiesReader,
  }) : _capabilitiesReader = capabilitiesReader ??
            (() => capabilities ?? AthleteRuntimeCapabilities.unavailable);

  static const rpcName = 'complete_backfilled_fixed_programme_occurrence';

  final AthleteRuntimeCapabilities Function() _capabilitiesReader;

  @override
  bool get isSupported => _capabilitiesReader().backfillResults;

  @override
  Future<BackfillProgrammeSessionResult> save(
    BackfillProgrammeSessionCommand command,
  ) async {
    if (!isSupported) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.failed,
        code: 'backfill_schema_unavailable',
        message:
            'Historical result entry is not available on this environment yet.',
      );
    }

    final controller = PerformanceCaptureController(draft: command.draft);
    final validation = controller.validateForCompletion();
    if (!validation.isValid) {
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.rejected,
        code: 'completion_validation_failure',
        message: validation.fieldErrors.values.first,
      );
    }

    final terminalStatus = controller.resolveCompletionStatus();
    final mapped = const PerformanceRecordMapper().fromDraft(
      command.draft.copyWith(status: terminalStatus),
    );
    final fingerprint = AthleteProgrammeCompletionService().fingerprintActuals(
      mapped,
    );
    final payload = <String, dynamic>{
      'occurrence_id': command.occurrenceId,
      'assignment_id': command.assignmentId,
      'performed_on': command.performedOn,
      'idempotency_key': command.idempotencyKey,
      'actuals_fingerprint': fingerprint,
      'status': terminalStatus.dbValue,
      'record_id': mapped.recordId,
      'completion_record': mapped.toCompletionTreeMap(),
    };

    try {
      final response = await SupabaseService.client.rpc(
        rpcName,
        params: {'payload': payload},
      );
      if (response is! Map) {
        return const BackfillProgrammeSessionResult(
          status: BackfillProgrammeSessionStatus.failed,
          code: 'malformed_response',
          message: 'Results could not be saved. Try again.',
        );
      }
      return _fromRpc(Map<String, dynamic>.from(response), mapped);
    } catch (_) {
      return const BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.failed,
        code: 'network_uncertain',
        message: 'Results could not be saved. Try again.',
      );
    }
  }

  BackfillProgrammeSessionResult _fromRpc(
    Map<String, dynamic> response,
    TrainingSessionRecord submitted,
  ) {
    final status = response['status']?.toString();
    final code = response['code']?.toString();
    if (status == 'committed' || status == 'already_committed') {
      final raw = response['completion_record'];
      final record = raw is Map
          ? TrainingSessionRecord.fromMap(
              Map<String, dynamic>.from(raw),
              blockResults: submitted.blockResults,
            )
          : TrainingSessionRecord(
              recordId: submitted.recordId,
              athleteId: submitted.athleteId,
              trainingSessionId: _asInt(response['training_session_id']),
              sourceProtocolId: submitted.sourceProtocolId,
              programmeId: submitted.programmeId,
              assignmentId: submitted.assignmentId,
              programmeSessionId: submitted.programmeSessionId,
              status: submitted.status == TrainingSessionRecordStatus.inProgress
                  ? TrainingSessionRecordStatus.completed
                  : submitted.status,
              sessionSnapshot: submitted.sessionSnapshot,
              startedAt: submitted.startedAt,
              completedAt: submitted.completedAt,
              durationSeconds: submitted.durationSeconds,
              overallRpe: submitted.overallRpe,
              athleteNote: submitted.athleteNote,
              blockResults: submitted.blockResults,
              entryMode: SessionResultEntryMode.backfill,
              performedOn: submitted.performedOn,
              performedPrecision: SessionPerformedPrecision.date,
              recordedAt: submitted.recordedAt ?? submitted.createdAt,
            );
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.saved,
        code: code,
        record: record,
      );
    }
    if (status == 'conflict') {
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.conflict,
        code: code,
        message: _messageFor(code),
      );
    }
    if (status == 'validation_failure' || status == 'authorization_failure') {
      return BackfillProgrammeSessionResult(
        status: BackfillProgrammeSessionStatus.rejected,
        code: code,
        message: _messageFor(code),
      );
    }
    return BackfillProgrammeSessionResult(
      status: BackfillProgrammeSessionStatus.failed,
      code: code,
      message: _messageFor(code),
    );
  }

  static String _messageFor(String? code) {
    return switch (code) {
      'already_completed' => 'Results for this session have already been saved.',
      'occurrence_in_progress' =>
        'This session is already in progress. Finish or keep training it live.',
      'occurrence_skipped' => 'This session was skipped and cannot be backfilled.',
      'future_date' => 'The performance date cannot be in the future.',
      'before_scheduled' =>
        'The performance date cannot be before the scheduled date.',
      'future_occurrence' => 'Only past incomplete sessions can be backfilled.',
      _ => 'Results could not be saved. Try again.',
    };
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
