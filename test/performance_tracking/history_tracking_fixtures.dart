import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';

/// Synthetic source rows and definitions only; no real profile or test content.
abstract final class SyntheticHistory {
  static final hashA = List.filled(64, 'a').join();
  static final hashB = List.filled(64, 'b').join();
  static TrackingMethodDefinition method(TrackingUnit unit) =>
      TrackingMethodDefinition(
        id: 'synthetic.extract',
        version: 1,
        kind: TrackingMethodKind.fieldExtraction,
        inputUnits: [unit],
        outputUnit: unit,
      );
  static TrackingMetricDefinition metric({
    String field = 'durationSeconds',
    TrackingUnit unit = TrackingUnit.seconds,
    bool allowPartial = false,
    bool assessment = false,
    int? freshness,
    List<String> requiredContext = const [],
    List<TrackingSourceKind> sources = const [TrackingSourceKind.historyResult],
  }) => TrackingMetricDefinition(
    id: 'synthetic.metric',
    version: 1,
    label: 'Synthetic actual only',
    unit: unit,
    method: method(unit).reference,
    allowedSources: sources,
    captureField: field,
    allowPartial: allowPartial,
    requiresAssessment: assessment,
    freshnessCivilDays: freshness,
    requiredContext: requiredContext,
  );

  static Map<String, Object?> record() => {
    'record_id': 'synthetic.record',
    'athlete_id': 'synthetic.athlete',
    'status': 'completed',
    'started_at': '2026-01-01T12:00:00Z',
    'performed_precision': 'timestamp',
    'training_session_id': 17,
    'source_protocol_id': 'synthetic.protocol',
    'assignment_id': 'synthetic.assignment',
  };
  static Map<String, Object?> block() => {
    'block_result_id': 'synthetic.block-result',
    'session_record_id': 'synthetic.record',
    'source_block_id': 'synthetic.block',
    'status': 'completed',
    'result_type': 'duration',
    'block_snapshot': {
      'sourceBlockId': 'synthetic.block',
      'comparisonFamily': 'synthetic.condition',
    },
    'result_data': {'resultType': 'duration', 'durationSeconds': 12},
  };
  static Map<String, Object?> exercise() => {
    'exercise_result_id': 'synthetic.exercise-result',
    'block_result_id': 'synthetic.block-result',
  };
  static Map<String, Object?> set() => {
    'set_result_id': 'synthetic.set-result',
    'exercise_result_id': 'synthetic.exercise-result',
    'completed': true,
    'reps': 3,
    'load': 12.5,
    'load_unit': 'kg',
    'duration_seconds': 12,
    'distance': 12,
    'distance_unit': 'm',
  };
  static Map<String, Object?> audit({String id = 'synthetic.audit'}) => {
    'correction_id': id,
    'record_id': 'synthetic.record',
    'athlete_id': 'synthetic.athlete',
    'training_session_id': 17,
    'corrected_at': '2026-01-02T12:00:00Z',
    'before_values': {
      'block:synthetic.block-result:result_data': {
        'resultType': 'duration',
        'durationSeconds': 9,
      },
    },
    'after_values': {
      'block:synthetic.block-result:result_data': {
        'resultType': 'duration',
        'durationSeconds': 12,
      },
    },
  };
  static HistoryFieldSelection field({
    String name = 'durationSeconds',
    bool fromSet = false,
    bool running = false,
    String? digest,
    String? correction,
  }) => HistoryFieldSelection(
    recordId: 'synthetic.record',
    blockResultId: 'synthetic.block-result',
    sourceBlockId: 'synthetic.block',
    fieldPath: fromSet
        ? [name]
        : ['result_data', if (running) 'intervals', name],
    exerciseResultId: fromSet ? 'synthetic.exercise-result' : null,
    setResultId: fromSet ? 'synthetic.set-result' : null,
    workoutId: running ? 'synthetic.workout' : null,
    stepId: running ? 'synthetic.step' : null,
    repeatOrdinal: running ? 2 : null,
    expectedInputDigest: digest,
    expectedCorrectionId: correction,
  );
  static TrackingProgrammeScope scope({
    String slot = 'synthetic.slot',
    String? mapping,
  }) => TrackingProgrammeScope(
    programmeVersionId: 'synthetic.version',
    packageHash: hashA,
    slotKey: slot,
    protocolId: 'synthetic.protocol',
    protocolRevision: 1,
    blockId: 'synthetic.block',
    workoutId: mapping == null ? null : 'synthetic.workout',
    stepId: mapping == null ? null : 'synthetic.step',
    repeatOrdinal: mapping == null ? null : 2,
    mappingHash: mapping,
  );
  static HistoryProgrammeClaim claim({TrackingProgrammeScope? value}) =>
      HistoryProgrammeClaim(
        assignmentId: 'synthetic.assignment',
        occurrenceId: 'synthetic.occurrence',
        trainingSessionId: '17',
        scope: value ?? scope(),
      );
  static HistoryProgrammeWitness witness({TrackingProgrammeScope? value}) =>
      HistoryProgrammeWitness(
        athleteId: 'synthetic.athlete',
        recordId: 'synthetic.record',
        assignmentId: 'synthetic.assignment',
        occurrenceId: 'synthetic.occurrence',
        trainingSessionId: '17',
        scope: value ?? scope(),
      );
  static Map<String, Object?> runningBlock() => {
    ...block(),
    'result_type': 'interval',
    'block_snapshot': {
      'sourceBlockId': 'synthetic.block',
      'structuredRunningV1': {
        'schema_version': 1,
        'workout_id': 'synthetic.workout',
        'session_block_id': 'synthetic.block',
        'execution_mapping_sha256': hashB,
        'package_content_hash': hashA,
        'work_repetitions': [
          {
            'workout_id': 'synthetic.workout',
            'session_block_id': 'synthetic.block',
            'authored_step_id': 'synthetic.step',
            'repeat_ordinal': 2,
            'work_seconds': 9,
          },
        ],
      },
    },
    'result_data': {
      'resultType': 'interval',
      'intervals': [
        {
          'ordinal': 42,
          'workoutId': 'synthetic.workout',
          'sessionBlockId': 'synthetic.block',
          'authoredStepId': 'synthetic.step',
          'repeatOrdinal': 2,
          'state': 'completed',
          'workSeconds': 9,
          'paceSecondsPerKm': 12.5,
          'paceUnit': 'sec_per_km',
        },
      ],
    },
  };

