import 'dart:convert';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import '../../domain/hyrox_base/base_personalisation.dart';

/// Trusted repository-owned synthetic definitions, not a catalogue import API.
class HyroxBindingCatalogue implements PersonalisationDependencyResolver {
  const HyroxBindingCatalogue();
  BaseMetric metric(PersonalisationTargetKind kind) => switch (kind) {
    PersonalisationTargetKind.runningIntervals => BaseMetric.run10km,
    PersonalisationTargetKind.dedicatedRowIntervals => BaseMetric.row2km,
    PersonalisationTargetKind.backSquat => BaseMetric.backSquat5rm,
  };
  PersonalisationUnit input(PersonalisationTargetKind kind) =>
      kind == PersonalisationTargetKind.backSquat
      ? PersonalisationUnit.microgramsTotalExternalLoad
      : PersonalisationUnit.milliseconds;
  PersonalisationUnit output(PersonalisationTargetKind kind) => switch (kind) {
    PersonalisationTargetKind.runningIntervals =>
      PersonalisationUnit.millisecondsPerKilometre,
    PersonalisationTargetKind.dedicatedRowIntervals =>
      PersonalisationUnit.millisecondsPer500Metres,
    PersonalisationTargetKind.backSquat =>
      PersonalisationUnit.gramsTotalExternalLoad,
  };
  Map<String, Object> benchmarkDocument(PersonalisationTargetKind kind) => {
    'id': 'hyrox-${metric(kind).name}',
    'version': 1,
    'metric': metric(kind).name,
    'unit': input(kind).name,
    'test_meaning': switch (kind) {
      PersonalisationTargetKind.runningIntervals =>
        '10 km run elapsed completion time',
      PersonalisationTargetKind.dedicatedRowIntervals =>
        '2 km row elapsed completion time',
      PersonalisationTargetKind.backSquat =>
        'back squat 5RM total external load',
    },
    'source_policy':
        'declared known result or recorded reference; local synthetic review only',
    'test_date_required': true,
    'freshness': 'none',
  };
  Map<String, Object> parameters(PersonalisationTargetKind kind, int week) {
    final r = BaseWeekRule.weeks[week - 1];
    return switch (kind) {
      PersonalisationTargetKind.runningIntervals => {
        'repetitions': r.runReps,
        'work_seconds': r.runMinutes * 60,
        'recovery_seconds': 120,
      },
      PersonalisationTargetKind.dedicatedRowIntervals => {
        'repetitions': r.rowReps,
        'work_seconds': r.rowMinutes * 60,
        'recovery_seconds': r.rowRecovery,
      },
      PersonalisationTargetKind.backSquat => {
        'sets': r.squatSets,
        'reps': r.squatReps,
        'five_rm_basis_points': r.squatBasisPoints,
        'rir': r.rir,
      },
    };
  }

  Map<String, Object> ruleDocument(PersonalisationTargetKind kind) => {
    'id': 'hyrox-base-${kind.name}',
    'version': 1,
    'approved_rule': BaseSessionPreview.ruleVersion,
    'approved_brief_sha256': BaseSessionPreview.approvedBriefSha256,
    'input_unit': input(kind).name,
    'output_unit': output(kind).name,
    'formula': switch (kind) {
      PersonalisationTargetKind.runningIntervals =>
        '10km_ms/10 * pace_multiplier; 4-5min:100/100..105/100; 6-7min:102/100..107/100; 10min:103/100..108/100',
      PersonalisationTargetKind.dedicatedRowIntervals =>
        '2km_ms/4 + split_offset_ms; 2min:+10000..15000; 3min:+12000..18000; W4:+18000..23000; W8:+15000..20000; dedicated only',
      PersonalisationTargetKind.backSquat =>
        '5rm_micrograms * authored_basis_points / 10000; nearest configured total gram increment; ties down; RIR governs adjustments',
    },
    'weeks': [
      for (var w = 1; w <= 8; w++) {'week': w, ...parameters(kind, w)},
    ],
  };
  Map<String, Object> exerciseDocument(PersonalisationTargetKind kind) => {
    'id': 'fixture-${kind.name}',
    'version': 1,
    'namespace': 'synthetic_fixture',
    'meaning': kind.name,
    'claim': 'software fixture only; no canonical ExerciseDefinition',
  };
  PersonalisationReference reference(Map<String, Object> document) =>
      PersonalisationReference(
        document['id']! as String,
        document['version']! as int,
        personalisationDigest(document),
      );
  @override
  String? validateTarget(PlanPackagePersonalisationTarget t) {
    if (t.weekNumber < 1 || t.weekNumber > 8) return 'unsupported_rule_week';
    if (personalisationCanonicalJson(t.benchmark.toJson()) !=
        personalisationCanonicalJson(
          reference(benchmarkDocument(t.kind)).toJson(),
        )) {
      return 'unresolved_benchmark_definition';
    }
    if (personalisationCanonicalJson(t.rule.toJson()) !=
        personalisationCanonicalJson(
          reference(ruleDocument(t.kind)).toJson(),
        )) {
      return 'unsupported_or_unresolved_rule';
    }
    if (t.inputUnit != input(t.kind) || t.outputUnit != output(t.kind)) {
      return 'incompatible_binding_units';
    }
    if (t.identityNamespace != 'synthetic_fixture' ||
        personalisationCanonicalJson(t.exercise.toJson()) !=
            personalisationCanonicalJson(
              reference(exerciseDocument(t.kind)).toJson(),
            )) {
      return 'unresolved_exercise_identity';
    }
    if (personalisationCanonicalJson(t.parameters) !=
        personalisationCanonicalJson(parameters(t.kind, t.weekNumber))) {
      return 'unapproved_authored_parameters';
    }
    final count = t.kind == PersonalisationTargetKind.backSquat
        ? 0
        : t.parameters['repetitions']! as int;
    if (personalisationCanonicalJson(t.stepIds) !=
        personalisationCanonicalJson([
          for (var i = 1; i <= count; i++) 'work-$i',
        ])) {
      return 'incompatible_work_step_scope';
    }
    return null;
  }
}

