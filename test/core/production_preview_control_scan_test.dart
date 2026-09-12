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
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
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
