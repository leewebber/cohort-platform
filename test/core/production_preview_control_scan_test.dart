import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const productionPaths = [
    'lib/main.dart',
    'lib/app/app.dart',
    'lib/features/app_shell/athlete_app_shell.dart',
    'lib/features/home/home_screen.dart',
    'lib/features/app_shell/screens/athlete_profile_screen.dart',
    'lib/features/programme/screens/athlete_calendar_screen.dart',
    'lib/features/programme/screens/athlete_programme_screen.dart',
    'lib/features/progress/screens/progress_screen.dart',
  ];

  test('production entrypoints do not mount Reset preview', () {
    final violations = <String>[];
    for (final path in productionPaths) {
      final contents = File(path).readAsStringSync();
      if (contents.contains('Reset preview')) {
        violations.add('$path contains Reset preview');
      }
      if (contents.contains('AthleteShellPreviewApp')) {
        violations.add('$path imports the preview harness');
      }
      if (contents.contains('main_emom_result_preview')) {
        violations.add('$path references the EMOM preview entry');
      }
      if (contents.contains('InMemoryPerformanceRecordStore')) {
        violations.add('$path uses an in-memory performance store');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('preview entry points stay off the production main', () {
    final productionMain = File('lib/main.dart').readAsStringSync();
    expect(productionMain, contains('CohortPlatformApp'));
    expect(productionMain, isNot(contains('main_emom_result_preview')));
    expect(productionMain, isNot(contains('main_progression_mechanics_preview')));

    final previewMains = [
      'lib/main_athlete_shell_preview.dart',
      'lib/main_emom_result_preview.dart',
      'lib/main_overdue_recovery_preview.dart',
      'lib/main_strength_accordion_preview.dart',
      'lib/main_week2_previous_strength_preview.dart',
      'lib/main_progression_mechanics_preview.dart',
    ];
    for (final path in previewMains) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('production profile diagnostics stay secret-free', () {
    final contents = File(
      'lib/features/app_shell/screens/athlete_profile_screen.dart',
    ).readAsStringSync();
    expect(contents.contains('supabase.co'), isFalse);
    expect(contents.contains('service_role'), isFalse);
    expect(contents.contains('SUPABASE_URL'), isFalse);
    expect(contents.contains('anon key'), isFalse);
    expect(contents.contains('JWT'), isFalse);
  });
}