/// Source blocks retained independently from package references. Never accepts imported
/// bytes as source authority. This registry contains only the repository's synthetic fixture.
class SyntheticBoundFixture {
  SyntheticBoundFixture._(this.source, Map<String, String> bodies)
    : bodies = Map.unmodifiable(bodies);
  final String source;
  final Map<String, String> bodies;
  factory SyntheticBoundFixture.build() {
    const c = HyroxBindingCatalogue();
    final sessions = <Object>[], weeks = <Object>[], targets = <Object>[];
    final bodies = <String, String>{};
    for (var week = 1; week <= 8; week++) {
      final days = <Object>[];
      for (final gym in [true, false]) {
        final key = 'SYNTH-W$week-${gym ? 'GYM' : 'RUN'}';
        final protocol = '$key-R1', slot = 'W$week-${gym ? 'GYM' : 'RUN'}';
        final kinds = gym
            ? [
                PersonalisationTargetKind.backSquat,
                PersonalisationTargetKind.dedicatedRowIntervals,
              ]
            : [PersonalisationTargetKind.runningIntervals];
        final blocks = <Object>[];
        for (final kind in kinds) {
          final params = c.parameters(kind, week);
          final steps = [
            for (
              var i = 1;
              i <=
                  (kind == PersonalisationTargetKind.backSquat
                      ? 0
                      : params['repetitions']! as int);
              i++
            )
              'work-$i',
          ];
          blocks.add({
            'block_id': 'block-${kind.name}',
            'kind': kind.name,
            'identity_namespace': 'synthetic_fixture',
            'exercise': c.reference(c.exerciseDocument(kind)).toJson(),
            'parameters': params,
            'step_ids': steps,
          });
        }
        final body = {
          'protocol_id': protocol,
          'revision': 1,
          'scope': 'synthetic_partial_session',
          'blocks': blocks,
        };
        final bodyText = personalisationCanonicalJson(body);
        bodies[protocol] = bodyText;
        for (var i = 0; i < kinds.length; i++) {
          final kind = kinds[i];
          final block = blocks[i] as Map<String, Object>;
          targets.add(
            PlanPackagePersonalisationTarget(
              id: '$slot-${kind.name}',
              slotKey: slot,
              weekNumber: week,
              sessionKey: key,
              protocolId: protocol,
              protocolRevision: 1,
              sessionBodyDigest: personalisationDigest(body),
              blockId: block['block_id']! as String,
              stepIds: (block['step_ids']! as List).cast<String>(),
              identityNamespace: 'synthetic_fixture',
              exercise: c.reference(c.exerciseDocument(kind)),
              benchmark: c.reference(c.benchmarkDocument(kind)),
              rule: c.reference(c.ruleDocument(kind)),
              kind: kind,
              inputUnit: c.input(kind),
              outputUnit: c.output(kind),
              parameters: c.parameters(kind, week),
            ).toJson(),
          );
        }
        sessions.add({
          'session_key': key,
          'protocol_id': protocol,
          'session_lineage_id': 'SL-$key',
          'revision_number': 1,
          'title': 'Synthetic partial ${gym ? 'gym' : 'running'} review W$week',
        });
        days.add({
          'day_key': gym ? 'day_1' : 'day_4',
          'day_order': gym ? 1 : 2,
          'day_type': 'training',
          'slots': [
            {
              'slot_key': slot,
              'session_order': 1,
              'session_key': key,
              'progression': {
                'prescription_summary':
                    'Approved personalisation targets only; incomplete session',
                'volume_note': 'Exact bound work; supporting content absent',
                'intensity_note': 'Approved Base v1 starting guidance',
              },
            },
          ],
        });
      }
      weeks.add({'week_number': week, 'days': days});
    }
    return SyntheticBoundFixture._(
      personalisationCanonicalJson({
        'package_schema_version': 3,
        'programme': {
          'lineage_code': 'SYNTH-HYROX-BOUND',
          'version_number': 1,
          'name': 'Synthetic bound target fixture',
          'library_scope': 'cohort_global',
          'owner_type': 'global',
          'coaching_intent':
              'Software integration fixture; incomplete sessions; no commercial programme',
          'duration_weeks': 8,
        },
        'sessions': sessions,
        'phases': <Object>[],
        'weeks': weeks,
        'adaptation_permissions': <Object>[],
        'protected_invariants': <Object>[],
        'assessments': <Object>[],
        'performance_evidence_requirements': <Object>[],
        'comparison_identities': <Object>[],
        'personalisation_binding': {
          'binding_schema_version': 1,
          'freshness': 'none',
          'replacement_policy': 'explicit_consent_future_unstarted_only',
          'missing_input_policy': 'unavailable_with_authored_effort_only',
          'targets': targets,
        },
      }),
      bodies,
    );
  }
}

