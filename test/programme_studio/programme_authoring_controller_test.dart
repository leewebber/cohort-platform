import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/programme_studio/authoring/plan_package_v1_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compiler = PlanPackageCompiler();
  const writer = PlanPackageV1YamlWriter();
  final fixture = programmeAuthoringFixtures.first;
  late ProgrammeAuthoringController controller;
  setUp(() {
    controller = ProgrammeAuthoringController(fixture: fixture);
  });
  tearDown(() => controller.dispose());
  String yaml(Map<String, dynamic> tree) => writer.writeDraft(tree);

  test(
    'complete v1 golden including locked contracts keeps exact canonical identity',
    () {
      final source = File(
        'packages/cohort_plan_package/test/fixtures/minimal_plan_package.yaml',
      ).readAsStringSync();
      final before = compiler.compile(source);
      final export = writer.write(before.manifest!);
      final after = compiler.compile(export);
      expect(after.isValid, isTrue, reason: after.issues.toString());
      expect(after.canonicalJson, before.canonicalJson);
      expect(after.contentHashSha256, before.contentHashSha256);
      expect(writer.write(after.manifest!), export);
      expect(export, endsWith('\n'));
      expect(export, isNot(contains('\r')));
    },
  );

  test(
    'quoted multiline Unicode and YAML-looking strings preserve semantic bytes',
    () {
      final tree = controller.tree!;
      for (final value in [
        'false',
        '001',
        'null',
        'key: value # text',
        'line one\nline two',
        'é 🏃 "quoted" \\',
      ]) {
        tree['programme']['description'] = value;
        final before = compiler.compile(jsonEncode(tree));
        final export = writer.write(before.manifest!);
        final after = compiler.compile(export);
        expect(after.canonicalJson, before.canonicalJson, reason: value);
        expect(writer.write(after.manifest!), export);
      }
    },
  );

  test('writer refuses v2 rather than downgrade or strip running authority', () {
    final source = File(
      'packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.yaml',
    ).readAsStringSync();
    expect(
      () => writer.write(compiler.compile(source).manifest!),
      throwsFormatException,
    );
    expect(controller.loadSource(source), isFalse);
    expect(controller.issues.single.code, 'unsupported_d1_schema');
    expect(controller.currentReview, isNull);
  });

  test(
    'both synthetic bundles project exact bodies and round trip deterministically',
    () {
      for (final f in programmeAuthoringFixtures) {
        final c = ProgrammeAuthoringController(fixture: f);
        expect(c.validateAndReview(), isTrue, reason: c.issues.toString());
        final export = c.verifiedExport()!;
        final compiled = compiler.compile(f.source);
        expect(compiler.compile(export).canonicalJson, compiled.canonicalJson);
        expect(
          c.currentReview!.developerFixtures.single.compile.contentHashSha256,
          c.currentHash,
        );
        expect(
          c
              .currentReview!
              .developerFixtures
              .single
              .weeks
              .first
              .days
              .first
              .sessions
              .first
              .bodiesResolved,
          isTrue,
        );
        expect(c.loadSource(export), isTrue);
        expect(c.currentReview, isNull);
        expect(c.validateAndReview(), isTrue);
        expect(c.verifiedExport(), export);
        c.dispose();
      }
    },
  );

  test(
    'equivalent key/default formatting yields identical normalized export',
    () {
      expect(controller.validateAndReview(), isTrue);
      final exported = controller.verifiedExport();
      final tree = controller.tree!;
      final slot = tree['weeks'][0]['days'][0]['slots'][0] as Map;
      slot.remove('time_of_day');
      slot.remove('is_optional');
      final reversed = Map<String, dynamic>.fromEntries(
        tree.entries.toList().reversed,
      );
      expect(controller.loadSource(jsonEncode(reversed)), isTrue);
      expect(controller.validateAndReview(), isTrue);
      expect(controller.verifiedExport(), exported);
    },
  );

  test(
    'edits synchronously invalidate hash export and review, invalid input cannot revive them',
    () {
      expect(controller.validateAndReview(), isTrue);
      final oldHash = controller.currentHash;
      controller.editProgramme('name', '');
      expect(controller.currentHash, isNull);
      expect(controller.exportYaml, isNull);
      expect(controller.currentReview, isNull);
      expect(controller.verifiedExport(), isNull);
      expect(controller.validateAndReview(), isFalse);
      expect(controller.issues, isNotEmpty);
      controller.editProgramme('name', 'Synthetic revised name');
      expect(controller.currentHash, isNull);
      expect(controller.validateAndReview(), isTrue);
      expect(controller.currentHash, isNot(oldHash));
      expect(controller.meaningChanged, isTrue);
    },
  );

  test(
    'source diff uses original imported bytes; reset cancels meaning edits',
    () {
      expect(controller.originalSource, fixture.source);
      expect(
        controller.sourceDiff.any((line) => line.contains('# Synthetic')),
        isTrue,
      );
      expect(controller.validateAndReview(), isTrue);
      expect(controller.meaningChanged, isFalse);
      controller.editProgramme('description', 'Changed description');
      controller.editWeek(0, 'coach_note', 'Changed week');
      controller.editDay(0, 0, 'title', 'Changed day');
      controller.reset();
      expect(controller.originalSource, fixture.source);
      expect(controller.validateAndReview(), isTrue);
      expect(controller.meaningChanged, isFalse);
    },
  );

  test(
    'exact revision selection changes only selected key, never progression or contracts',
    () {
      final before = controller.tree!;
      controller.editSlot(0, 0, 0, 'session_key', 'SYN-SESSION-R2');
      expect(
        controller.validateAndReview(),
        isTrue,
        reason: controller.issues.toString(),
      );
      final after = controller.tree!;
      expect(
        after['weeks'][0]['days'][0]['slots'][0]['progression'],
        before['weeks'][0]['days'][0]['slots'][0]['progression'],
      );
      for (final field in [
        'sessions',
        'phases',
        'adaptation_permissions',
        'protected_invariants',
        'assessments',
        'performance_evidence_requirements',
        'comparison_identities',
      ]) {
        expect(after[field], before[field], reason: field);
      }
      expect(
        controller
            .currentReview!
            .developerFixtures
            .single
            .weeks
            .first
            .days
            .first
            .sessions
            .first
            .revisionNumber,
        2,
      );
      controller.editSlot(0, 0, 0, 'session_key', 'UNKNOWN');
      expect(controller.validateAndReview(), isFalse);
      expect(controller.currentReview, isNull);
    },
  );

  test(
    'slot reorder/move/add/remove preserves identities and rejects orphaned refs',
    () {
      final progression =
          controller.tree!['weeks'][0]['days'][0]['slots'][1]['progression'];
      controller.moveSlot(0, 0, 1, 0, 0, 0);
      expect(
        controller.tree!['weeks'][0]['days'][0]['slots'][0]['slot_key'],
        'W1D1S2',
      );
      controller.setDayType(0, 1, 'training');
      controller.moveSlot(0, 0, 0, 0, 1, 0);
      expect(
        controller.validateAndReview(),
        isTrue,
        reason: controller.issues.toString(),
      );
      expect(
        controller.tree!['weeks'][0]['days'][1]['slots'][0]['progression'],
        progression,
      );
      controller.addSlot(0, 0, 'SYN-NEW', 'SYN-SESSION-R2');
      expect(controller.validateAndReview(), isTrue);
      controller.removeSlot(0, 0, 1);
      expect(controller.validateAndReview(), isTrue);
      controller.removeSlot(0, 0, 0); // The adaptation still targets W1D1S1.
      expect(controller.validateAndReview(), isFalse);
      expect(
        controller.issues.any((i) => i.code == 'broken_reference'),
        isTrue,
      );
    },
  );

  test(
    'invalid day transition and duplicate key fail closed without silent repair',
    () {
      controller.setDayType(0, 0, 'rest');
      expect(controller.validateAndReview(), isFalse);
      controller.reset();
      controller.addSlot(0, 0, 'W1D1S1', 'SYN-SESSION-R1');
      expect(controller.validateAndReview(), isFalse);
      expect(controller.issues.any((i) => i.code == 'duplicate_id'), isTrue);
      controller.reset();
      controller.editProgramme('sessions_per_week', 'not an integer');
      expect(controller.validateAndReview(), isFalse);
    },
  );

  test(
    'malformed and unsupported sources clear previous successful review',
    () {
      for (final source in [
        'programme: [',
        '${fixture.source}\nunknown: true\n',
        '${fixture.source}\nathlete_result: 10\n',
      ]) {
        controller.reset();
        controller.validateAndReview();
        expect(controller.loadSource(source), isFalse);
        expect(controller.currentHash, isNull);
        expect(controller.currentReview, isNull);
        expect(controller.tree, isNull);
        expect(controller.issues, isNotEmpty);
      }
    },
  );

  test(
    'valid but foreign identity, locked contracts and progression edits are refused',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (t) => t['programme']['lineage_code'] = 'REAL-OTHER',
        (t) => t['sessions'][0]['revision_number'] = 9,
        (t) => t['phases'][0]['coach_note'] = 'Unauthorized phase change',
        (t) =>
            t['adaptation_permissions'][0]['scope_note'] = 'Changed contract',
        (t) =>
            t['weeks'][0]['days'][0]['slots'][0]['progression']['volume_note'] =
                'Changed dose',
      ]) {
        controller.reset();
        final tree = controller.tree!;
        mutate(tree);
        expect(controller.loadSource(yaml(tree)), isFalse);
        expect(
          controller.issues.any(
            (i) =>
                i.code == 'locked_source_changed' ||
                i.code == 'locked_slot_changed',
          ),
          isTrue,
        );
      }
    },
  );

  test('untrusted caller cannot mutate exposed controller tree', () {
    final exposed = controller.tree!;
    exposed['programme']['lineage_code'] = 'OTHER';
    expect(controller.validateAndReview(), isTrue);
    expect(controller.tree!['programme']['lineage_code'], 'SYN-D1-CONTRACTS');
    controller.editProgramme('lineage_code', 'OTHER');
    expect(controller.issues.single.code, 'unsupported_edit');
    expect(controller.currentReview, isNull);
  });

  test(
    'fixture source must independently match exact lineage/revision/unpublished state',
    () {
      for (final sql in [
        fixture.protocolSql.replaceFirst(
          "'SYN-SESSION-LINEAGE',1",
          "'SYN-SESSION-LINEAGE',9",
        ),
        fixture.protocolSql.replaceFirst(
          "'SYN-SESSION-LINEAGE',1",
          "'OTHER-LINEAGE',1",
        ),
        fixture.protocolSql.replaceFirst(
          "'Fixture','false'",
          "'Fixture','true'",
        ),
        '',
      ]) {
        final c = ProgrammeAuthoringController(
          fixture: ProgrammeAuthoringFixture(
            id: fixture.id,
            label: fixture.label,
            source: fixture.source,
            protocolSql: sql,
          ),
        );
        expect(c.validateAndReview(), isFalse);
        expect(c.issues, isNotEmpty);
        expect(c.exportYaml, isNull);
        c.dispose();
      }
    },
  );

  test(
    'missing or unsupported protocol body does not receive successful export',
    () {
      for (final sql in [
        fixture.protocolSql.split('INSERT INTO public.session_blocks').first,
        fixture.protocolSql.replaceAll("'none'", "'unknown_format'"),
      ]) {
        final c = ProgrammeAuthoringController(
          fixture: ProgrammeAuthoringFixture(
            id: fixture.id,
            label: fixture.label,
            source: fixture.source,
            protocolSql: sql,
          ),
        );
        expect(c.validateAndReview(), isFalse);
        expect(
          c.issues.any((i) => i.code == 'fixture_body_unresolved'),
          isTrue,
        );
        c.dispose();
      }
    },
  );
}
