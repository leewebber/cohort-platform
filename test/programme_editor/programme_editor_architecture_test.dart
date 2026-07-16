import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editor widgets and controller avoid Supabase imports', () {
    final root = Directory.current.path;
    final targets = [
      '$root/lib/features/coach_studio/programmes/controllers/programme_editor_controller.dart',
      '$root/lib/features/coach_studio/programmes/widgets',
      '$root/lib/features/coach_studio/programmes/programme_editor_screen.dart',
      '$root/lib/features/coach_studio/programmes/programme_preview_screen.dart',
    ];

    final violations = <String>[];

    for (final target in targets) {
      final entity = File(target);
      if (entity.existsSync()) {
        _scanFile(entity, violations);
        continue;
      }

      final directory = Directory(target);
      if (!directory.existsSync()) continue;

      for (final file in directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        _scanFile(file, violations);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

void _scanFile(File file, List<String> violations) {
  final lines = file.readAsLinesSync();
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ') &&
        trimmed.toLowerCase().contains('supabase')) {
      violations.add(file.path);
      break;
    }
  }
}
