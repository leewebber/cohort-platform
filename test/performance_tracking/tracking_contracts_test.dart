import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tracking_fixtures.dart';

TrackingArtifact edit(
  TrackingArtifact a,
  void Function(Map<String, dynamic>) change,
) {
  final json = jsonDecode(a.canonicalJson) as Map<String, dynamic>;
  change(json);
  return TrackingCodec.decode(jsonEncode(json));
}

Set<String> codes(List<TrackingArtifact> artifacts) => TrackingValidator(
  knownTimezoneIds: const {'Asia/Makassar'},
).validate(artifacts).map((issue) => issue.code).toSet();

void main() {
  test(
    'tracking schema 1 synthetic method golden bytes and SHA-256 are fixed',
    () {
      final method = TrackingFixtures.method();
      expect(
        method.canonicalJson,
        File(
          'test/performance_tracking/fixtures/synthetic_method_v1.canonical.json',
        ).readAsStringSync().trim(),
      );
      expect(
        method.digest,
        File(
          'test/performance_tracking/fixtures/synthetic_method_v1.sha256',
        ).readAsStringSync().trim(),
      );
    },
  );

  test('synthetic closure is valid without production composition', () {
    expect(codes(TrackingFixtures.all), isEmpty);
  });

  test('every artifact round trips exact canonical bytes and hashes', () {
    for (final artifact in TrackingFixtures.all) {
      final decoded = TrackingCodec.decode(artifact.canonicalJson);
      expect(decoded.canonicalJson, artifact.canonicalJson);
      expect(decoded.digest, artifact.digest);
      expect(decoded.digest, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
    final decoded = TrackingFixtures.all
        .map((a) => TrackingCodec.decode(a.canonicalJson))
        .toList();
    expect(codes(decoded), isEmpty);
  });

  test('object key order and whitespace do not change canonical identity', () {
    final a = TrackingFixtures.metric();
    final map = jsonDecode(a.canonicalJson) as Map<String, dynamic>;
    final reversed = {
      for (final key in map.keys.toList().reversed) key: map[key],
    };
    expect(
      TrackingCodec.decode(
        const JsonEncoder.withIndent('  ').convert(reversed),
      ).digest,
      a.digest,
    );
  });

  test('unordered policies normalize; profile display order is retained', () {
    final a = TrackingFixtures.metric();
    final b = edit(
      a,
      (m) => m['allowed_sources'] = (m['allowed_sources'] as List).reversed
          .toList(),
    );
    expect(b.digest, a.digest);
    final m2 = TrackingFixtures.metric(version: 2);
    final p = TrackingProfile(
      id: 'synthetic.multi',
      version: 1,
      kind: TrackingProfileKind.curated,
      name: 'Synthetic',
      metrics: [a.reference, m2.reference],
    );
    final reversed = edit(
      p,
      (m) => m['metrics'] = (m['metrics'] as List).reversed.toList(),
    );
    expect(reversed.digest, isNot(p.digest));
  });

  test(
    'definition changes invalidate dependent digests until explicitly repinned',
    () {
      final metric = TrackingFixtures.metric();
      final changed = edit(
        metric,
        (m) => m['label'] = 'Changed synthetic meaning',
      );
      expect(changed.digest, isNot(metric.digest));
      expect(
        codes([TrackingFixtures.method(), changed, TrackingFixtures.curated()]),
        contains('reference_digest_mismatch'),
      );
    },
  );

  test('constructors defensively freeze input collections', () {
    final metrics = [TrackingFixtures.metric().reference];
    final p = TrackingProfile(
      id: 'synthetic',
      version: 1,
      kind: TrackingProfileKind.curated,
      name: 'Synthetic',
      metrics: metrics,
    );
    final hash = p.digest;
    metrics.clear();
    expect(p.digest, hash);
    expect(() => p.metrics.clear(), throwsUnsupportedError);
    final m = TrackingFixtures.measurement();
    expect(() => m.context['setting'] = 'mutated', throwsUnsupportedError);
  });

  for (final field in ['formula', 'prescription_eligible', 'target', 'score']) {
    test('wire contract rejects $field', () {
      expect(
        () => edit(TrackingFixtures.metric(), (m) => m[field] = 'invented'),
        throwsFormatException,
      );
    });
  }

  test(
    'strict nested reader rejects malformed vocabulary, nulls and timestamps',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (m) => m['unit'] = 'mystery',
        (m) => m['method']['version'] = 1.5,
        (m) => m['method']['formula'] = 'invented',
        (m) => m['schema_version'] = 3,
        (m) => m.remove('label'),
      ]) {
        expect(
          () => edit(TrackingFixtures.metric(), change),
          throwsFormatException,
        );
      }
      expect(
        () => edit(TrackingFixtures.curated(), (m) => m['athlete_id'] = null),
        throwsFormatException,
      );
      expect(
        () => edit(
          TrackingFixtures.selection(),
          (m) => m['recorded_at'] = '2026-01-02T12:00:00',
        ),
        throwsFormatException,
      );
    },
  );

  test('invalid and duplicate artifact identities fail closed', () {
    final a = TrackingFixtures.method();
    expect(codes([a, a]), contains('duplicate_identity'));
    expect(
      codes([edit(a, (m) => m['version'] = 0)]),
      contains('invalid_identity'),
    );
  });

  test(
    'unresolved versions, bad digest and wrong-kind references are rejected',
    () {
      final m = TrackingFixtures.metric();
      expect(codes([m]), contains('unresolved_method'));
      expect(
        codes([
          TrackingFixtures.method(),
          edit(m, (j) => j['method']['digest'] = TrackingFixtures.digestB),
        ]),
        contains('reference_digest_mismatch'),
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(
            TrackingFixtures.curated(),
            (j) =>
                j['metrics'][0] = TrackingFixtures.method().reference.toJson(),
          ),
        ]),
        contains('unresolved_metric'),
      );
    },
  );

  test(
    'duplicate metric references cannot mix versions in one composition',
    () {
      final p = edit(
        TrackingFixtures.curated(),
        (m) => m['metrics'].add(
          TrackingFixtures.metric(version: 2).reference.toJson(),
        ),
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          TrackingFixtures.metric(version: 2),
          p,
        ]),
        contains('duplicate_metric'),
      );
    },
  );

  test('method arity and units are explicit; no conversion or formulas', () {
    final bad = edit(
      TrackingFixtures.method(),
      (m) => m['input_units'] = ['metres'],
    );
    expect(codes([bad]), contains('method_unit_signature_mismatch'));
    final wrong = edit(TrackingFixtures.metric(), (m) => m['unit'] = 'metres');
    expect(
      codes([TrackingFixtures.method(), wrong]),
      contains('metric_method_unit_mismatch'),
    );
    final difference = TrackingMethodDefinition(
      id: 'synthetic.difference',
      version: 1,
      kind: TrackingMethodKind.difference,
      inputUnits: [TrackingUnit.seconds, TrackingUnit.seconds],
      outputUnit: TrackingUnit.seconds,
    );
    expect(codes([difference]), isEmpty);
    final derived = edit(
      TrackingFixtures.metric(),
      (m) => m['method'] = difference.reference.toJson(),
    );
    expect(
      codes([difference, derived]),
      contains('derived_metric_cannot_capture_results'),
    );
  });

  test('custom composition revisions preserve owner and exact predecessor', () {
    final first = TrackingFixtures.custom();
    final next = TrackingFixtures.custom(version: 2, previous: first.reference);
    expect(codes([...TrackingFixtures.definitions, first, next]), isEmpty);
    expect(
      codes([
        ...TrackingFixtures.definitions,
        first,
        TrackingFixtures.custom(version: 2),
      ]),
      contains('previous_revision_required'),
    );
    expect(
      codes([
        ...TrackingFixtures.definitions,
        first,
        edit(next, (m) => m['athlete_id'] = 'other'),
      ]),
      contains('custom_profile_lineage_mismatch'),
    );
    expect(
      codes([
        ...TrackingFixtures.definitions,
        first,
        edit(next, (m) => m['previous']['version'] = 2),
      ]),
      contains('revision_lineage_mismatch'),
    );
  });

  test('curated profiles cannot contain athlete state', () {
    expect(
      codes([
        ...TrackingFixtures.definitions,
        edit(TrackingFixtures.curated(), (m) => m['athlete_id'] = 'other'),
      ]),
      contains('curated_profile_has_athlete_state'),
    );
  });

  test('curated updates preserve old selection until explicit upgrade', () {
    final first = TrackingFixtures.selection();
    final p2 = TrackingFixtures.curated(version: 2);
    final next = TrackingFixtures.selection(
      version: 2,
      previous: first.reference,
      profile: p2.reference,
      action: TrackingSelectionAction.upgrade,
    );
    final closure = [
      ...TrackingFixtures.definitions,
      TrackingFixtures.curated(),
      p2,
      first,
    ];
    expect(codes([...closure, next]), isEmpty);
    expect(first.profile.digest, TrackingFixtures.curated().digest);
    expect(
      codes([...closure, edit(next, (m) => m['action'] = 'revise')]),
      contains('explicit_upgrade_required'),
    );
    final noChange = TrackingFixtures.selection(
      version: 2,
      previous: first.reference,
      action: TrackingSelectionAction.upgrade,
    );
    expect(
      codes([...closure, noChange]),
      contains('upgrade_requires_new_profile_version'),
    );
  });

  test(
    'selection ownership, switching, deselect and reselect are explicit',
    () {
      final first = TrackingFixtures.selection();
      final custom = TrackingFixtures.custom();
      final next = TrackingFixtures.selection(
        version: 2,
        previous: first.reference,
        profile: custom.reference,
        action: TrackingSelectionAction.select,
      );
      final closure = [
        ...TrackingFixtures.definitions,
        TrackingFixtures.curated(),
        custom,
        first,
      ];
      expect(codes([...closure, next]), isEmpty);
      expect(
        codes([...closure, edit(next, (m) => m['athlete_id'] = 'other')]),
        contains('selection_profile_owner_mismatch'),
      );
      final off = TrackingFixtures.selection(
        version: 2,
        previous: first.reference,
        action: TrackingSelectionAction.deselect,
      );
      expect(codes([...closure, off]), isEmpty);
      final back = TrackingFixtures.selection(
        version: 3,
        previous: off.reference,
      );
      expect(codes([...closure, off, back]), isEmpty);
    },
  );

  test(
    'manual measurement correction chain is append-only and owner-bound',
    () {
      final first = TrackingFixtures.measurement();
      final next = TrackingFixtures.measurement(
        version: 2,
        previous: first.reference,
      );
      final closure = [...TrackingFixtures.definitions, first];
      expect(codes([...closure, next]), isEmpty);
      expect(
        codes([...closure, edit(next, (m) => m['athlete_id'] = 'other')]),
        contains('measurement_correction_lineage_mismatch'),
      );
      expect(
        codes([
          ...closure,
          edit(next, (m) => m['previous']['digest'] = TrackingFixtures.digestB),
        ]),
        contains('reference_digest_mismatch'),
      );
      expect(
        codes([...closure, edit(next, (m) => m.remove('correction_reason'))]),
        contains('correction_reason_required'),
      );
      expect(
        codes([
          ...closure,
          edit(
            next,
            (m) => m['chronology']['recorded_at'] = DateTime.utc(
              2025,
            ).toIso8601String(),
          ),
        ]),
        contains('revision_time_reversed'),
      );
    },
  );

  test(
    'history field and correction identities round trip without copied actuals',
    () {
      final first = TrackingFixtures.measurement(fromHistory: true);
      final next = TrackingFixtures.measurement(
        fromHistory: true,
        version: 2,
        previous: first.reference,
        correctionId: 'synthetic.correction',
        inputDigest: TrackingFixtures.digestB,
      );
      expect(codes([...TrackingFixtures.definitions, first, next]), isEmpty);
      final decoded =
          TrackingCodec.decode(next.canonicalJson)
              as TrackingMeasurementRevision;
      expect(decoded.source.history!.recordId, 'synthetic.record');
      expect(decoded.source.history!.blockResultId, 'synthetic.block-result');
      expect(decoded.source.history!.fieldPath.last, 'duration_seconds');
      expect(decoded.source.history!.correctionId, 'synthetic.correction');
      expect(decoded.source.history!.canReconstructHistoricalInputs, isFalse);
      expect(decoded.grantsPrescriptionEligibility, isFalse);
      expect(
        () => edit(
          next,
          (m) =>
              m['source']['history']['historical_inputs'] = 'reconstructable',
        ),
        throwsFormatException,
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(first, (m) => m['canonical_value'] = '12'),
        ]),
        contains('history_value_copy_forbidden'),
      );
    },
  );

  test('changed History digest requires a new correction reference', () {
    final first = TrackingFixtures.measurement(fromHistory: true);
    final changed = TrackingFixtures.measurement(
      fromHistory: true,
      version: 2,
      previous: first.reference,
      inputDigest: TrackingFixtures.digestB,
    );
    expect(
      codes([...TrackingFixtures.definitions, first, changed]),
      contains('history_correction_reference_required'),
    );
  });

  test('history corrections cannot move to another record or field', () {
    final first = TrackingFixtures.measurement(fromHistory: true);
    final next = TrackingFixtures.measurement(
      fromHistory: true,
      version: 2,
      previous: first.reference,
    );
    expect(
      codes([
        ...TrackingFixtures.definitions,
        first,
        edit(next, (m) => m['source']['history']['record_id'] = 'other'),
      ]),
      contains('measurement_correction_lineage_mismatch'),
    );
    expect(
      codes([
        ...TrackingFixtures.definitions,
        edit(
          first,
          (m) => m['source']['history']['field_path'] = ['result_data', 'load'],
        ),
      ]),
      contains('history_metric_field_mismatch'),
    );
  });

  test(
    'reusing one source across profiles does not duplicate observations',
    () {
      expect(codes(TrackingFixtures.all), isEmpty);
      final first = TrackingFixtures.measurement(fromHistory: true);
      final duplicate = edit(first, (m) {
        m['id'] = 'different';
        m['source']['source_id'] = 'alias';
      });
      expect(
        codes([...TrackingFixtures.definitions, first, duplicate]),
        contains('duplicate_source_measurement'),
      );
    },
  );

  test(
    'measurement unit mismatch and noncanonical numeric strings are rejected',
    () {
      final m = TrackingFixtures.measurement();
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(m, (j) => j['unit'] = 'metres'),
        ]),
        contains('measurement_unit_mismatch'),
      );
      for (final v in ['NaN', 'Infinity', '01', '12.0', '-0', '-12', '1e3']) {
        expect(
          codes([
            ...TrackingFixtures.definitions,
            edit(m, (j) => j['canonical_value'] = v),
          ]),
          contains('invalid_canonical_value'),
        );
      }
    },
  );

  for (final state in TrackingEvidenceState.values.where(
    (s) => s != TrackingEvidenceState.available,
  )) {
    test('${state.name} stays explicit without fabricated zero', () {
      final m = edit(TrackingFixtures.measurement(), (j) {
        j.remove('canonical_value');
        j['evidence'] = {
          'state': state.name,
          'reason': 'synthetic_reason',
          if (state == TrackingEvidenceState.partial) 'recorded_count': 1,
          if (state == TrackingEvidenceState.partial) 'required_count': 2,
        };
      });
      expect(codes([...TrackingFixtures.definitions, m]), isEmpty);
      expect(TrackingCodec.decode(m.canonicalJson).digest, m.digest);
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(m, (j) => j['evidence'].remove('reason')),
        ]),
        contains('evidence_reason_required'),
      );
    });
  }

  test(
    'skipped/missing/unavailable cannot manufacture values; partial needs coverage',
    () {
      final m = TrackingFixtures.measurement();
      for (final state in ['missing', 'skipped', 'unavailable']) {
        expect(
          codes([
            ...TrackingFixtures.definitions,
            edit(
              m,
              (j) => j['evidence'] = {'state': state, 'reason': 'synthetic'},
            ),
          ]),
          contains('unmeasured_state_has_value'),
        );
      }
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(
            m,
            (j) => j['evidence'] = {'state': 'partial', 'reason': 'synthetic'},
          ),
        ]),
        contains('partial_coverage_required'),
      );
    },
  );

  test(
    'chronology keeps event time separate from recording and validates civil date',
    () {
      final m = TrackingFixtures.measurement();
      final civil = edit(
        m,
        (j) => j['chronology'] = {
          'precision': 'civilDate',
          'recorded_at': TrackingFixtures.time.toIso8601String(),
          'performed_on': '2026-01-01',
          'timezone': 'Asia/Makassar',
        },
      );
      expect(codes([...TrackingFixtures.definitions, civil]), isEmpty);
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(civil, (j) => j['chronology']['performed_on'] = '2026-02-30'),
        ]),
        contains('civil_date_chronology_mismatch'),
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(civil, (j) => j['chronology']['timezone'] = 'invented/zone'),
        ]),
        contains('unknown_timezone'),
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(
            m,
            (j) => j['chronology']['performed_at'] = DateTime.utc(
              2027,
            ).toIso8601String(),
          ),
        ]),
        contains('performance_after_entry'),
      );
    },
  );

  test(
    'entry never proves an assessment or programme; standalone has no programme links',
    () {
      final manual = TrackingFixtures.measurement();
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(
            manual,
            (j) => j['source']['assessment'] = TrackingFixtures.assessment()
                .reference
                .toJson(),
          ),
        ]),
        contains('manual_entry_cannot_claim_test_or_programme'),
      );
      final attempt = edit(
        manual,
        (j) => j['source'] = {
          'kind': 'assessmentAttempt',
          'source_id': 'synthetic.attempt',
          'attempt_id': 'synthetic.attempt',
          'assessment': TrackingFixtures.assessment().reference.toJson(),
        },
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          TrackingFixtures.assessment(),
          attempt,
        ]),
        isEmpty,
      );
      expect(
        (attempt as TrackingMeasurementRevision).source.programmeScope,
        isNull,
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          TrackingFixtures.assessment(),
          edit(attempt, (j) => j['source']['occurrence_id'] = 'invented'),
        ]),
        contains('programme_scope_required'),
      );
    },
  );

  test(
    'programme scope requires full exact links; mismatched block rejected',
    () {
      final history = TrackingFixtures.measurement(fromHistory: true);
      final scoped = edit(history, (j) {
        j['source']['programme_scope'] = TrackingFixtures.scope().toJson();
        j['source']['assignment_id'] = 'synthetic.assignment';
        j['source']['occurrence_id'] = 'synthetic.occurrence';
        j['source']['training_session_id'] = 'synthetic.training-session';
      });
      expect(codes([...TrackingFixtures.definitions, scoped]), isEmpty);
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(scoped, (j) => j['source'].remove('occurrence_id')),
        ]),
        contains('programme_evidence_links_required'),
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(
            scoped,
            (j) => j['source']['programme_scope']['block_id'] = 'other',
          ),
        ]),
        contains('history_programme_scope_mismatch'),
      );
    },
  );

  test(
    'bindings reject profile ownership, duplicate scope and cross-package links',
    () {
      final base = [
        ...TrackingFixtures.definitions,
        TrackingFixtures.curated(),
        TrackingFixtures.custom(),
        TrackingFixtures.assessment(),
      ];
      expect(
        codes([
          ...base,
          edit(
            TrackingFixtures.binding(),
            (j) => j['profile'] = TrackingFixtures.custom().reference.toJson(),
          ),
        ]),
        contains('programme_binding_requires_authored_profile'),
      );
      expect(
        codes([
          ...base,
          edit(
            TrackingFixtures.binding(),
            (j) => j['assessment_scopes'].add(j['assessment_scopes'][0]),
          ),
        ]),
        contains('duplicate_assessment_scope'),
      );
      expect(
        codes([
          ...base,
          edit(
            TrackingFixtures.binding(),
            (j) => j['assessment_scopes'][0]['scope']['package_hash'] =
                TrackingFixtures.digestB,
          ),
        ]),
        contains('binding_scope_mismatch'),
      );
    },
  );
  test(
    'History correction cannot change chronology, source kind or programme attribution',
    () {
      final first = TrackingFixtures.measurement(fromHistory: true);
      final next = TrackingFixtures.measurement(
        fromHistory: true,
        version: 2,
        previous: first.reference,
      );
      final closure = [
        ...TrackingFixtures.definitions,
        TrackingFixtures.assessment(),
        first,
      ];
      expect(
        codes([
          ...closure,
          edit(
            next,
            (m) => m['chronology']['performed_at'] = DateTime.utc(
              2026,
              1,
              2,
            ).toIso8601String(),
          ),
        ]),
        contains('history_event_chronology_changed'),
      );
      expect(
        codes([
          ...closure,
          edit(next, (m) {
            m['source']['kind'] = 'assessmentAttempt';
            m['source']['attempt_id'] = 'synthetic.attempt';
            m['source']['assessment'] = TrackingFixtures.assessment().reference
                .toJson();
          }),
        ]),
        contains('measurement_correction_lineage_mismatch'),
      );
      expect(
        codes([
          ...closure,
          edit(next, (m) {
            m['source']['programme_scope'] = TrackingFixtures.scope().toJson();
            m['source']['assignment_id'] = 'synthetic.assignment';
            m['source']['occurrence_id'] = 'synthetic.occurrence';
            m['source']['training_session_id'] = 'synthetic.session';
          }),
        ]),
        contains('measurement_correction_lineage_mismatch'),
      );
    },
  );

  test(
    'History references preserve set and exact running repetition identities',
    () {
      final a =
          edit(TrackingFixtures.measurement(fromHistory: true), (m) {
                m['source']['history']['exercise_result_id'] =
                    'synthetic.exercise-result';
                m['source']['history']['set_result_id'] =
                    'synthetic.set-result';
              })
              as TrackingMeasurementRevision;
      expect(codes([...TrackingFixtures.definitions, a]), isEmpty);
      expect(
        (TrackingCodec.decode(a.canonicalJson) as TrackingMeasurementRevision)
            .source
            .history!
            .setResultId,
        'synthetic.set-result',
      );
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(a, (m) => m['source']['history'].remove('exercise_result_id')),
        ]),
        contains('set_requires_exercise_result'),
      );
      final running = edit(a, (m) {
        m['source']['history'].remove('exercise_result_id');
        m['source']['history'].remove('set_result_id');
        m['source']['history']['workout_id'] = 'synthetic.workout';
        m['source']['history']['step_id'] = 'synthetic.step';
        m['source']['history']['repeat_ordinal'] = 2;
      });
      expect(codes([...TrackingFixtures.definitions, running]), isEmpty);
      expect(
        codes([
          ...TrackingFixtures.definitions,
          edit(running, (m) => m['source']['history'].remove('repeat_ordinal')),
        ]),
        contains('incomplete_history_running_identity'),
      );
    },
  );

  test('assessment required context and source policy fail closed', () {
    final metric = edit(TrackingFixtures.metric(), (m) {
      m['requires_assessment'] = true;
      m['allowed_sources'] = ['assessmentAttempt'];
    });
    final a = edit(
      TrackingFixtures.measurement(),
      (m) => m['metric'] = metric.reference.toJson(),
    );
    expect(
      codes([TrackingFixtures.method(), metric, a]),
      contains('assessment_proof_required'),
    );
    expect(
      codes([TrackingFixtures.method(), metric, a]),
      contains('unsupported_measurement_source'),
    );
    final missingContext = edit(
      TrackingFixtures.measurement(),
      (m) => m['context'] = <String, dynamic>{},
    );
    expect(
      codes([...TrackingFixtures.definitions, missingContext]),
      contains('required_context_missing'),
    );
  });

  test('validation diagnostics do not depend on supplied artifact order', () {
    final bad = edit(
      TrackingFixtures.measurement(),
      (m) => m['unit'] = 'metres',
    );
    final all = [...TrackingFixtures.all, bad];
    final validator = TrackingValidator();
    expect(
      validator.validate(all).map((i) => i.toString()).toList(),
      validator
          .validate(all.reversed.toList())
          .map((i) => i.toString())
          .toList(),
    );
  });
}
