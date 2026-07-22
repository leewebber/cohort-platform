import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/beta_support/beta_diagnostic_summary.dart';
import 'package:cohort_platform/features/programme/debug/programme_debug_resolution_cache.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CurrentUserSession.clear();
    ProgrammeDebugResolutionCache.clear();
  });

  test('beta diagnostic summary excludes secrets and private notes', () {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'user-123',
        displayName: 'Lee',
        isCoach: true,
        isAthlete: true,
      ),
    );

    final summary = BetaDiagnosticSummary.build(
      screenContext: 'Home',
      lastOperation: 'assignment failed',
      hasActiveAssignment: true,
    );

    final text = summary.format();
    expect(text, contains('App version:'));
    expect(text, contains('Coach role: true'));
    expect(text, contains('Active assignment: true'));
    expect(text.toLowerCase(), isNot(contains('token')));
    expect(text.toLowerCase(), isNot(contains('refresh')));
    expect(text.toLowerCase(), isNot(contains('password')));
  });

  test('account switch clears prior debug cache via CurrentUserSession.bind',
      () {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'user-a',
        displayName: 'A',
        isCoach: false,
        isAthlete: true,
      ),
    );

    ProgrammeDebugResolutionCache.store(
      const ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
      ),
    );
    expect(ProgrammeDebugResolutionCache.lastResolution, isNotNull);

    CurrentUserSession.bind(
      const UserProfile(
        id: 'user-b',
        displayName: 'B',
        isCoach: false,
        isAthlete: true,
      ),
    );

    expect(ProgrammeDebugResolutionCache.lastResolution, isNull);
  });
}
