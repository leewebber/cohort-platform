import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final forbiddenPatterns = <String>[
    'ProgrammeDevIdentity',
    'DevCoachIdentity',
    "ProgrammeDevIdentity.coachId",
    "?? ProgrammeDevIdentity",
    "?? const DevCoachIdentity",
    "coachId = ProgrammeDevIdentity",
    "coachId: ProgrammeDevIdentity",
    "String coachId = ProgrammeDevIdentity",
  ];

  final allowedPathFragments = <String>[
    '/features/programme/debug/',
    '/features/founder_acceptance/',
  ];

  group('production identity source scan', () {
    test('lib production paths do not silently default to dev-coach', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final path = entity.path.replaceAll('\\', '/');
        if (allowedPathFragments.any(path.contains)) continue;

        final contents = entity.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          if (contents.contains(pattern)) {
            violations.add('$path contains "$pattern"');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: violations.join('\n'),
      );
    });
  });
}
