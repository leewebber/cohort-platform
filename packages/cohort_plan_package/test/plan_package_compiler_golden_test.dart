import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

void main() {
  late String yaml;
  late String canonicalGolden;
  late String hashGolden;

  setUpAll(() {
    yaml = File('test/fixtures/minimal_plan_package.yaml').readAsStringSync();
    canonicalGolden = File(
      'test/fixtures/minimal_plan_package.canonical.json',
    ).readAsStringSync();
    hashGolden = File(
      'test/fixtures/minimal_plan_package.sha256',
    ).readAsStringSync().trim();
  });

  test('accepted canonical JSON and SHA-256 remain byte-identical', () {
    final result = const PlanPackageCompiler().compile(yaml);

    expect(result.isValid, isTrue, reason: result.issues.toString());
    expect(result.canonicalJson, canonicalGolden);
    expect(result.contentHashSha256, hashGolden);
    expect(result.contentHashSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('typed manifest preserves complete authored contract and order', () {
    final manifest = const PlanPackageCompiler().compile(yaml).manifest!;

    expect(manifest.programme.lineageCode, 'PROG-FIXTURE-01');
    expect(manifest.programme.versionNumber, 1);
    expect(manifest.sessions.single.protocolId, 'PROT-SQUAT-A-R1');
    expect(manifest.sessions.single.sessionLineageId, 'SL-SQUAT-A');
    expect(manifest.sessions.single.revisionNumber, 1);
    expect(manifest.weeks.map((week) => week.weekNumber), [1, 2]);
    expect(manifest.weeks.first.days.map((day) => day.dayOrder), [1, 2]);
    expect(manifest.weeks.first.days.first.slots.single.slotKey, 'W1D1S1');
    expect(
      manifest.adaptationPermissions.single.athleteAgreementRequired,
      true,
    );
    expect(manifest.protectedInvariants.single.id, 'INV-ASSESSMENT-IMMUTABLE');
    expect(manifest.assessments.single.id, 'ASM-SQUAT-BASELINE');
    expect(
      manifest.performanceEvidenceRequirements.single.id,
      'EVD-SQUAT-LOAD',
    );
    expect(manifest.comparisonIdentities.single.id, 'CMP-SQUAT-3X5');
  });

  test('malformed YAML preserves structured issue contract', () {
    final result = const PlanPackageCompiler().compile(
      'programme: [\n  - broken',
    );

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => (issue.path, issue.code)).toList(),
      contains((r'$', 'malformed_yaml')),
    );
  });

  test('semantic validation preserves structured issue contract', () {
    final invalid = yaml.replaceFirst(
      'athlete_agreement_required: true',
      'athlete_agreement_required: false',
    );
    final result = const PlanPackageCompiler().compile(invalid);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      contains('agreement_required'),
    );
  });

  test('formatting-only input changes preserve canonical output', () {
    final original = const PlanPackageCompiler().compile(yaml);
    final reformatted = const PlanPackageCompiler().compile(
      '# accepted package\n${yaml.replaceAll('\n', '\n\n')}',
    );

    expect(reformatted.isValid, isTrue);
    expect(reformatted.canonicalJson, original.canonicalJson);
    expect(reformatted.contentHashSha256, original.contentHashSha256);
  });
}
