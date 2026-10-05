import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

void main() {
  late String yaml;
  late String canonicalGolden;
  late String hashGolden;

  setUpAll(() {
    yaml = File(
      'test/fixtures/minimal_plan_package_v2.yaml',
    ).readAsStringSync();
    canonicalGolden = File(
      'test/fixtures/minimal_plan_package_v2.canonical.json',
    ).readAsStringSync().trim();
    hashGolden = File(
      'test/fixtures/minimal_plan_package_v2.sha256',
    ).readAsStringSync().trim();
  });

  test('v2 hashes the complete explicit authored-running document', () {
    final result = const PlanPackageCompiler().compile(yaml);

    expect(result.isValid, isTrue, reason: result.issues.toString());
    expect(result.canonicalJson, canonicalGolden);
    expect(result.contentHashSha256, hashGolden);
    final running = result
        .manifest!
        .weeks
        .single
        .days
        .single
        .slots
        .single
        .authoredRunningV1!;
    expect(running.workoutId, 'RUN-FIXTURE-A');
    expect(running.stepIds, ['STEP-WORK-1', 'STEP-WORK-2']);
    expect(
      running.advisoryAttachments.single.policy.minimumSpeedBasisPoints,
      8123,
    );

    final canonical = jsonDecode(result.canonicalJson!) as Map<String, Object?>;
    final weeks = canonical['weeks']! as List<Object?>;
    final days =
        (weeks.single as Map<String, Object?>)['days']! as List<Object?>;
    final slots =
        (days.single as Map<String, Object?>)['slots']! as List<Object?>;
    expect(
      (slots.single as Map<String, Object?>)['authored_running_v1'],
      isA<Map<String, Object?>>(),
    );

    final changed = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        'minimum_speed_basis_points: 8123',
        'minimum_speed_basis_points: 8124',
      ),
    );
    expect(changed.isValid, isTrue, reason: changed.issues.toString());
    expect(changed.contentHashSha256, isNot(result.contentHashSha256));
  });

  test(
    'v2 private payload carries canonical attestation and running document',
    () {
      final compiled = const PlanPackageCompiler().compile(yaml);
      final payload = const PlanPackageImportPayloadBuilder().build(
        compileResult: compiled,
        importedBy: 'fixture-author',
      );

      expect(payload['package_schema_version'], 2);
      expect(payload['package_canonical_json'], compiled.canonicalJson);
      final weeks = payload['weeks']! as List<Object?>;
      final days =
          (weeks.single as Map<String, Object?>)['days']! as List<Object?>;
      final slots =
          (days.single as Map<String, Object?>)['slots']! as List<Object?>;
      expect(
        (slots.single as Map<String, Object?>)['authored_running_v1'],
        isA<Map<String, Object?>>(),
      );
    },
  );

  test('v1 payload shape does not acquire v2 attestation fields', () {
    final v1 = File(
      'test/fixtures/minimal_plan_package.yaml',
    ).readAsStringSync();
    final compiled = const PlanPackageCompiler().compile(v1);
    final payload = const PlanPackageImportPayloadBuilder().build(
      compileResult: compiled,
      importedBy: 'fixture-author',
    );

    expect(payload, isNot(contains('package_canonical_json')));
    final weeks = payload['weeks']! as List<Object?>;
    for (final week in weeks.cast<Map<String, Object?>>()) {
      for (final day
          in (week['days']! as List<Object?>).cast<Map<String, Object?>>()) {
        for (final slot
            in (day['slots']! as List<Object?>).cast<Map<String, Object?>>()) {
          expect(slot, isNot(contains('authored_running_v1')));
        }
      }
    }
  });

  test('v2 authored-running document is optional', () {
    final v1 = File(
      'test/fixtures/minimal_plan_package.yaml',
    ).readAsStringSync();
    final result = const PlanPackageCompiler().compile(
      v1.replaceFirst('package_schema_version: 1', 'package_schema_version: 2'),
    );

    expect(result.isValid, isTrue, reason: result.issues.toString());
    expect(
      result.manifest!.weeks
          .expand((week) => week.days)
          .expand((day) => day.slots)
          .every((slot) => slot.authoredRunningV1 == null),
      isTrue,
    );
  });

  test('v1 rejects authored_running_v1 instead of silently omitting it', () {
    final result = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        'package_schema_version: 2',
        'package_schema_version: 1',
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.issues.map((issue) => issue.code), contains('unknown_field'));
  });

  test('unknown and malformed running fields fail closed', () {
    final unknown = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        'workout_id: RUN-FIXTURE-A',
        'workout_id: RUN-FIXTURE-A\n              invented_field: true',
      ),
    );
    expect(unknown.isValid, isFalse);
    expect(
      unknown.issues.map((issue) => issue.code),
      contains('unknown_field'),
    );

    final malformed = const PlanPackageCompiler().compile(
      yaml.replaceFirst('workout_id: RUN-FIXTURE-A', 'workout_id: bad id'),
    );
    expect(malformed.isValid, isFalse);
    expect(
      malformed.issues.map((issue) => issue.code),
      contains('invalid_identifier'),
    );
  });

  test('attachments must explicitly scope declared stable steps', () {
    final duplicate = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        '                - STEP-WORK-2\n              advisory_attachments:',
        '                - STEP-WORK-1\n              advisory_attachments:',
      ),
    );
    expect(duplicate.isValid, isFalse);
    expect(
      duplicate.issues.map((issue) => issue.code),
      contains('duplicate_id'),
    );

    final unknownStep = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        '                    - STEP-WORK-2\n                  policy:',
        '                    - STEP-NOT-DECLARED\n                  policy:',
      ),
    );
    expect(unknownStep.isValid, isFalse);
    expect(
      unknownStep.issues.map((issue) => issue.code),
      contains('broken_reference'),
    );
  });

  test('shared advisory scope cases enforce one attachment per step', () {
    final cases = const LineSplitter()
        .convert(
          File(
            'test/fixtures/authored_running_advisory_scope_cases.jsonl',
          ).readAsStringSync(),
        )
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>);

    for (final scopeCase in cases) {
      final result = const PlanPackageCompiler().compile(
        _scopeCaseYaml(scopeCase),
      );
      final expectedValid = scopeCase['expected_valid'] as bool;
      expect(
        result.isValid,
        expectedValid,
        reason: '${scopeCase['name']}: ${result.issues}',
      );
      if (!expectedValid) {
        expect(
          result.issues.map((issue) => issue.code),
          contains('overlapping_advisory_step_scope'),
          reason: scopeCase['name'] as String,
        );
      }
    }
  });

  test(
    'policy remains explicit and rejects deferred evidence or bad ranges',
    () {
      final external = const PlanPackageCompiler().compile(
        yaml.replaceFirst(
          'external_completed_tests_eligible: false',
          'external_completed_tests_eligible: true',
        ),
      );
      expect(external.isValid, isFalse);
      expect(
        external.issues.map((issue) => issue.code),
        contains('unsupported_evidence_source'),
      );

      final badRange = const PlanPackageCompiler().compile(
        yaml.replaceFirst(
          'maximum_speed_basis_points: 9345',
          'maximum_speed_basis_points: 8000',
        ),
      );
      expect(badRange.isValid, isFalse);
      expect(
        badRange.issues.map((issue) => issue.code),
        contains('invalid_percentage_range'),
      );
    },
  );
}