class BoundProgramme {
  BoundProgramme._(
    this.source,
    this.canonicalJson,
    this.hash,
    this.targets,
    this._bodies,
  );
  factory BoundProgramme.compile(
    String source, {
    SyntheticBoundFixture? sourceRegistry,
  }) {
    const c = HyroxBindingCatalogue();
    final result = const PlanPackageCompiler(
      validator: PlanPackageValidator(personalisationResolver: c),
    ).compile(source);
    if (!result.isValid) {
      throw FormatException(result.issues.map((i) => i.code).join(','));
    }
    final binding = result.manifest!.personalisationBinding;
    if (result.manifest!.packageSchemaVersion != 3 || binding == null) {
      throw const FormatException('missing_v3_binding');
    }
    final bodies = (sourceRegistry ?? SyntheticBoundFixture.build()).bodies;
    for (final t in binding.targets) {
      final text = bodies[t.protocolId];
      if (text == null) {
        throw const FormatException('unresolved_session_source');
      }
      final body = jsonDecode(text) as Map<String, dynamic>;
      if (personalisationDigest(body) != t.sessionBodyDigest ||
          body['revision'] != t.protocolRevision) {
        throw const FormatException('session_source_digest_mismatch');
      }
      final blocks = (body['blocks'] as List)
          .cast<Map<String, dynamic>>()
          .where((b) => b['block_id'] == t.blockId)
          .toList();
      if (blocks.length != 1) {
        throw const FormatException('unresolved_session_block');
      }
      final expected = {
        'block_id': t.blockId,
        'kind': t.kind.name,
        'identity_namespace': t.identityNamespace,
        'exercise': t.exercise.toJson(),
        'parameters': t.parameters,
        'step_ids': t.stepIds,
      };
      if (personalisationCanonicalJson(blocks.single) !=
          personalisationCanonicalJson(expected)) {
        throw const FormatException('session_block_binding_mismatch');
      }
    }
    return BoundProgramme._(
      source,
      result.canonicalJson!,
      result.contentHashSha256!,
      List.unmodifiable(binding.targets),
      Map.unmodifiable(bodies),
    );
  }
  final String source, canonicalJson, hash;
  final List<PlanPackagePersonalisationTarget> targets;
  final Map<String, String> _bodies;
  List<String> get slots =>
      List.unmodifiable(targets.map((t) => t.slotKey).toSet());
  String sourceBody(PlanPackagePersonalisationTarget target) =>
      _bodies[target.protocolId]!;
  Map<String, Object?> calculate(
    PlanPackagePersonalisationTarget target,
    String athlete,
    Map<String, BaseBenchmark> selected,
    int? increment,
  ) {
    const c = HyroxBindingCatalogue();
    if (!targets.contains(target)) {
      throw const FormatException('foreign_binding_target');
    }
    final b = selected[target.benchmark.id];
    final preview = const BasePersonalisationCalculator().preview(
      athleteId: athlete,
      week: target.weekNumber,
      selected: {c.metric(target.kind): ?b},
      incrementGrams: increment,
    );
    // Parameters have been independently resolved against the approved rule AND source body.
    return switch (target.kind) {
      PersonalisationTargetKind.runningIntervals => preview.run.toJson(),
      PersonalisationTargetKind.dedicatedRowIntervals => preview.row.toJson(),
      PersonalisationTargetKind.backSquat =>
        (preview.toJson()['back_squat']! as Map<String, Object?>),
    };
  }
}
