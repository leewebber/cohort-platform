import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production login has no START TRAINING Coach Brain launch', () {
    final login = File('lib/features/auth/screens/login_screen.dart').readAsStringSync();
    expect(login.contains('START TRAINING'), isFalse);
    expect(login.contains('AthleteOnboardingFlow'), isFalse);
    expect(login.contains('AthleteProgrammeGenerationService'), isFalse);
    expect(login.contains('AthleteAppShell'), isFalse);
  });

  test('AuthGate never uses local onboarding as shell authority', () {
    final gate = File('lib/features/auth/screens/auth_gate.dart').readAsStringSync();
    expect(gate.contains('hasCompletedOnboarding'), isFalse);
    expect(gate.contains('AthleteProfileSession'), isFalse);
    expect(gate.contains('allowRegenerate: true'), isFalse);
    expect(gate.contains('ProductionAuthAuthority'), isTrue);
  });

  test('production main does not import preview players or DJI preview', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('session_player_screen'), isFalse);
    expect(main.contains('main_daily_journey_integrity_preview'), isFalse);
    expect(main.contains('AuthGate'), isFalse);
    expect(main.contains('CohortPlatformApp'), isTrue);
  });
}
