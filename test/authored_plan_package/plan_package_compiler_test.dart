import 'dart:io';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String fixtureYaml;
  const compiler = PlanPackageCompiler();

  setUpAll(() {
    fixtureYaml = File(
      'test/fixtures/authored_plan_package/minimal_plan_package.yaml',
    ).readAsStringSync();
  });

  group('parsing and validation', () {
    test('valid fixture parses and compiles successfully', () {
      final result = compiler.compile(fixtureYaml);
      expect(result.isValid, isTrue, reason: result.issues.toString());
      expect(result.manifest, isNotNull);
      expect(result.contentHashSha256, isNotNull);
      expect(result.contentHashSha256!.length, 64);
      expect(result.manifest!.programme.lineageCode, 'PROG-FIXTURE-01');
      expect(result.manifest!.programme.versionNumber, 1);
      expect(result.manifest!.sessions, hasLength(1));
      expect(result.manifest!.weeks, hasLength(2));
      expect(result.manifest!.adaptationPermissions, hasLength(1));
      expect(result.manifest!.protectedInvariants, hasLength(1));
      expect(result.manifest!.assessments, hasLength(1));
      expect(result.manifest!.comparisonIdentities, hasLength(1));
    });

    test('malformed YAML fails', () {
      final result = compiler.compile('programme: [\n  - broken');
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.code == 'malformed_yaml'), isTrue);
    });

    test('missing required data fails', () {
      final result = compiler.compile('''
package_schema_version: 1
sessions: []
weeks: []
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''');
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.code == 'missing_field'), isTrue);
    });

    test('unknown or misspelled coaching fields fail', () {
      final yaml = fixtureYaml.replaceFirst(
        'coaching_intent:',
        'coaching_intnet:',
      );
      final result = compiler.compile(yaml);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.code == 'unknown_field'), isTrue);
    });

    test('unsupported schema versions fail', () {
      final yaml = fixtureYaml.replaceFirst(
        'package_schema_version: 1',
        'package_schema_version: 99',
      );
      final result = compiler.compile(yaml);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.code == 'unsupported_schema_version'),
        isTrue,
      );
    });

    test('duplicate IDs fail', () {
      final result = compiler.compile('''
package_schema_version: 1
programme:
  lineage_code: PROG-X
  version_number: 1
  name: X
  library_scope: coach_private
  owner_type: coach
  coaching_intent: Intent
  duration_weeks: 1
sessions:
  - session_key: SES-A
    protocol_id: PROT-A
    session_lineage_id: SL-A
    revision_number: 1
    title: A
  - session_key: SES-A
    protocol_id: PROT-B
    session_lineage_id: SL-B
    revision_number: 1
    title: B
weeks:
  - week_number: 1
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        slots:
          - slot_key: S1
            session_order: 1
            session_key: SES-A
            progression:
              prescription_summary: 3x5
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''');
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.code == 'duplicate_id'), isTrue);
    });

    test('broken references fail', () {
      final yaml = fixtureYaml.replaceFirst(
        'session_key: SES-SQUAT-A\n            completion_expectation',
        'session_key: SES-MISSING\n            completion_expectation',
      );
      final result = compiler.compile(yaml);
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.code == 'broken_reference'), isTrue);
    });

    test('invalid protected/adaptable combinations fail', () {
      final yaml = fixtureYaml.replaceFirst(
        'kind: assessment_immutable\n    target_ref: ASM-SQUAT-BASELINE',
        'kind: session_slot_immutable\n    target_ref: W1D1S1',
      );
      final result = compiler.compile(yaml);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.code == 'protected_adaptable_conflict'),
        isTrue,
        reason: result.issues.toString(),
      );
    });

    test(
      'structurally incomplete authored content fails rather than generating',
      () {
        final result = compiler.compile('''
package_schema_version: 1
programme:
  lineage_code: PROG-X
  version_number: 1
  name: X
  library_scope: coach_private
  owner_type: coach
  coaching_intent: Intent
  duration_weeks: 1
sessions:
  - session_key: SES-A
    protocol_id: PROT-A
    session_lineage_id: SL-A
    revision_number: 1
    title: A
weeks:
  - week_number: 1
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        slots: []
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''');
        expect(result.isValid, isFalse);
        expect(
          result.issues.any((i) => i.code == 'incomplete_structure'),
          isTrue,
        );
      },
    );

    test('forbidden execution evidence fields fail', () {
      final yaml = fixtureYaml.replaceFirst(
        'primary_goal: strength',
        'primary_goal: strength\n  previous_performance: 100kg',
      );
      final result = compiler.compile(yaml);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.code == 'execution_evidence_forbidden'),
        isTrue,
      );
    });
  });

  group('determinism and canonicalisation', () {
    test('compiling identical input twice produces identical hash', () {
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(fixtureYaml);
      expect(a.isValid, isTrue);
      expect(a.contentHashSha256, b.contentHashSha256);
      expect(a.canonicalJson, b.canonicalJson);
    });

    test('formatting-only changes produce the same hash', () {
      final spaced = fixtureYaml.replaceAll('\n', '\n\n');
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(spaced);
      expect(a.isValid && b.isValid, isTrue, reason: '${a.issues} ${b.issues}');
      expect(a.contentHashSha256, b.contentHashSha256);
    });

    test('comments produce the same hash', () {
      final withComments = '# header comment\n$fixtureYaml\n# trailer\n';
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(withComments);
      expect(b.isValid, isTrue, reason: b.issues.toString());
      expect(a.contentHashSha256, b.contentHashSha256);
    });

    test('mapping-key reordering produces the same hash', () {
      final reordered = '''
package_schema_version: 1
comparison_identities:
  - label: Squat A 3x5 like-for-like
    id: CMP-SQUAT-3X5
    session_lineage_id: SL-SQUAT-A
performance_evidence_requirements:
  - required: true
    id: EVD-SQUAT-LOAD
    metric: load_kg
    comparison_identity_id: CMP-SQUAT-3X5
assessments:
  - comparison_identity_id: CMP-SQUAT-3X5
    id: ASM-SQUAT-BASELINE
    slot_ref: W2D1S1
    evidence_requirement: recorded_load_and_reps
    label: Squat A baseline assessment
protected_invariants:
  - description: Assessment session must not be adapted.
    id: INV-ASSESSMENT-IMMUTABLE
    kind: assessment_immutable
    target_ref: ASM-SQUAT-BASELINE
adaptation_permissions:
  - athlete_agreement_required: true
    id: ADP-REDUCE-VOLUME-W1
    change_kind: reduce_volume
    target_ref: W1D1S1
    scope_note: Volume reduction only on foundation slot.
sessions:
  - title: Squat A
    session_key: SES-SQUAT-A
    protocol_id: PROT-SQUAT-A-R1
    session_lineage_id: SL-SQUAT-A
    revision_number: 1
phases: []
weeks:
  - week_number: 1
    title: Foundation
    intent: build
    coach_note: Establish baseline volume.
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        intent: build
        slots:
          - slot_key: W1D1S1
            session_order: 1
            session_key: SES-SQUAT-A
            completion_expectation: required
            progression:
              prescription_summary: 3x5 @ RPE 7
              volume_note: Accumulate quality sets
              intensity_note: Submaximal
      - day_key: day_2
        day_order: 2
        day_type: rest
  - week_number: 2
    title: Progression and assessment
    intent: test
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        intent: test
        slots:
          - slot_key: W2D1S1
            session_order: 1
            session_key: SES-SQUAT-A
            completion_expectation: required
            progression:
              prescription_summary: 3x5 @ RPE 8 assessment
              volume_note: Same set structure as week 1
              intensity_note: Authored intensity step; not athlete-history driven
      - day_key: day_2
        day_order: 2
        day_type: rest
programme:
  name: Fixture Strength Base
  lineage_code: PROG-FIXTURE-01
  version_number: 1
  description: Minimal authored package for compiler foundation tests.
  library_scope: cohort_global
  owner_type: global
  coaching_intent: Establish squat pattern under controlled authored volume.
  duration_weeks: 2
  sessions_per_week: 1
  primary_goal: strength
''';
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(reordered);
      expect(b.isValid, isTrue, reason: b.issues.toString());
      expect(a.contentHashSha256, b.contentHashSha256);
    });

    test('line-ending differences produce the same hash', () {
      final crlf = fixtureYaml.replaceAll('\n', '\r\n');
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(crlf);
      expect(b.isValid, isTrue, reason: b.issues.toString());
      expect(a.contentHashSha256, b.contentHashSha256);
    });

    test('meaningful coaching change produces a different hash', () {
      final changed = fixtureYaml.replaceFirst(
        'Establish squat pattern under controlled authored volume.',
        'Different authored coaching intent.',
      );
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(changed);
      expect(b.isValid, isTrue);
      expect(a.contentHashSha256, isNot(b.contentHashSha256));
    });

    test('session-version change produces a different hash', () {
      final changed = fixtureYaml.replaceFirst(
        'revision_number: 1',
        'revision_number: 2',
      );
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(changed);
      expect(b.isValid, isTrue);
      expect(a.contentHashSha256, isNot(b.contentHashSha256));
    });

    test('schedule-order change produces a different hash', () {
      // Swap week titles alone wouldn't change order keys; change week 1/2
      // progression summaries swap to prove order of weeks in canonical form
      // matters via week_number sorting — swap week numbers with content.
      final swapped = fixtureYaml
          .replaceFirst('week_number: 1', 'week_number: 9')
          .replaceFirst('week_number: 2', 'week_number: 1')
          .replaceFirst('week_number: 9', 'week_number: 2')
          .replaceFirst('duration_weeks: 2', 'duration_weeks: 2');
      final a = compiler.compile(fixtureYaml);
      final b = compiler.compile(swapped);
      expect(b.isValid, isTrue, reason: b.issues.toString());
      expect(a.contentHashSha256, isNot(b.contentHashSha256));
    });

    test('transient source details do not enter canonical representation', () {
      final result = compiler.compile(fixtureYaml);
      expect(result.isValid, isTrue);
      final json = result.canonicalJson!;
      expect(json.contains('file://'), isFalse);
      expect(json.contains('created_at'), isFalse);
      expect(json.contains('imported_at'), isFalse);
      expect(json.contains('localId'), isFalse);
      expect(json.contains('previous_performance'), isFalse);
      expect(json.contains('builder'), isFalse);
    });
  });
}
