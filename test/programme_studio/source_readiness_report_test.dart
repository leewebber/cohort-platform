import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/projection/source_readiness_report.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'protocol_authoring_isolation_test.dart' as traversal;

void main() {
  Map<String, Object?> report({String Function(String)? read}) =>
      sourceReadinessReport(
        catalogId: 'apollo-build-v2',
        readAsset: read ?? (path) => File(path).readAsStringSync(),
      );
  late Map<String, Object?> apollo;
  setUpAll(() => apollo = report());
  Map<String, dynamic> section(Map<String, Object?> r, String key) =>
      (r[key]! as Map).cast<String, dynamic>();

  test(
    'planned HYROX Base does not borrow another source or pass empty checks',
    () {
      final r = sourceReadinessReport(
        catalogId: 'hyrox-base',
        readAsset: (_) =>
            throw StateError('No unrelated source should be read.'),
      );
      expect(section(r, 'candidate_source'), {
        'status': 'absent',
        'file_sha256': <String, String>{},
        'planned_duration_weeks': 8,
      });
      expect(
        section(r, 'content_authority')['status'],
        'missing_source_and_approval',
      );
      for (final key in [
        'canonical_package',
        'exercise_bindings',
        'unsupported_prescriptions',
        'readable_review',
      ]) {
        expect(section(r, key)['status'], 'not_assessed', reason: key);
      }
      expect(section(r, 'canonical_publication')['status'], 'not_established');
    },
  );
  test(
    'unknown IDs, titles, fixture and pilot paths cannot become candidates',
    () {
      for (final id in [
        'HYROX Base',
        'missing',
        'b3-device-validation-v1',
        'studio.local.apollo.w4.sat',
        '../apollo.json',
      ]) {
        expect(
          () => sourceReadinessReport(catalogId: id, readAsset: (_) => ''),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'existing compiler hash and publication evidence never establish approval',
    () {
      expect(section(apollo, 'canonical_package')['status'], 'compiled');
      expect(
        section(apollo, 'canonical_package')['compile']['content_hash_sha256'],
        '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
      );
      expect(section(apollo, 'content_authority')['status'], 'not_verified');
      expect(
        section(apollo, 'canonical_publication')['status'],
        'not_established',
      );
      expect(
        apollo['report_authority'],
        'derived_read_only_not_content_approval',
      );
    },
  );
  test(
    'exact source hashes are independent from package identity and deterministic',
    () {
      const path = 'tool/programmes/apollo_build_12_week_v1.plan-package.yaml';
      final text = File(path).readAsStringSync();
      expect(
        section(apollo, 'candidate_source')['file_sha256'][path],
        sha256.convert(utf8.encode(text)).toString(),
      );
      expect(jsonEncode(report()), jsonEncode(apollo));
      expect(File(path).readAsStringSync(), text);
    },
  );
  test(
    'existing EX references never manufacture authoritative definition versions',
    () {
      final bindings = section(apollo, 'exercise_bindings');
      expect(bindings['status'], 'unresolved');
      final issues = bindings['issues'] as List;
      expect(issues, isNotEmpty);
      expect(
        issues.every(
          (i) => i['issue'] == 'canonical_definition_version_not_supplied',
        ),
        isTrue,
      );
      expect(issues.first, containsPair('slot_key', isNotNull));
    },
  );
  test('malformed canonical references are separate from missing versions', () {
    final r = report(
      read: (p) =>
          File(p).readAsStringSync().replaceAll("'EX-079'", "'not-canonical'"),
    );
    expect(
      (section(r, 'exercise_bindings')['issues'] as List).any(
        (i) =>
            i['exercise_reference'] == 'not-canonical' &&
            i['issue'] == 'missing_or_malformed_canonical_reference',
      ),
      isTrue,
    );
  });
  test(
    'unsupported prescriptions and incomplete review stay separate from identity',
    () {
      expect(
        section(apollo, 'unsupported_prescriptions')['status'],
        'detected',
      );
      expect(
        section(apollo, 'unsupported_prescriptions')['findings'],
        isNotEmpty,
      );
      expect(section(apollo, 'readable_review')['status'], 'incomplete');
      expect(section(apollo, 'readable_review')['scheduled_sessions'], 84);
      expect(section(apollo, 'exercise_bindings')['status'], 'unresolved');
    },
  );
  test('compiled package with missing bodies cannot pass readable review', () {
    final r = report(
      read: (p) => p.endsWith('.sql') ? '' : File(p).readAsStringSync(),
    );
    expect(section(r, 'canonical_package')['status'], 'compiled');
    expect(section(r, 'readable_review')['status'], 'blocked');
    expect(
      section(r, 'readable_review')['missing_or_empty_bodies'],
      hasLength(84),
    );
    expect(section(r, 'unsupported_prescriptions')['status'], 'not_assessed');
    expect(section(r, 'exercise_bindings')['status'], 'not_assessed');
  });
  test('invalid package leaves downstream interpretation unassessed', () {
    final r = report(
      read: (p) =>
          p.endsWith('.yaml') ? '::: not yaml' : File(p).readAsStringSync(),
    );
    expect(section(r, 'canonical_package')['status'], 'invalid');
    expect(
      section(r, 'candidate_source').containsKey('version_number'),
      isFalse,
    );
    expect(section(r, 'readable_review')['status'], 'blocked');
    expect(section(r, 'unsupported_prescriptions')['status'], 'not_assessed');
    expect(section(r, 'exercise_bindings')['status'], 'not_assessed');
    expect(
      (r['projection_findings'] as List).any(
        (i) => i['code'] == 'package_compile_failed',
      ),
      isTrue,
    );
  });
  test('missing registered bytes fail instead of borrowing a source', () {
    expect(
      () => report(read: (_) => throw const FileSystemException('missing')),
      throwsA(isA<FileSystemException>()),
    );
  });
  test(
    'report stays unreachable from production and every existing Studio entry',
    () {
      for (final entry in [
        'lib/main.dart',
        'lib/main_programme_studio_preview.dart',
        'lib/main_programme_studio_composition_preview.dart',
        'lib/main_programme_studio_apollo_pilot.dart',
      ]) {
        expect(
          traversal
              .reachable(entry, strict: false)
              .where((p) => p.endsWith('source_readiness_report.dart')),
          isEmpty,
        );
      }
    },
  );
}
