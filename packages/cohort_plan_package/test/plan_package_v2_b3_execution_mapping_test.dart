import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

void main() {
  final yaml = File(
    'test/fixtures/minimal_plan_package_v2_b3.yaml',
  ).readAsStringSync();

  test('canonical v2 package hashes exact step-to-block bindings', () {
    final result = const PlanPackageCompiler().compile(yaml);
    expect(result.isValid, isTrue, reason: result.issues.toString());

    final canonical = jsonDecode(result.canonicalJson!) as Map<String, Object?>;
    final running =
        ((((canonical['weeks']! as List).single as Map)['days'] as List).single
                as Map)['slots']
            as List;
    final authored = (running.single as Map)['authored_running_v1'] as Map;
    expect(
      authored['execution_mapping_sha256'],
      '4bad0e42edc21276153ce31e7c389a216a389870f5794834e930eea1b6ce36bb',
    );
    expect(
      (authored['executable_step_bindings'] as List).single,
      containsPair('session_block_id', '2d8f9c46-60dc-422b-8d0e-4d94028617ca'),
    );

    final changed = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        '2d8f9c46-60dc-422b-8d0e-4d94028617ca',
        '2d8f9c46-60dc-422b-8d0e-4d94028617cb',
      ),
    );
    expect(changed.isValid, isTrue, reason: changed.issues.toString());
    expect(changed.contentHashSha256, isNot(result.contentHashSha256));
    expect(changed.canonicalJson, isNot(result.canonicalJson));
  });

  test('mapping is ordered, complete, canonical-UUID scoped, and optional', () {
    final orderMismatch = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        'step_id: rw1:p:7e50ec7208a5dd0f:s:0',
        'step_id: STEP-OTHER',
      ),
    );
    expect(orderMismatch.isValid, isFalse);
    expect(
      orderMismatch.issues.map((issue) => issue.code),
      contains('execution_mapping_order_mismatch'),
    );

    final malformedBlock = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        '2d8f9c46-60dc-422b-8d0e-4d94028617ca',
        'BLOCK-BY-TITLE',
      ),
    );
    expect(malformedBlock.isValid, isFalse);
    expect(
      malformedBlock.issues.map((issue) => issue.code),
      contains('invalid_identifier'),
    );

    final unattached = const PlanPackageCompiler().compile(
      yaml.replaceFirst(
        '              executable_step_bindings:\n'
            '                - step_id: rw1:p:7e50ec7208a5dd0f:s:0\n'
            '                  session_block_id: 2d8f9c46-60dc-422b-8d0e-4d94028617ca\n',
        '',
      ),
    );
    expect(unattached.isValid, isTrue, reason: unattached.issues.toString());
    expect(
      unattached.canonicalJson,
      isNot(contains('execution_mapping_sha256')),
    );
  });
}
