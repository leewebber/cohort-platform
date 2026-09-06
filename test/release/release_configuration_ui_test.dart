import 'package:cohort_platform/app/app.dart';
import 'package:cohort_platform/core/config/app_build_provenance.dart';
import 'package:cohort_platform/core/config/build_environment.dart';
import 'package:cohort_platform/core/config/release_configuration_code.dart';
import 'package:cohort_platform/core/widgets/local_preview_banner.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/beta_support/beta_diagnostic_summary.dart';
import 'package:cohort_platform/features/beta_support/beta_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_controller_test.dart' show FakeAuthSessionPort;
import '../support/in_memory_profile_repository.dart';
import 'synthetic_jwts.dart';

void main() {
  tearDown(() {
    AppBuildProvenance.debugOverride = null;
  });

  testWidgets('invalid configuration shows a safe non-auth error screen', (
    tester,
  ) async {
    AppBuildProvenance.debugOverride = const AppBuildProvenance(
      environment: BuildEnvironment.production,
      appVersion: '1.0.0',
      buildNumber: '42',
      gitCommit: '388cc4ad42f12f0157ddfe106ae3952ffe241deb',
    );

    await tester.pumpWidget(
      const CohortPlatformApp(
        configurationError: 'This build has invalid Production configuration.',
        configurationErrorCode: ReleaseConfigurationCode.productionHost,
      ),
    );

    expect(
      find.text('This build has invalid Production configuration.'),
      findsOneWidget,
    );
    expect(find.text('Cohort 1.0.0 (42)'), findsOneWidget);
    expect(find.text('Commit 388cc4a'), findsOneWidget);
    expect(find.text('Environment Production'), findsOneWidget);
    expect(find.text('CFG_PROD_HOST'), findsOneWidget);
    expect(find.byType(AuthGate), findsNothing);
    expect(find.textContaining('supabase'), findsNothing);
    expect(find.textContaining(SyntheticJwts.anon), findsNothing);
    expect(find.byType(LocalPreviewBanner), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('LOCAL PREVIEW is visible before login', (tester) async {
    AppBuildProvenance.debugOverride = const AppBuildProvenance(
      environment: BuildEnvironment.loopbackPreview,
      appVersion: '1.0.0',
      buildNumber: '1',
      gitCommit: '388cc4a',
    );

    final controller = AuthController(
      authService: FakeAuthSessionPort(),
      profileProvisioningService: ProfileProvisioningService(
        profileRepository: InMemoryProfileRepository(),
      ),
    );

    await tester.pumpWidget(CohortPlatformApp(authController: controller));
    await tester.pump();

    expect(find.text('LOCAL PREVIEW'), findsWidgets);
    expect(find.byIcon(Icons.computer), findsOneWidget);
    expect(find.byType(AuthGate), findsOneWidget);
  });

  testWidgets('Help & feedback shows provenance and no secrets', (tester) async {
    AppBuildProvenance.debugOverride = const AppBuildProvenance(
      environment: BuildEnvironment.loopbackPreview,
      appVersion: '1.0.0',
      buildNumber: '42',
      gitCommit: '388cc4ad42f12f0157ddfe106ae3952ffe241deb',
    );

    await tester.pumpWidget(const MaterialApp(home: BetaSupportScreen()));

    expect(find.text('Cohort 1.0.0 (42)'), findsOneWidget);
    expect(find.text('388cc4a'), findsOneWidget);
    expect(find.text('Local Preview'), findsOneWidget);
    final summary = BetaDiagnosticSummary.build();
    expect(summary.format(), contains('Cohort 1.0.0 (42)'));
    expect(summary.format(), contains('Commit 388cc4a'));
    expect(summary.format(), contains('Environment Local Preview'));
    expect(summary.format().toLowerCase(), isNot(contains('token')));
    expect(summary.format(), isNot(contains('SUPABASE')));
    expect(summary.format(), isNot(contains(SyntheticJwts.anon)));
    expect(summary.format(), isNot(contains(BuildEnvironment.productionHost)));
  });
}
