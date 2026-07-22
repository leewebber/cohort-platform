import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const forbiddenHomeLabels = <String>[
    'Analyze Current Protocol',
    'Compare BW-001 Similarity',
    'Compile RN-006 Interval Plan',
    'Compile Circuit Debug Plans',
    'Compare BW-001 Suitable Alternatives',
    'Assign Test Programme',
    'Resolve Test Programme',
    'Sync Resolved Session',
    'Complete Current Programme Slot',
    'Complete Current Slot Partial',
    'Reset Test Programme Assignment',
    'Install Founder Acceptance Programme',
    'Assign Founder Acceptance Programme',
    'Resolve Founder Acceptance Programme',
    'Reset Founder Acceptance Programme',
    'Admin Protocol Editor',
    "const SectionTitle('DEBUG')",
    'if (kDebugMode)',
  ];

  group('production navigation source scan', () {
    test('home screen does not mount known internal action labels', () {
      final homePath = 'lib/features/home/home_screen.dart';
      final contents = File(homePath).readAsStringSync();

      final violations = <String>[];
      for (final label in forbiddenHomeLabels) {
        if (contents.contains(label)) {
          violations.add('home_screen.dart contains "$label"');
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
