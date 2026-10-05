import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'history_tracking_fixtures.dart';

Future<HistoryTrackingResult> read(
  HistoryReadFrame frame, {
  TrackingMetricDefinition? metric,
  HistoryFieldSelection? field,
  HistoryProgrammeClaim? claim,
  Map<String, String> expectedContext = const {},
}) {
  final definition = metric ?? SyntheticHistory.metric();
  return HistoryTrackingAdapter(
    reader: FakeHistoryReader(frame),
    definitions: [SyntheticHistory.method(definition.unit), definition],
  ).read(
    HistoryTrackingQuery(
      athleteId: 'synthetic.athlete',
      metric: definition.reference,
      field: field ?? SyntheticHistory.field(name: definition.captureField),
      programmeClaim: claim,
      expectedContext: expectedContext,
    ),
  );
}

void fails(HistoryTrackingResult result, String code) {
  expect(result, isA<HistoryTrackingFailure>());
  expect((result as HistoryTrackingFailure).code, code);
  expect(result.grantsPrescriptionEligibility, isFalse);
}

void main() {
  test(
    'running input digest pins capture window and mapping even if pace is unchanged',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final field = SyntheticHistory.field(
        name: 'paceSecondsPerKm',
        running: true,
      );
      final original =
          await read(
                SyntheticHistory.frame(
                  blockRow: SyntheticHistory.runningBlock(),
                ),
                metric: metric,
                field: field,
              )
              as HistoryTrackingObservation;
      final changed = SyntheticHistory.runningBlock();
      final snapshot =
          ((changed['block_snapshot'] as Map)['structuredRunningV1'] as Map);
      (snapshot['work_repetitions'] as List).single['work_seconds'] = 11;
      snapshot['execution_mapping_sha256'] = SyntheticHistory.hashA;
      (((changed['result_data'] as Map)['intervals'] as List).single
              as Map)['workSeconds'] =
          11;
      final frame = SyntheticHistory.frame(blockRow: changed);
      final current =
          await read(frame, metric: metric, field: field)
              as HistoryTrackingObservation;
      expect(current.value, original.value);
      expect(current.source.inputDigest, isNot(original.source.inputDigest));
      fails(
        await read(
          frame,
          metric: metric,
          field: HistoryFieldSelection.fromReference(original.source),
        ),
        'source_inputs_changed',
      );
    },
  );

  test('distance cannot be read from a duration-only result shape', () async {
    fails(
      await read(
        SyntheticHistory.frame(
          blockRow: {
            ...SyntheticHistory.block(),
            'result_data': {
              'resultType': 'duration',
              'distance': 12,
              'distanceUnit': 'm',
            },
          },
        ),
        metric: SyntheticHistory.metric(
          field: 'distance',
          unit: TrackingUnit.metres,
        ),
      ),
      'unsupported_result_shape',
    );
  });

  test(
    'endurance completion must be explicitly valid, not parser-defaulted',
    () async {
      fails(
        await read(
          SyntheticHistory.frame(
            blockRow: {
              ...SyntheticHistory.block(),
              'result_type': 'endurance',
              'result_data': {'resultType': 'endurance', 'durationSeconds': 12},
            },
          ),
        ),
        'malformed_completion_state',
      );
      final result =
          await read(
                SyntheticHistory.frame(
                  blockRow: {
                    ...SyntheticHistory.block(),
                    'result_type': 'endurance',
                    'result_data': {
                      'resultType': 'endurance',
                      'durationSeconds': 12,
                      'completed': false,
                    },
                  },
                ),
              )
              as HistoryTrackingObservation;
      expect(result.evidence.state, TrackingEvidenceState.partial);
    },
  );

  test(
    'running capture window and ordinal types must match retained authored scope',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final field = SyntheticHistory.field(
        name: 'paceSecondsPerKm',
        running: true,
      );
      for (final (key, value) in [('workSeconds', 7), ('repeatOrdinal', 2.0)]) {
        final block = SyntheticHistory.runningBlock();
        (((block['result_data'] as Map)['intervals'] as List).single
                as Map)[key] =
            value;
        fails(
          await read(
            SyntheticHistory.frame(blockRow: block),
            metric: metric,
            field: field,
          ),
          'running_result_scope_mismatch',
        );
      }
    },
  );

  test(
    'optional programme claim reaches the read authority without changing source identity',
    () async {
      final metric = SyntheticHistory.metric();
      final reader = FakeHistoryReader(
        SyntheticHistory.frame(programmeWitness: SyntheticHistory.witness()),
      );
      final claim = SyntheticHistory.claim();
      final result =
          await HistoryTrackingAdapter(
                reader: reader,
                definitions: [SyntheticHistory.method(metric.unit), metric],
              ).read(
                HistoryTrackingQuery(
                  athleteId: 'synthetic.athlete',
                  metric: metric.reference,
                  field: SyntheticHistory.field(),
                  programmeClaim: claim,
                ),
              )
              as HistoryTrackingObservation;
      expect(reader.receivedClaim, same(claim));
      expect(result.sourceIdentity, SyntheticHistory.field().sourceIdentity);
      expect(reader.reads, 1);
    },
  );

  test(
    'contradictory programme witness is rejected even for an independent query',
    () async {
      final witness = HistoryProgrammeWitness(
        athleteId: 'synthetic.other',
        recordId: 'synthetic.record',
        assignmentId: 'synthetic.assignment',
        occurrenceId: 'synthetic.occurrence',
        trainingSessionId: '17',
        scope: SyntheticHistory.scope(),
      );
      fails(
        await read(SyntheticHistory.frame(programmeWitness: witness)),
        'programme_scope_mismatch',
      );
    },
  );

  test(
    'malformed running mapping and contradictory unavailable pace are rejected',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final field = SyntheticHistory.field(
        name: 'paceSecondsPerKm',
        running: true,
      );
      final block = SyntheticHistory.runningBlock();
      ((block['block_snapshot'] as Map)['structuredRunningV1']
              as Map)['execution_mapping_sha256'] =
          7;
      fails(
        await read(
          SyntheticHistory.frame(blockRow: block),
          metric: metric,
          field: field,
        ),
        'running_snapshot_mismatch',
      );
      final unavailable = SyntheticHistory.runningBlock();
      (((unavailable['result_data'] as Map)['intervals'] as List).single
              as Map)['state'] =
          'pace_unavailable';
      fails(
        await read(
          SyntheticHistory.frame(blockRow: unavailable),
          metric: metric,
          field: field,
        ),
        'contradictory_pace_state',
      );
    },
  );

  test(
    'unsupported references, paths and methods fail before reading',
    () async {
      final metric = SyntheticHistory.metric();
      final reader = FakeHistoryReader(
        SyntheticHistory.frame(missingRecord: true),
      );
      final adapter = HistoryTrackingAdapter(
        reader: reader,
        definitions: [SyntheticHistory.method(metric.unit), metric],
      );
      fails(
        await adapter.read(
          HistoryTrackingQuery(
            athleteId: 'synthetic.athlete',
            metric: TrackingReference(
              id: metric.id,
              version: metric.version,
              digest: SyntheticHistory.hashA,
            ),
            field: SyntheticHistory.field(),
          ),
        ),
        'unsupported_metric_reference',
      );
      final unsupported = SyntheticHistory.metric(field: 'plannedSeconds');
      fails(
        await HistoryTrackingAdapter(
          reader: reader,
          definitions: [SyntheticHistory.method(unsupported.unit), unsupported],
        ).read(
          HistoryTrackingQuery(
            athleteId: 'synthetic.athlete',
            metric: unsupported.reference,
            field: SyntheticHistory.field(name: 'plannedSeconds'),
          ),
        ),
        'unsupported_field_path',
      );
      final method = TrackingMethodDefinition(
        id: 'synthetic.difference',
        version: 1,
        kind: TrackingMethodKind.difference,
        inputUnits: [TrackingUnit.seconds, TrackingUnit.seconds],
        outputUnit: TrackingUnit.seconds,
      );
      final derived = TrackingMetricDefinition(
        id: 'synthetic.derived',
        version: 1,
        label: 'Synthetic signature only',
        unit: TrackingUnit.seconds,
        method: method.reference,
        allowedSources: [],
        captureField: 'durationSeconds',
      );
      fails(
        await HistoryTrackingAdapter(
          reader: reader,
          definitions: [method, derived],
        ).read(
          HistoryTrackingQuery(
            athleteId: 'synthetic.athlete',
            metric: derived.reference,
            field: SyntheticHistory.field(),
          ),
        ),
        'unsupported_method',
      );
      fails(
        await HistoryTrackingAdapter(
          reader: reader,
          definitions: [SyntheticHistory.method(metric.unit), metric, metric],
        ).read(
          HistoryTrackingQuery(
            athleteId: 'synthetic.athlete',
            metric: metric.reference,
            field: SyntheticHistory.field(),
          ),
        ),
        'invalid_definition_closure',
      );
      expect(reader.reads, 0);
    },
  );

  test('mixed current inputs and complete audit scopes are rejected', () async {
    fails(
      await read(
        SyntheticHistory.frame(
          blockRow: {
            ...SyntheticHistory.block(),
            'result_data': {'resultType': 'duration', 'durationSeconds': 15},
          },
          audits: [SyntheticHistory.audit()],
        ),
      ),
      'correction_inputs_mismatch',
    );
    final metric = SyntheticHistory.metric(
      field: 'reps',
      unit: TrackingUnit.count,
    );
    final audit = {
      ...SyntheticHistory.audit(),
      'before_values': {
        'set:synthetic.set-result': {'reps': 2, 'completed': true},
      },
      'after_values': {
        'set:synthetic.set-result': {'reps': 9, 'completed': true},
      },
    };
    fails(
      await read(
        SyntheticHistory.frame(
          exercises: [SyntheticHistory.exercise()],
          sets: [SyntheticHistory.set()],
          audits: [audit],
        ),
        metric: metric,
        field: SyntheticHistory.field(name: 'reps', fromSet: true),
      ),
      'correction_inputs_mismatch',
    );
  });

  test(
    'older incomplete set audits cannot prove previous duration or distance inputs',
    () async {
      final metric = SyntheticHistory.metric(field: 'duration_seconds');
      final audit = {
        ...SyntheticHistory.audit(),
        'before_values': {
          'set:synthetic.set-result': {
            'reps': 2,
            'load': 12,
            'completed': true,
          },
        },
        'after_values': {
          'set:synthetic.set-result': {
            'reps': 3,
            'load': 12.5,
            'completed': true,
          },
        },
      };
      final result =
          await read(
                SyntheticHistory.frame(
                  exercises: [SyntheticHistory.exercise()],
                  sets: [SyntheticHistory.set()],
                  audits: [audit],
                ),
                metric: metric,
                field: SyntheticHistory.field(
                  name: 'duration_seconds',
                  fromSet: true,
                ),
              )
              as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(result.canReconstructHistoricalInputs, isFalse);
      expect(result.source.correctionId, isNull);
    },
  );

  test(
    'raw session and audited lifecycle references cannot contradict authority',
    () async {
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {
              ...SyntheticHistory.record(),
              'training_session_id': '17',
            },
          ),
        ),
        'malformed_session_reference',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {
              ...SyntheticHistory.record(),
              'status': 'partially_completed',
            },
            audits: [SyntheticHistory.audit()],
          ),
        ),
        'correction_lifecycle_mismatch',
      );
    },
  );

  test(
    'current actual is an ephemeral exact source reference, not a measurement ledger',
    () async {
      final result =
          await read(SyntheticHistory.frame()) as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(result.unit, TrackingUnit.seconds);
      expect(result.trackingEligible, isTrue);
      expect(result.sourceIdentity, SyntheticHistory.field().sourceIdentity);
      expect(result.source.inputDigest, matches(r'^[0-9a-f]{64}$'));
      expect(result.correctionIds, isEmpty);
      expect(result.source.correctionId, isNull);
      expect(result.grantsPrescriptionEligibility, isFalse);
      expect(result.canReconstructHistoricalInputs, isFalse);
      expect(result.source.canReconstructHistoricalInputs, isFalse);
    },
  );

  test(
    'owner denial occurs before a query; auth changes during await also deny',
    () async {
      final reader = FakeHistoryReader(SyntheticHistory.frame())
        ..actor = 'synthetic.other';
      final metric = SyntheticHistory.metric();
      final adapter = HistoryTrackingAdapter(
        reader: reader,
        definitions: [SyntheticHistory.method(metric.unit), metric],
      );
      final query = HistoryTrackingQuery(
        athleteId: 'synthetic.athlete',
        metric: metric.reference,
        field: SyntheticHistory.field(),
      );
      fails(await adapter.read(query), 'ownership_denied');
      expect(reader.reads, 0);
      reader.actor = 'synthetic.athlete';
      reader.onRead = () async {
        reader.actor = 'synthetic.other';
      };
      fails(await adapter.read(query), 'ownership_denied');
      for (final frame in [
        SyntheticHistory.frame(athlete: 'synthetic.other'),
        SyntheticHistory.frame(
          recordRow: {
            ...SyntheticHistory.record(),
            'athlete_id': 'synthetic.other',
          },
        ),
      ]) {
        fails(await read(frame), 'ownership_denied');
      }
    },
  );

  test(
    'separate hydration and truncated audit/tree reads never yield actuals',
    () async {
      for (final frame in [
        SyntheticHistory.frame(consistency: HistoryReadConsistency.unproven),
        SyntheticHistory.frame(completeTree: false),
        SyntheticHistory.frame(completeAudits: false),
      ]) {
        fails(await read(frame), 'coherent_read_required');
      }
    },
  );

  test(
    'transport errors remain failures and reveal no exception details',
    () async {
      final reader = FakeHistoryReader(SyntheticHistory.frame())
        ..onRead = () async {
          throw StateError('synthetic private transport detail');
        };
      final metric = SyntheticHistory.metric();
      final result =
          await HistoryTrackingAdapter(
            reader: reader,
            definitions: [SyntheticHistory.method(metric.unit), metric],
          ).read(
            HistoryTrackingQuery(
              athleteId: 'synthetic.athlete',
              metric: metric.reference,
              field: SyntheticHistory.field(),
            ),
          );
      fails(result, 'history_read_failed');
    },
  );

  test(
    'successful no visible record or result rows is missing, not a zero',
    () async {
      for (final frame in [
        SyntheticHistory.frame(missingRecord: true),
        SyntheticHistory.frame(blocks: []),
      ]) {
        final result = await read(frame) as HistoryTrackingAbsent;
        expect(result.evidence.state, TrackingEvidenceState.missing);
      }
      fails(
        await read(
          SyntheticHistory.frame(
            missingRecord: true,
            blocks: [SyntheticHistory.block()],
          ),
        ),
        'orphaned_history_rows',
      );
    },
  );

  test(
    'record identity and block source/parent are exact, never position/name matches',
    () async {
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {
              ...SyntheticHistory.record(),
              'record_id': 'synthetic.other',
            },
          ),
        ),
        'record_reference_mismatch',
      );
      for (final entry in {
        'session_record_id': 'block_parent_mismatch',
        'source_block_id': 'source_block_mismatch',
      }.entries) {
        fails(
          await read(
            SyntheticHistory.frame(
              blockRow: {
                ...SyntheticHistory.block(),
                entry.key: 'synthetic.other',
              },
            ),
          ),
          entry.value,
        );
      }
      final block = SyntheticHistory.block();
      block['block_snapshot'] = {'sourceBlockId': 'synthetic.other'};
      fails(
        await read(SyntheticHistory.frame(blockRow: block)),
        'source_block_mismatch',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            blocks: [SyntheticHistory.block(), SyntheticHistory.block()],
          ),
        ),
        'duplicate_row_identity',
      );
    },
  );

  test(
    'exercise/set parentage and duplicate identities cannot be ambiguous',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'reps',
        unit: TrackingUnit.count,
      );
      final field = SyntheticHistory.field(name: 'reps', fromSet: true);
      for (final (exercises, sets, code) in [
        (
          [
            {
              ...SyntheticHistory.exercise(),
              'block_result_id': 'synthetic.other',
            },
          ],
          [SyntheticHistory.set()],
          'exercise_parent_mismatch',
        ),
        (
          [SyntheticHistory.exercise()],
          [
            {
              ...SyntheticHistory.set(),
              'exercise_result_id': 'synthetic.other',
            },
          ],
          'set_parent_mismatch',
        ),
        (
          [SyntheticHistory.exercise()],
          [SyntheticHistory.set(), SyntheticHistory.set()],
          'duplicate_row_identity',
        ),
      ]) {
        fails(
          await read(
            SyntheticHistory.frame(exercises: exercises, sets: sets),
            metric: metric,
            field: field,
          ),
          code,
        );
      }
      final missing =
          await read(
                SyntheticHistory.frame(
                  exercises: [SyntheticHistory.exercise()],
                ),
                metric: metric,
                field: field,
              )
              as HistoryTrackingAbsent;
      expect(missing.reason, 'set_result_missing');
    },
  );

  test(
    'supported set fields have canonical units without conversion',
    () async {
      for (final (name, unit, value) in [
        ('reps', TrackingUnit.count, '3'),
        ('load', TrackingUnit.kilograms, '12.5'),
        ('duration_seconds', TrackingUnit.seconds, '12'),
        ('distance', TrackingUnit.metres, '12'),
      ]) {
        final result =
            await read(
                  SyntheticHistory.frame(
                    exercises: [SyntheticHistory.exercise()],
                    sets: [SyntheticHistory.set()],
                  ),
                  metric: SyntheticHistory.metric(field: name, unit: unit),
                  field: SyntheticHistory.field(name: name, fromSet: true),
                )
                as HistoryTrackingObservation;
        expect(result.value, value);
        expect(result.unit, unit);
        expect(result.trackingEligible, isTrue);
      }
    },
  );

  test(
    'null field, skip, pending and incomplete scope remain distinct',
    () async {
      final metric = SyntheticHistory.metric();
      for (final (status, value, expected) in [
        ('completed', null, TrackingEvidenceState.unavailable),
        ('skipped', 12, TrackingEvidenceState.skipped),
        ('not_started', null, TrackingEvidenceState.missing),
        ('in_progress', 12, TrackingEvidenceState.partial),
      ]) {
        final block = {
          ...SyntheticHistory.block(),
          'status': status,
          'result_data': {'resultType': 'duration', 'durationSeconds': value},
        };
        final result =
            await read(SyntheticHistory.frame(blockRow: block), metric: metric)
                as HistoryTrackingObservation;
        expect(result.evidence.state, expected);
        expect(result.value, isNull);
        expect(result.trackingEligible, isFalse);
      }
      final partial =
          await read(
                SyntheticHistory.frame(
                  blockRow: {
                    ...SyntheticHistory.block(),
                    'status': 'in_progress',
                  },
                ),
                metric: SyntheticHistory.metric(allowPartial: true),
              )
              as HistoryTrackingObservation;
      expect(partial.value, '12');
      expect(partial.evidence.state, TrackingEvidenceState.partial);
      expect(partial.evidence.recordedCount, 0);
      expect(partial.evidence.requiredCount, 1);
      expect(partial.trackingEligible, isFalse);
    },
  );

  test(
    'complete scope within partial session is an actual, not a full test result',
    () async {
      final result =
          await read(
                SyntheticHistory.frame(
                  recordRow: {
                    ...SyntheticHistory.record(),
                    'status': 'partially_completed',
                  },
                ),
              )
              as HistoryTrackingObservation;
      expect(result.trackingEligible, isTrue);
      expect(result.value, '12');
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {...SyntheticHistory.record(), 'status': 'in_progress'},
          ),
        ),
        'record_not_terminal',
      );
    },
  );

  test(
    'malformed numeric fields are rejected before permissive parsing',
    () async {
      for (final value in [
        '12',
        true,
        -1,
        double.nan,
        double.infinity,
        1.5,
        {'value': 12},
      ]) {
        fails(
          await read(
            SyntheticHistory.frame(
              blockRow: {
                ...SyntheticHistory.block(),
                'result_data': {
                  'resultType': 'duration',
                  'durationSeconds': value,
                },
              },
            ),
          ),
          'malformed_numeric_value',
        );
      }
      final zero =
          await read(
                SyntheticHistory.frame(
                  blockRow: {
                    ...SyntheticHistory.block(),
                    'result_data': {
                      'resultType': 'duration',
                      'durationSeconds': 0,
                    },
                  },
                ),
              )
              as HistoryTrackingObservation;
      expect(zero.value, '0');
      expect(zero.trackingEligible, isTrue);
    },
  );

  test(
    'malformed result shape/type/state and arbitrary paths are rejected',
    () async {
      fails(
        await read(
          SyntheticHistory.frame(
            blockRow: {...SyntheticHistory.block(), 'result_data': []},
          ),
        ),
        'malformed_field_shape',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            blockRow: {
              ...SyntheticHistory.block(),
              'result_data': {'resultType': 'endurance', 'durationSeconds': 12},
            },
          ),
        ),
        'contradictory_result_type',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            blockRow: {...SyntheticHistory.block(), 'status': 'invented'},
          ),
        ),
        'malformed_completion_state',
      );
      fails(
        await read(
          SyntheticHistory.frame(),
          metric: SyntheticHistory.metric(field: 'plannedSeconds'),
        ),
        'unsupported_field_path',
      );
    },
  );

  test(
    'known different units are incomparable; absent/unknown units are never guessed',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'distance',
        unit: TrackingUnit.metres,
      );
      final block = {
        ...SyntheticHistory.block(),
        'result_type': 'distance',
        'result_data': {
          'resultType': 'distance',
          'distance': 12,
          'distanceUnit': 'km',
        },
      };
      final result =
          await read(SyntheticHistory.frame(blockRow: block), metric: metric)
              as HistoryTrackingObservation;
      expect(result.evidence.state, TrackingEvidenceState.incomparable);
      expect(result.value, '12');
      expect(result.unit, TrackingUnit.kilometres);
      expect(result.trackingEligible, isFalse);
      for (final unit in [null, 'mi', '', 'KG']) {
        fails(
          await read(
            SyntheticHistory.frame(
              blockRow: {
                ...block,
                'result_data': {
                  'resultType': 'distance',
                  'distance': 12,
                  'distanceUnit': unit,
                },
              },
            ),
            metric: metric,
          ),
          'unsupported_source_unit',
        );
      }
    },
  );

  test(
    'comparison context remains observational and incompatible conditions retain individual facts',
    () async {
      final result =
          await read(
                SyntheticHistory.frame(),
                expectedContext: {'comparison_family': 'synthetic.other'},
              )
              as HistoryTrackingObservation;
      expect(result.evidence.state, TrackingEvidenceState.incomparable);
      expect(result.value, '12');
      expect(result.trackingEligible, isFalse);
      for (final metric in [
        SyntheticHistory.metric(assessment: true),
        SyntheticHistory.metric(freshness: 7),
        SyntheticHistory.metric(requiredContext: ['unsupported_context']),
        SyntheticHistory.metric(sources: [TrackingSourceKind.manualEntry]),
      ]) {
        final result =
            await read(SyntheticHistory.frame(), metric: metric)
                as HistoryTrackingObservation;
        expect(result.evidence.state, TrackingEvidenceState.ineligible);
        expect(result.trackingEligible, isFalse);
      }
    },
  );

  test(
    'correction metadata must match record, athlete, session and exact affected rows',
    () async {
      for (final key in ['record_id', 'athlete_id', 'training_session_id']) {
        fails(
          await read(
            SyntheticHistory.frame(
              audits: [
                {...SyntheticHistory.audit(), key: 'synthetic.other'},
              ],
            ),
          ),
          'correction_parent_mismatch',
        );
      }
      fails(
        await read(
          SyntheticHistory.frame(
            audits: [SyntheticHistory.audit(), SyntheticHistory.audit()],
          ),
        ),
        'duplicate_row_identity',
      );
      final audit = {
        ...SyntheticHistory.audit(),
        'before_values': {'set:synthetic.unknown': {}},
        'after_values': {'set:synthetic.unknown': {}},
      };
      fails(
        await read(SyntheticHistory.frame(audits: [audit])),
        'correction_scope_mismatch',
      );
      fails(
        await read(
          SyntheticHistory.frame(),
          field: SyntheticHistory.field(correction: 'synthetic.missing-audit'),
        ),
        'correction_reference_not_found',
      );
    },
  );

  test(
    'current read resolves exact requested audit membership, not an as-of or latest claim',
    () async {
      final result =
          await read(
                SyntheticHistory.frame(audits: [SyntheticHistory.audit()]),
                field: SyntheticHistory.field(correction: 'synthetic.audit'),
              )
              as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(result.source.correctionId, 'synthetic.audit');
      expect(result.correctionIds, ['synthetic.audit']);
      expect(result.canReconstructHistoricalInputs, isFalse);
      final query = HistoryFieldSelection.fromReference(result.source);
      expect(
        (await read(
                  SyntheticHistory.frame(audits: [SyntheticHistory.audit()]),
                  field: query,
                )
                as HistoryTrackingObservation)
            .source
            .inputDigest,
        result.source.inputDigest,
      );
    },
  );

  test(
    'a correction between observations makes an existing input reference stale',
    () async {
      final original =
          await read(SyntheticHistory.frame()) as HistoryTrackingObservation;
      final field = HistoryFieldSelection.fromReference(original.source);
      final changed = SyntheticHistory.frame(
        blockRow: {
          ...SyntheticHistory.block(),
          'result_data': {'resultType': 'duration', 'durationSeconds': 15},
        },
        audits: [
          {
            ...SyntheticHistory.audit(),
            'after_values': {
              'block:synthetic.block-result:result_data': {
                'resultType': 'duration',
                'durationSeconds': 15,
              },
            },
          },
        ],
      );
      fails(await read(changed, field: field), 'source_inputs_changed');
      final current = await read(changed) as HistoryTrackingObservation;
      expect(current.value, '15');
      expect(current.sourceIdentity, original.sourceIdentity);
      expect(current.source.inputDigest, isNot(original.source.inputDigest));
      expect(current.source.correctionId, isNull); // No inferred audit order.
    },
  );

  test(
    'historical reconstruction is refused even when partial audit values exist',
    () async {
      final metric = SyntheticHistory.metric();
      final reader = FakeHistoryReader(
        SyntheticHistory.frame(audits: [SyntheticHistory.audit()]),
      );
      final result =
          await HistoryTrackingAdapter(
            reader: reader,
            definitions: [SyntheticHistory.method(metric.unit), metric],
          ).read(
            HistoryTrackingQuery(
              athleteId: 'synthetic.athlete',
              metric: metric.reference,
              field: SyntheticHistory.field(correction: 'synthetic.audit'),
              historical: true,
            ),
          );
      fails(result, 'historical_inputs_unavailable');
      expect(reader.reads, 0);
    },
  );

  test(
    'input/audit digests are deterministic across map and audit enumeration',
    () async {
      final a = SyntheticHistory.audit(id: 'synthetic.audit-a');
      final b = SyntheticHistory.audit(
        id: 'synthetic.audit-b',
      ); // Timestamp tie deliberately not ordered as revisions.
      final first =
          await read(SyntheticHistory.frame(audits: [a, b]))
              as HistoryTrackingObservation;
      final second =
          await read(
                SyntheticHistory.frame(
                  recordRow: Map.fromEntries(
                    SyntheticHistory.record().entries.toList().reversed,
                  ),
                  audits: [b, a],
                ),
              )
              as HistoryTrackingObservation;
      expect(first.source.inputDigest, second.source.inputDigest);
      expect(first.auditSetDigest, second.auditSetDigest);
      expect(first.correctionIds, ['synthetic.audit-a', 'synthetic.audit-b']);
      expect(first.source.correctionId, isNull);
    },
  );

  test(
    'programme claim requires a coherent verified witness, not merely matching labels',
    () async {
      fails(
        await read(SyntheticHistory.frame(), claim: SyntheticHistory.claim()),
        'programme_scope_unproven',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {
              ...SyntheticHistory.record(),
              'assignment_id': 'synthetic.other',
            },
            programmeWitness: SyntheticHistory.witness(),
          ),
          claim: SyntheticHistory.claim(),
        ),
        'programme_scope_mismatch',
      );
      fails(
        await read(
          SyntheticHistory.frame(
            programmeWitness: SyntheticHistory.witness(
              value: SyntheticHistory.scope(slot: 'synthetic.other'),
            ),
          ),
          claim: SyntheticHistory.claim(),
        ),
        'programme_scope_mismatch',
      );
      final result =
          await read(
                SyntheticHistory.frame(
                  programmeWitness: SyntheticHistory.witness(),
                ),
                claim: SyntheticHistory.claim(),
              )
              as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(result.grantsPrescriptionEligibility, isFalse);
    },
  );

  test(
    'running pace resolves exact authored step/repetition, never displayed ordinal or timer dosage',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final field = SyntheticHistory.field(
        name: 'paceSecondsPerKm',
        running: true,
      );
      final result =
          await read(
                SyntheticHistory.frame(
                  blockRow: SyntheticHistory.runningBlock(),
                ),
                metric: metric,
                field: field,
              )
              as HistoryTrackingObservation;
      expect(result.value, '12.5');
      expect(result.source.repeatOrdinal, 2);
      expect(result.trackingEligible, isTrue);
      final block = SyntheticHistory.runningBlock();
      final data = block['result_data'] as Map<String, Object?>;
      final row = (data['intervals'] as List).single as Map<String, Object?>;
      row['authoredStepId'] = 'synthetic.other';
      fails(
        await read(
          SyntheticHistory.frame(blockRow: block),
          metric: metric,
          field: field,
        ),
        'running_result_scope_mismatch',
      );
      row['authoredStepId'] = 'synthetic.step';
      data['intervals'] = [row, row];
      fails(
        await read(
          SyntheticHistory.frame(blockRow: block),
          metric: metric,
          field: field,
        ),
        'ambiguous_running_result',
      );
    },
  );

  test(
    'running pace-unavailable/skipped/pending/missing evidence does not invent pace',
    () async {
      final metric = SyntheticHistory.metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final field = SyntheticHistory.field(
        name: 'paceSecondsPerKm',
        running: true,
      );
      for (final (state, expected) in [
        ('pace_unavailable', TrackingEvidenceState.unavailable),
        ('skipped', TrackingEvidenceState.skipped),
        ('pending', TrackingEvidenceState.partial),
      ]) {
        final block = SyntheticHistory.runningBlock();
        final row =
            (((block['result_data'] as Map)['intervals'] as List).single
                as Map);
        row['state'] = state;
        row.remove('paceSecondsPerKm');
        final result =
            await read(
                  SyntheticHistory.frame(blockRow: block),
                  metric: metric,
                  field: field,
                )
                as HistoryTrackingObservation;
        expect(result.evidence.state, expected);
        expect(result.value, isNull);
      }
      final block = SyntheticHistory.runningBlock();
      (block['result_data'] as Map)['intervals'] = [];
      final missing =
          await read(
                SyntheticHistory.frame(blockRow: block),
                metric: metric,
                field: field,
              )
              as HistoryTrackingObservation;
      expect(missing.evidence.state, TrackingEvidenceState.missing);
    },
  );

  test(
    'backfilled event date is preserved with unknown zone; corrections do not replace it with audit time',
    () async {
      final result =
          await read(
                SyntheticHistory.frame(
                  recordRow: {
                    ...SyntheticHistory.record(),
                    'performed_precision': 'date',
                    'performed_on': '2025-12-31',
                  },
                  audits: [SyntheticHistory.audit()],
                ),
              )
              as HistoryTrackingObservation;
      expect(result.chronology, {
        'precision': 'civil_date',
        'performed_on': '2025-12-31',
        'timezone': null,
      });
      fails(
        await read(
          SyntheticHistory.frame(
            recordRow: {
              ...SyntheticHistory.record(),
              'performed_precision': 'date',
              'performed_on': '2026-02-30',
            },
          ),
        ),
        'malformed_chronology',
      );
    },
  );

  test(
    'frames and output collections are immutable defensive copies',
    () async {
      final block = SyntheticHistory.block();
      final frame = SyntheticHistory.frame(blockRow: block);
      (block['result_data'] as Map)['durationSeconds'] = 99;
      final result = await read(frame) as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(
        () => frame.record!['athlete_id'] = 'synthetic.other',
        throwsUnsupportedError,
      );
      expect(
        () =>
            (frame.blocks.single['result_data'] as Map)['durationSeconds'] = 99,
        throwsUnsupportedError,
      );
      expect(
        () => result.correctionIds.add('synthetic.other'),
        throwsUnsupportedError,
      );
    },
  );
}
