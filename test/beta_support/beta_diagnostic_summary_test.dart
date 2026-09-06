import 'package:cohort_platform/core/config/app_build_provenance.dart';
import 'package:cohort_platform/core/config/build_environment.dart';
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
    AppBuildProvenance.debugOverride = null;
  });

  test('beta diagnostic summary excludes secrets and private notes', () {
    AppBuildProvenance.debugOverride = const AppBuildProvenance(
      environment: BuildEnvironment.production,
      appVersion: '1.0.0',
      buildNumber: '42',
      gitCommit: '388cc4ad42f12f0157ddfe106ae3952ffe241deb',
    );
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
    expect(text, contains('Cohort 1.0.0 (42)'));
    expect(text, contains('Commit 388cc4a'));
    expect(text, contains('Environment Production'));
    expect(text, contains('Active assignment: true'));
    expect(text.toLowerCase(), isNot(contains('token')));
    expect(text.toLowerCase(), isNot(contains('refresh')));
    expect(text.toLowerCase(), isNot(contains('password')));
    expect(text, isNot(contains('otnhhdxs')));
    expect(text, isNot(contains('service_role')));
  });

  test(
    'account switch clears prior debug cache via CurrentUserSession.bind',
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
        const ResolvedTodaySession(kind: ResolvedTodaySessionKind.executable),
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
    },
  );
}