  static HistoryReadFrame frame({
    Map<String, Object?>? recordRow,
    Map<String, Object?>? blockRow,
    List<Map<String, Object?>>? blocks,
    List<Map<String, Object?>> exercises = const [],
    List<Map<String, Object?>> sets = const [],
    List<Map<String, Object?>> audits = const [],
    HistoryProgrammeWitness? programmeWitness,
    bool missingRecord = false,
    HistoryReadConsistency consistency =
        HistoryReadConsistency.singleStatementSnapshot,
    bool completeTree = true,
    bool completeAudits = true,
    String athlete = 'synthetic.athlete',
  }) => HistoryReadFrame(
    athleteId: athlete,
    consistency: consistency,
    completeRecordTree: completeTree,
    completeAuditSet: completeAudits,
    record: missingRecord ? null : recordRow ?? record(),
    blocks: blocks ?? (missingRecord ? [] : [blockRow ?? block()]),
    exercises: exercises,
    sets: sets,
    corrections: audits,
    programmeWitness: programmeWitness,
  );
}

final class FakeHistoryReader implements HistoryTrackingReadPort {
  FakeHistoryReader(this.frame);
  HistoryReadFrame frame;
  String? actor = 'synthetic.athlete';
  int reads = 0;
  HistoryProgrammeClaim? receivedClaim;
  Future<void> Function()? onRead;
  @override
  String? get authenticatedAthleteId => actor;
  @override
  Future<HistoryReadFrame> readCurrentRecord(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  }) async {
    reads++;
    receivedClaim = programmeClaim;
    if (onRead != null) await onRead!();
    return frame;
  }
}
