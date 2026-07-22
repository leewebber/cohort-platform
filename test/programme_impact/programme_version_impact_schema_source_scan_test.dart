import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('programme version impact schema source scan', () {
    test('impact store does not select removed protocol_steps.step_id column', () {
      final impactStoreFile = File(
        'lib/data/repositories/programme_version_impact_supabase_store.dart',
      );
      expect(impactStoreFile.existsSync(), isTrue);

      final contents = impactStoreFile.readAsStringSync();
      expect(
        contents.contains("select('step_id"),
        isFalse,
        reason:
            'protocol_steps primary key is id; step_id was removed from production schema',
      );
    });

    test('lib does not query protocol_steps.step_id via PostgREST select', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final violations = <String>[];
      final stepIdSelectPattern = RegExp(
        r"\.select\s*\(\s*'[^']*\bstep_id\b",
      );

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final path = entity.path.replaceAll('\\', '/');
        final contents = entity.readAsStringSync();
        if (!contents.contains('protocol_steps')) continue;
        if (stepIdSelectPattern.hasMatch(contents)) {
          violations.add(path);
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
