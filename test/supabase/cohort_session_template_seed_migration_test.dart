import 'dart:io';

import 'package:cohort_platform/features/training_library/services/cohort_session_template_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Case A deployment contract:
/// `20260730150000` has not been applied remotely, so the hardened original
/// migration is retained and no additive corrective migration is required.
void main() {
  final migrationFile = File(
    'supabase/migrations/20260730150000_seed_cohort_session_templates.sql',
  );
  final migrationsDir = Directory('supabase/migrations');

  late String sql;
  late List<File> migrationFiles;

  setUpAll(() {
    sql = migrationFile.readAsStringSync();
    migrationFiles =
        migrationsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
  });

  const expectedStepCounts = {
    'TMP-001': 6,
    'TMP-002': 6,
    'TMP-003': 6,
    'TMP-004': 3,
    'TMP-005': 3,
    'TMP-006': 4,
    'TMP-007': 6,
    'TMP-008': 6,
    'TMP-009': 5,
    'TMP-010': 3,
  };

  group('cohort session template seed migration (Case A)', () {
    test('migration file exists', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('no additive corrective migration is present for Case A', () {
      final corrective = migrationFiles.where((f) {
        final name = f.uri.pathSegments.last;
        return name.compareTo(
                  '20260730150000_seed_cohort_session_templates.sql',
                ) >
                0 &&
            name.contains('cohort_session_template');
      }).toList();

      expect(
        corrective,
        isEmpty,
        reason:
            'Case A: 20260730150000 has not been applied remotely, so a later '
            'corrective template seed migration must not exist.',
      );
    });

    test('fails closed on wrong-classification TMP collisions', () {
      expect(sql, contains('Canonical template seed conflict'));
      expect(sql, contains("endorsement_status = 'cohort_endorsed'"));
      expect(sql, contains('owner_id IS NULL'));
      expect(sql, contains('RAISE EXCEPTION'));
      expect(sql, isNot(contains('ON CONFLICT (protocol_id) DO UPDATE')));
      expect(sql, contains('ON CONFLICT (protocol_id) DO NOTHING'));
    });

    test('preflight rejects non-canonical occupying TMP ids', () {
      expect(sql, contains('FOR bad IN'));
      expect(sql, contains("content_kind = 'session_template'"));
      expect(sql, contains("authoring_scope = 'cohort_global'"));
      expect(sql, contains("endorsement_status = 'cohort_endorsed'"));
      expect(sql, contains("published = 'true'"));
      expect(sql, contains('owner_id IS NULL'));
      expect(sql, contains('Refusing to treat it as TMP catalogue content'));
    });

    test('models live text published column — never boolean predicates', () {
      expect(sql, isNot(contains('published IS TRUE')));
      expect(sql, isNot(contains('published IS FALSE')));
      expect(sql, isNot(contains('published::boolean')));
      expect(sql, isNot(contains('::boolean')));
      // Canonical inserts store exact text 'true', not boolean TRUE.
      expect(
        RegExp(
          r"'TMP-\d{3}', '[^']+', '[^']*', 'true', 'session_template'",
        ).allMatches(sql).length,
        10,
      );
      expect(
        RegExp(
          r"'TMP-\d{3}', '[^']+', '[^']*', TRUE, 'session_template'",
        ).allMatches(sql),
        isEmpty,
      );
      // Legacy representations must not be accepted as published.
      expect(sql, isNot(contains("published = 'No'")));
      expect(sql, isNot(contains("published = 'false'")));
      expect(sql, isNot(contains("published ILIKE")));
      expect(sql, isNot(contains('published IN (')));
    });

    test('validates expected step counts after seed for all ten templates', () {
      for (final entry in expectedStepCounts.entries) {
        expect(sql, contains('"${entry.key}": ${entry.value}'));
      }
      expect(sql, contains('expected % steps but found'));
      expect(
        sql,
        contains('Refusing to treat a partial or corrupt step set as deployed'),
      );
    });

    test('keeps TMP-007 suitcase carry distance parity with catalogue', () {
      expect(sql, contains('"distance": "20-30 m/side"'));
      final carry = CohortSessionTemplateCatalogue
          .minimalEquipmentStrength
          .steps
          .firstWhere((s) => s.title == 'Suitcase carry');
      expect(carry.distance, '20-30 m/side');
    });

    test('app catalogue and SQL share stable IDs, titles, and step counts', () {
      final catalogue = CohortSessionTemplateCatalogue.all();
      expect(catalogue, hasLength(10));

      for (final draft in catalogue) {
        expect(sql, contains("'${draft.protocolId}'"));
        expect(sql, contains("'${draft.name}'"));
        expect(sql, contains("'${draft.purpose!.replaceAll("'", "''")}'"));
        expect(
          draft.steps.length,
          expectedStepCounts[draft.protocolId],
          reason: '${draft.protocolId} catalogue step count drift',
        );
        expect(sql, contains("'${draft.protocolId}', '${draft.name}'"));
      }

      for (final id in expectedStepCounts.keys) {
        expect(
          catalogue.any((d) => d.protocolId == id),
          isTrue,
          reason: '$id missing from app catalogue',
        );
      }
    });

    test('seeded headers use full official classification fields', () {
      final headerInserts = RegExp(
        r"'TMP-\d{3}'[\s\S]*?'session_template', 'cohort_global', 'cohort_endorsed'",
      ).allMatches(sql);
      expect(headerInserts.length, 10);

      // Each VALUES header places NULL owner immediately after endorsement.
      final ownerNullPattern = RegExp(
        r"'session_template', 'cohort_global', 'cohort_endorsed',\s*\n\s*NULL,",
      );
      expect(ownerNullPattern.allMatches(sql).length, 10);

      // Published is exact text 'true' for every canonical header.
      final publishedPattern = RegExp(
        r"'TMP-\d{3}', '[^']+', '[^']*', 'true', 'session_template'",
      );
      expect(publishedPattern.allMatches(sql).length, 10);
    });

    test('SQL step inserts require full official classification', () {
      expect(
        sql.contains(
          "AND p.endorsement_status = 'cohort_endorsed'\n"
          "    AND p.published = 'true'\n"
          '    AND p.owner_id IS NULL',
        ),
        isTrue,
      );
      // One gated step insert block per template.
      expect(
        RegExp(
          r"AND p.endorsement_status = 'cohort_endorsed'",
        ).allMatches(sql).length,
        greaterThanOrEqualTo(10),
      );
      expect(
        RegExp(r"AND p\.published = 'true'").allMatches(sql).length,
        greaterThanOrEqualTo(10),
      );
    });

    test('postflight requires all ten official headers after inserts', () {
      expect(
        sql,
        contains(
          'Canonical template seed incomplete: official header for % is missing',
        ),
      );
      for (final id in expectedStepCounts.keys) {
        expect(sql, contains("'$id'"));
      }
    });

    test('does not silently overwrite existing rows', () {
      expect(sql.toUpperCase(), isNot(contains('DO UPDATE')));
      expect(
        sql.toUpperCase(),
        isNot(contains('DELETE FROM PERFORMANCE_PROTOCOLS')),
      );
      expect(sql.toUpperCase(), isNot(contains('DELETE FROM PROTOCOL_STEPS')));
      expect(sql.toUpperCase(), isNot(contains('TRUNCATE')));
    });
  });
}