String _scopeCaseYaml(Map<String, dynamic> scopeCase) {
  final stepIds = (scopeCase['step_ids'] as List).cast<String>();
  final scopes = (scopeCase['attachment_scopes'] as List)
      .map((scope) => (scope as List).cast<String>())
      .toList(growable: false);
  final buffer = StringBuffer('''
package_schema_version: 2

programme:
  lineage_code: PROG-RUNNING-SCOPE-FIXTURE
  version_number: 1
  name: Running advisory scope fixture
  library_scope: coach_private
  owner_type: coach
  coaching_intent: Validate explicit advisory scope authority.
  duration_weeks: 1
  sessions_per_week: 1

sessions:
  - session_key: SES-RUN-SCOPE
    protocol_id: PROT-RUN-SCOPE-R1
    session_lineage_id: b4000000-0000-4000-8000-000000000001
    revision_number: 1
    title: Running scope fixture

phases: []

weeks:
  - week_number: 1
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        slots:
          - slot_key: W1D1S1
            session_order: 1
            session_key: SES-RUN-SCOPE
            progression:
              prescription_summary: Synthetic validator fixture only.
            authored_running_v1:
              schema_version: 1
              workout_id: RUN-SCOPE-FIXTURE
              step_ids:
''');
  for (final stepId in stepIds) {
    buffer.writeln('                - $stepId');
  }
  buffer.writeln('              advisory_attachments:');
  for (var index = 0; index < scopes.length; index++) {
    buffer
      ..writeln('                - attachment_id: TARGET-${index + 1}')
      ..writeln('                  step_ids:');
    for (final stepId in scopes[index]) {
      buffer.writeln('                    - $stepId');
    }
    buffer.write('''
                  policy:
                    policy_id: POLICY-${index + 1}
                    policy_version: 1
                    method_id: PERCENT-BENCHMARK-SPEED
                    method_version: 1
                    benchmark_eligibility:
                      cohort_completed_tests_eligible: true
                      manual_completed_tests_eligible: true
                      external_completed_tests_eligible: false
                    freshness_local_civil_days: 90
                    minimum_speed_basis_points: 8123
                    maximum_speed_basis_points: 9345
                    display_rounding:
                      increment_milliseconds_per_kilometre: 1000
                      direction: nearest
''');
  }
  buffer.write('''
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''');
  return buffer.toString();
}
