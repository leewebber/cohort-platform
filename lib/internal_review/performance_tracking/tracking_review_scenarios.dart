/// Synthetic internal-review inputs only. No registry, transport or live data.
library;

import '../../application/performance_tracking/history_tracking_adapter.dart';
import '../../application/performance_tracking/profile_tracking_evaluator.dart';
import '../../domain/performance_tracking/performance_tracking.dart';

enum TrackingReviewScenario {
  complete('Complete profile', 'Two distinct recorded observations'),
  missing('Missing and partial', 'Capture states and selected-field coverage'),
  corrected('Corrected evidence', 'Current facts and historical limits'),
  incompatible('Incompatible evidence', 'Units, methods and retained context'),
  aliases('Duplicate source aliases', 'Shared facts and explicit conflicts'),
  attribution('Independent and programme', 'Separate evidence and attribution');

  const TrackingReviewScenario(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

final class TrackingReviewCase {
  TrackingReviewCase({
    required this.title,
    required this.note,
    required this.definitions,
    required this.profile,
    required this.inputs,
    required this.comparisons,
    required this.frames,
    required this.labels,
  }) : evaluation = ProfileTrackingEvaluator(definitions: definitions).evaluate(
         athleteId: _athlete,
         profiles: [TrackingProfileRequest(profile: profile.reference)],
         inputs: inputs,
         comparisons: comparisons,
       );

  final String title;
  final String note;
  final List<TrackingArtifact> definitions;
  final TrackingProfile profile;
  final List<TrackingEvaluationInput> inputs;
  final List<TrackingComparisonRequest> comparisons;
  final List<HistoryReadFrame> frames;
  final Map<String, String> labels;
  final ProfileTrackingEvaluation evaluation;

  List<TrackingMetricDefinition> get metrics => [
    for (final ref in profile.metrics)
      definitions.whereType<TrackingMetricDefinition>().singleWhere(
        (m) => m.reference.digest == ref.digest,
      ),
  ];

  /// Re-evaluation is useful for review verification without a second engine.
  ProfileTrackingEvaluation reevaluate({bool reverseInputs = false}) =>
      ProfileTrackingEvaluator(definitions: definitions).evaluate(
        athleteId: _athlete,
        profiles: [TrackingProfileRequest(profile: profile.reference)],
        inputs: reverseInputs ? inputs.reversed.toList() : inputs,
        comparisons: comparisons,
      );
}

const _athlete = 'synthetic.c4.athlete';

/// Like C2's test fake port, each immutable frame is a synthetic producer promise.
/// It is not evidence of an authenticated database or cross-record snapshot.
final class _SyntheticReader implements HistoryTrackingReadPort {
  const _SyntheticReader(this.frame);
  final HistoryReadFrame frame;
  @override
  String get authenticatedAthleteId => _athlete;
  @override
  Future<HistoryReadFrame> readCurrentRecord(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  }) async => frame;
}

final class _Source {
  const _Source(
    this.id,
    this.label,
    this.metric,
    this.frame,
    this.field, {
    this.claim,
  });
  final String id;
  final String label;
  final TrackingMetricDefinition metric;
  final HistoryReadFrame frame;
  final HistoryFieldSelection field;
  final HistoryProgrammeClaim? claim;
}

TrackingMethodDefinition _method(TrackingUnit unit, {String suffix = ''}) =>
    TrackingMethodDefinition(
      id: 'synthetic.c4.extract.${unit.name}$suffix',
      version: 1,
      kind: TrackingMethodKind.fieldExtraction,
      inputUnits: [unit],
      outputUnit: unit,
    );

TrackingMetricDefinition _metric({
  String suffix = '',
  String field = 'durationSeconds',
  TrackingUnit unit = TrackingUnit.seconds,
  bool allowPartial = false,
  TrackingMethodDefinition? method,
  String? label,
}) => TrackingMetricDefinition(
  id: 'synthetic.c4.metric.$field.${unit.name}$suffix',
  version: 1,
  label: label ?? 'Synthetic block duration',
  unit: unit,
  method: (method ?? _method(unit)).reference,
  allowedSources: method?.kind == TrackingMethodKind.difference
      ? const []
      : const [TrackingSourceKind.historyResult],
  captureField: field,
  allowPartial: allowPartial,
  requiredContext: const [],
  requiresAssessment: false,
);

HistoryFieldSelection _field(
  String key,
  TrackingMetricDefinition metric, {
  String? audit,
}) => HistoryFieldSelection(
  recordId: 'synthetic.c4.record.$key',
  blockResultId: 'synthetic.c4.result.$key',
  sourceBlockId: 'synthetic.c4.block.$key',
  fieldPath: metric.captureField == 'duration_seconds'
      ? ['duration_seconds']
      : ['result_data', metric.captureField],
  exerciseResultId: metric.captureField == 'duration_seconds'
      ? 'synthetic.c4.exercise.$key'
      : null,
  setResultId: metric.captureField == 'duration_seconds'
      ? 'synthetic.c4.set.$key'
      : null,
  expectedCorrectionId: audit,
);

HistoryReadFrame _frame(
  String key, {
  num? value = 12,
  String state = 'completed',
  String sessionState = 'completed',
  String? context = 'synthetic.c4.context',
  String date = '2026-01-01',
  bool dateOnly = false,
  String? distanceUnit,
  bool setDuration = false,
  List<Map<String, Object?>> corrections = const [],
  HistoryProgrammeWitness? witness,
}) => HistoryReadFrame(
  athleteId: _athlete,
  consistency: HistoryReadConsistency.singleStatementSnapshot,
  completeRecordTree: true,
  completeAuditSet: true,
  record: {
    'record_id': 'synthetic.c4.record.$key',
    'athlete_id': _athlete,
    'status': sessionState,
    'started_at': '${date}T12:00:00Z',
    'performed_precision': dateOnly ? 'date' : 'timestamp',
    if (dateOnly) 'performed_on': date,
    'training_session_id': 17,
    'source_protocol_id': 'synthetic.c4.protocol',
    'assignment_id': 'synthetic.c4.assignment',
  },
  blocks: [
    {
      'block_result_id': 'synthetic.c4.result.$key',
      'session_record_id': 'synthetic.c4.record.$key',
      'source_block_id': 'synthetic.c4.block.$key',
      'status': state,
      'result_type': distanceUnit == null ? 'duration' : 'distance',
      'block_snapshot': {
        'sourceBlockId': 'synthetic.c4.block.$key',
        'comparisonFamily': ?context,
      },
      'result_data': {
        'resultType': distanceUnit == null ? 'duration' : 'distance',
        (distanceUnit == null ? 'durationSeconds' : 'distance'): ?value,
        'distanceUnit': ?distanceUnit,
      },
    },
  ],
  exercises: [
    if (setDuration)
      {
        'exercise_result_id': 'synthetic.c4.exercise.$key',
        'block_result_id': 'synthetic.c4.result.$key',
      },
  ],
  sets: [
    if (setDuration)
      {
        'set_result_id': 'synthetic.c4.set.$key',
        'exercise_result_id': 'synthetic.c4.exercise.$key',
        'completed': true,
        'duration_seconds': value,
      },
  ],
  corrections: corrections,
  programmeWitness: witness,
);

_Source _source(
  String key,
  String label,
  TrackingMetricDefinition metric, {
  HistoryReadFrame? frame,
  String? alias,
  String? audit,
  HistoryProgrammeClaim? claim,
}) => _Source(
  alias ?? key,
  label,
  metric,
  frame ?? _frame(key),
  _field(key, metric, audit: audit),
  claim: claim,
);

TrackingComparisonRequest _pair(
  String id,
  TrackingMetricDefinition m,
  String a,
  String b,
) => TrackingComparisonRequest(
  id: id,
  metric: m.reference,
  policy: TrackingComparabilityPolicy.reference,
  leftInputId: a,
  rightInputId: b,
);

Future<TrackingReviewCase> _case(
  String title,
  String note,
  List<_Source> sources, {
  List<TrackingComparisonRequest> pairs = const [],
  List<TrackingMethodDefinition> extraMethods = const [],
}) async {
  final metrics = {
    for (final s in sources) s.metric.id: s.metric,
  }.values.toList();
  final methods = {
    for (final m in metrics) _method(m.unit).id: _method(m.unit),
    for (final m in extraMethods) m.id: m,
  }.values.toList();
  // Include only referenced methods; no unused conflicting method identity.
  final usedMethods = methods
      .where((m) => metrics.any((v) => v.method.digest == m.digest))
      .toList();
  final profile = TrackingProfile(
    id: 'synthetic.c4.profile.${sources.first.id}',
    version: 1,
    kind: TrackingProfileKind.curated,
    name: 'Synthetic observation profile',
    metrics: metrics.map((m) => m.reference).toList(),
  );
  final definitions = <TrackingArtifact>[...usedMethods, ...metrics, profile];
  final inputs = <TrackingEvaluationInput>[];
  for (final s in sources) {
    final query = HistoryTrackingQuery(
      athleteId: _athlete,
      metric: s.metric.reference,
      field: s.field,
      programmeClaim: s.claim,
    );
    inputs.add(
      TrackingEvaluationInput(
        id: s.id,
        query: query,
        result: await HistoryTrackingAdapter(
          reader: _SyntheticReader(s.frame),
          definitions: definitions,
        ).read(query),
      ),
    );
  }
  return TrackingReviewCase(
    title: title,
    note: note,
    definitions: List.unmodifiable(definitions),
    profile: profile,
    inputs: List.unmodifiable(inputs),
    comparisons: pairs,
    frames: List.unmodifiable(sources.map((s) => s.frame)),
    labels: Map.unmodifiable({for (final s in sources) s.id: s.label}),
  );
}

TrackingProgrammeScope _scope(String key) => TrackingProgrammeScope(
  programmeVersionId: 'synthetic.c4.version',
  packageHash: List.filled(64, 'a').join(),
  slotKey: 'synthetic.c4.slot',
  protocolId: 'synthetic.c4.protocol',
  protocolRevision: 1,
  blockId: 'synthetic.c4.block.$key',
);
HistoryProgrammeClaim _claim(String key) => HistoryProgrammeClaim(
  assignmentId: 'synthetic.c4.assignment',
  occurrenceId: 'synthetic.c4.occurrence',
  trainingSessionId: '17',
  scope: _scope(key),
);
HistoryProgrammeWitness _witness(String key, {bool conflict = false}) =>
    HistoryProgrammeWitness(
      athleteId: _athlete,
      recordId: 'synthetic.c4.record.$key',
      assignmentId: 'synthetic.c4.assignment',
      occurrenceId: conflict
          ? 'synthetic.c4.other-occurrence'
          : 'synthetic.c4.occurrence',
      trainingSessionId: '17',
      scope: _scope(key),
    );

/// Each case runs C2 followed by C3. No fabricated evaluator output or arithmetic.
Future<List<TrackingReviewCase>> buildTrackingReviewScenario(
  TrackingReviewScenario scenario,
) async {
  final m = _metric();
  switch (scenario) {
    case TrackingReviewScenario.complete:
      return [
        await _case(
          'Complete selected fields',
          'Two independently supplied synthetic record frames; no cross-record snapshot is asserted.',
          [
            _source('a', 'Observation A', m),
            _source(
              'b',
              'Observation B',
              m,
              frame: _frame('b', value: 14, date: '2026-01-08'),
            ),
          ],
          pairs: [_pair('pair', m, 'a', 'b')],
        ),
      ];
    case TrackingReviewScenario.missing:
      final partial = _metric(
        suffix: '.partial',
        allowPartial: true,
        label: 'Synthetic duration — partial values visible',
      );
      return [
        await _case(
          'Capture is not completion',
          'A complete selected field can remain eligible within a partial session. Partial values never become comparison operands.',
          [
            _source(
              'complete-field',
              'Complete field in a partial session',
              m,
              frame: _frame(
                'complete-field',
                sessionState: 'partially_completed',
              ),
            ),
            _source(
              'missing',
              'Missing observation',
              m,
              frame: _frame('missing', state: 'not_started', value: null),
            ),
            _source(
              'partial',
              'Partial observation',
              m,
              frame: _frame('partial', state: 'in_progress'),
            ),
            _source(
              'partial',
              'Partial observation — permissive view',
              partial,
              alias: 'partial-visible',
              frame: _frame('partial', state: 'in_progress'),
            ),
            _source(
              'skipped',
              'Skipped observation',
              m,
              frame: _frame('skipped', state: 'skipped', value: null),
            ),
            _source(
              'unavailable',
              'Completed field without a value',
              m,
              frame: _frame('unavailable', value: null, dateOnly: true),
            ),
          ],
          pairs: [
            _pair('missing-pair', m, 'complete-field', 'missing'),
            _pair('partial-pair', m, 'complete-field', 'partial'),
          ],
        ),
      ];
    case TrackingReviewScenario.corrected:
      final setMetric = _metric(
        field: 'duration_seconds',
        label: 'Synthetic set duration',
      );
      final audits = <Map<String, Object?>>[
        for (final id in ['synthetic.c4.audit.one', 'synthetic.c4.audit.two'])
          {
            'correction_id': id, 'record_id': 'synthetic.c4.record.corrected',
            'athlete_id': _athlete, 'training_session_id': 17,
            'corrected_at': '2026-01-02T12:00:00Z',
            // Legacy payload lacks selected duration and completion fields.
            'before_values': {
              'set:synthetic.c4.set.corrected': {'reps': 2},
            },
            'after_values': {
              'set:synthetic.c4.set.corrected': {'reps': 3},
            },
          },
      ];
      return [
        await _case(
          'Current value with audit provenance',
          'Correction audit present; earlier inputs unavailable. Tied audit times do not identify a latest revision or prove this field changed.',
          [
            _source(
              'corrected',
              'Current recorded set duration',
              setMetric,
              audit: 'synthetic.c4.audit.one',
              frame: _frame(
                'corrected',
                setDuration: true,
                corrections: audits,
              ),
            ),
          ],
        ),
      ];
    case TrackingReviewScenario.incompatible:
      final km = _metric(
        field: 'distance',
        unit: TrackingUnit.kilometres,
        label: 'Synthetic block distance',
      );
      final alternative = _method(TrackingUnit.seconds, suffix: '.alternative');
      final different = _metric(
        suffix: '.alternative',
        method: alternative,
        label: 'Synthetic duration — alternate method',
      );
      final difference = TrackingMethodDefinition(
        id: 'synthetic.c4.difference',
        version: 1,
        kind: TrackingMethodKind.difference,
        inputUnits: [TrackingUnit.seconds, TrackingUnit.seconds],
        outputUnit: TrackingUnit.seconds,
      );
      final unsupported = _metric(
        suffix: '.difference',
        method: difference,
        label: 'Synthetic unsupported difference',
      );
      return [
        await _case(
          'Source units differ',
          'Recorded metres remain metres; no unit conversion is performed.',
          [
            _source(
              'metres',
              'Recorded metres',
              km,
              frame: _frame('metres', distanceUnit: 'm'),
            ),
            _source(
              'kilometres',
              'Recorded kilometres',
              km,
              frame: _frame('kilometres', distanceUnit: 'km'),
            ),
          ],
          pairs: [_pair('units', km, 'metres', 'kilometres')],
        ),
        await _case(
          'Exact methods differ',
          'Matching field labels do not make different definitions or methods equivalent.',
          [
            _source('method-a', 'Original extraction method', m),
            _source('method-b', 'Alternate extraction method', different),
          ],
          extraMethods: [alternative],
          pairs: [_pair('methods', m, 'method-a', 'method-b')],
        ),
        await _case(
          'Context differs or is missing',
          'Only retained source context can admit a pair.',
          [
            _source('context-a', 'Known context', m),
            _source(
              'context-b',
              'Different context',
              m,
              frame: _frame('context-b', context: 'synthetic.c4.other'),
            ),
            _source(
              'context-c',
              'Context not retained',
              m,
              frame: _frame('context-c', context: null),
            ),
          ],
          pairs: [
            _pair('context-different', m, 'context-a', 'context-b'),
            _pair('context-missing', m, 'context-a', 'context-c'),
          ],
        ),
        await _case(
          'Unsupported method',
          'A difference signature is not executable authority. No observation or calculated result is admitted.',
          [_source('unsupported', 'Unsupported request', unsupported)],
          extraMethods: [difference],
        ),
      ];
    case TrackingReviewScenario.aliases:
      return [
        await _case(
          'One physical observation, two references',
          'Aliases reuse a fact; they do not create two attempts.',
          [
            _source('shared', 'Reference A', m, alias: 'alias-a'),
            _source('shared', 'Reference B', m, alias: 'alias-b'),
          ],
          pairs: [_pair('self-pair', m, 'alias-a', 'alias-b')],
        ),
        await _case(
          'Contradictory source aliases',
          'Conflicting current values for one physical source fail the evaluation. No winner or last-good value is displayed.',
          [
            _source(
              'conflict',
              'Conflicting reference A',
              m,
              alias: 'conflict-a',
            ),
            _source(
              'conflict',
              'Conflicting reference B',
              m,
              alias: 'conflict-b',
              frame: _frame('conflict', value: 14),
            ),
          ],
        ),
      ];
    case TrackingReviewScenario.attribution:
      return [
        await _case(
          'Independent fact; programme scope unproven',
          'The independent result was separately requested. The unproven programme request is retained; no fallback is performed.',
          [
            _source(
              'scope',
              'Independent observation',
              m,
              alias: 'independent',
            ),
            _source(
              'scope',
              'Programme claim without retained proof',
              m,
              alias: 'unproven',
              claim: _claim('scope'),
            ),
          ],
        ),
        await _case(
          'Proven synthetic scope',
          'A fake C2 witness exercises exact scope composition only; it does not establish live publication, authentication or test completion.',
          [
            _source(
              'proven',
              'Synthetic programme-scoped observation',
              m,
              claim: _claim('proven'),
              frame: _frame('proven', witness: _witness('proven')),
            ),
          ],
        ),
        await _case(
          'Contradictory programme proof',
          'A mismatching witness fails the request; no independent observation is admitted from that failed read.',
          [
            _source(
              'contradictory',
              'Conflicting programme claim',
              m,
              claim: _claim('contradictory'),
              frame: _frame(
                'contradictory',
                witness: _witness('contradictory', conflict: true),
              ),
            ),
          ],
        ),
      ];
  }
}
