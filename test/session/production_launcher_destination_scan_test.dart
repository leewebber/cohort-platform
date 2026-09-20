import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production launchers do not push preview SessionPlayerScreen', () {
    final launcher = File(
      'lib/features/session/services/session_execution_launcher.dart',
    ).readAsStringSync();
    final programme = File(
      'lib/features/session/services/programme_session_execution_launcher.dart',
    ).readAsStringSync();
    expect(launcher.contains('SessionPlayerScreen'), isFalse);
    expect(launcher.contains('ActiveSessionScreen'), isTrue);
    expect(launcher.contains('ProductionRestoreResolver'), isTrue);
    expect(launcher.contains('AthleteSessionMemoryStore.instance.read'), isTrue);
    expect(programme.contains('SessionPlayerScreen'), isFalse);
    expect(programme.contains('launchActiveSessionWithPlan'), isTrue);
  });
}
