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
