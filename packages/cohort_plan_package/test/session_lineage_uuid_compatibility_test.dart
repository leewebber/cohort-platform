import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

void main() {
  late String fixture;

  setUpAll(() {
    fixture = File(
      'test/fixtures/minimal_plan_package.yaml',
    ).readAsStringSync();
  });

  String withSessionLineage(String value) {
    return fixture.replaceAll(
      'session_lineage_id: SL-SQUAT-A',
      'session_lineage_id: $value',
    );
  }

  PlanPackageCompileResult compileLineage(String value) {
    return const PlanPackageCompiler().compile(withSessionLineage(value));
  }

  test('existing symbolic session lineage remains valid', () {
    final result = compileLineage('SL-SQUAT-A');

    expect(result.isValid, isTrue, reason: result.issues.toString());
    expect(result.manifest!.sessions.single.sessionLineageId, 'SL-SQUAT-A');
  });

  test('canonical lowercase UUID accepts every hexadecimal leading digit', () {
    for (final prefix in '0123456789abcdef'.split('')) {
      final value =
          '$prefix'
          '1111111-1111-1111-1111-111111111111';
      final result = compileLineage(value);

      expect(result.isValid, isTrue, reason: '$value: ${result.issues}');
      expect(result.manifest!.sessions.single.sessionLineageId, value);
    }
  });

  test(
    'real hosted leading shapes compile without embedding hosted identities',
    () {
      for (final prefix in const ['0d', '3e', '5f', '0e', '2c']) {
        final value = '${prefix}aaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        final result = compileLineage(value);

        expect(result.isValid, isTrue, reason: '$value: ${result.issues}');
      }
    },
  );

  test('exact UUID is preserved in manifest canonical JSON and hash', () {
    const value = '0dce1a80-bc64-4727-8442-a555dc21b0ed';
    final first = compileLineage(value);
    final second = compileLineage(value);

    expect(first.isValid, isTrue, reason: first.issues.toString());
    expect(first.manifest!.sessions.single.sessionLineageId, value);
    expect(first.manifest!.comparisonIdentities.single.sessionLineageId, value);
    final canonical = jsonDecode(first.canonicalJson!) as Map<String, dynamic>;
    final sessions = canonical['sessions'] as List<dynamic>;
    expect(
      (sessions.single as Map<String, dynamic>)['session_lineage_id'],
      value,
    );
    expect(second.canonicalJson, first.canonicalJson);
    expect(second.contentHashSha256, first.contentHashSha256);
  });

  group('non-canonical UUID representations fail closed', () {
    for (final invalid in const [
      '0DCE1A80-BC64-4727-8442-A555DC21B0ED',
      "'{0dce1a80-bc64-4727-8442-a555dc21b0ed}'",
      '0dce1a80bc6447278442a555dc21b0ed',
      '0dce1a80-bc64-4727-8442-a555dc21b0e',
      "' 0dce1a80-bc64-4727-8442-a555dc21b0ed'",
      "'0dce1a80-bc64-4727-8442-a555dc21b0ed '",
      '1-not-a-uuid',
    ]) {
      test(invalid, () {
        final result = compileLineage(invalid);

        expect(result.isValid, isFalse);
        expect(
          result.issues.map((issue) => issue.code),
          contains('invalid_identifier'),
        );
      });
    }
  });

  test(
    'package-local session and slot keys retain existing identity rules',
    () {
      final invalidSessionKey = fixture.replaceFirst(
        'session_key: SES-SQUAT-A',
        'session_key: 01111111-1111-1111-1111-111111111111',
      );
      final invalidSlotKey = fixture.replaceFirst(
        'slot_key: W1D1S1',
        'slot_key: 01111111-1111-1111-1111-111111111111',
      );

      for (final source in [invalidSessionKey, invalidSlotKey]) {
        final result = const PlanPackageCompiler().compile(source);
        expect(result.isValid, isFalse);
        expect(
          result.issues.map((issue) => issue.code),
          contains('invalid_identifier'),
        );
      }
    },
  );

  test('unrelated identity fields do not gain UUID acceptance', () {
    final source = fixture.replaceFirst(
      'id: CMP-SQUAT-3X5',
      'id: 01111111-1111-1111-1111-111111111111',
    );
    final result = const PlanPackageCompiler().compile(source);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      contains('invalid_identifier'),
    );
  });
}
