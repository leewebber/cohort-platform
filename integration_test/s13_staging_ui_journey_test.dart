import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/core/services/supabase_service.dart';
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/plans/screens/plan_library_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hosted Cohort Staging UI journey for Sprint 1.3.
///
/// Opt-in only. Requires:
/// - `S13_STAGING_UI=1`
/// - `.env` temporarily pointing at Cohort Staging anon credentials
/// - `S13_CREDS_FILE` → JSON with athlete `a` email/password (outside repo)
/// - `S13_IDS_FILE` → JSON with fixture version ids / athlete ids
///
/// Run on a real device/desktop target (not plain `flutter test` VM):
/// `flutter test integration_test/s13_staging_ui_journey_test.dart -d macos`
///
/// Never commit credentials. Skips when not explicitly enabled.
void main() {
  final enabled = Platform.environment['S13_STAGING_UI'] == '1';
  if (enabled) {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  group('Sprint 1.3 staging UI journey', () {
    late Map<String, dynamic> creds;
    late Map<String, dynamic> ids;

    setUpAll(() async {
      if (!enabled) return;

      final credsPath = Platform.environment['S13_CREDS_FILE'];
      final idsPath = Platform.environment['S13_IDS_FILE'];
      if (credsPath == null || idsPath == null) {
        fail(
          'S13_CREDS_FILE and S13_IDS_FILE are required when S13_STAGING_UI=1',
        );
      }
      creds =
          jsonDecode(File(credsPath).readAsStringSync())
              as Map<String, dynamic>;
      ids =
          jsonDecode(File(idsPath).readAsStringSync()) as Map<String, dynamic>;

      final init = await SupabaseService.tryInitialize();
      expect(init.isConfigured, isTrue, reason: init.errorMessage);
      final url = Supabase.instance.client.rest.url.toString();
      expect(
        url.contains('tsbadngzgvsyfqjupkng'),
        isTrue,
        reason: 'UI journey must target Cohort Staging, not production',
      );
    });

    tearDown(() async {
      CurrentUserSession.clear();
      if (enabled) {
        await Supabase.instance.client.auth.signOut();
      }
    });

    testWidgets(
      'Home Programme and Plans separation; catalogue enrol against staging',
      (tester) async {
        if (!enabled) {
          return;
        }

        final email = (creds['a'] as Map)['email'] as String;
        final password = (creds['a'] as Map)['password'] as String;
        final athleteId = ids['athlete_a_id'] as String;
        final eligibleName = 'S13 Staging PROG-S13-ELIG';

        final auth = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        expect(auth.session, isNotNull);

        final profileRow = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', athleteId)
            .single();
        final profile = UserProfile.fromMap(
          Map<String, dynamic>.from(profileRow as Map),
        );
        expect(profile.isAthlete, isTrue);
        expect(profile.isCoach, isFalse);
        CurrentUserSession.bind(profile);

        await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
        await tester.pump();
        // Allow Home async sections to settle without hanging forever.
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Programme'), findsWidgets);
        expect(find.text('Home'), findsWidgets);
        expect(find.text('Plans'), findsOneWidget);

        // Empty-state VIEW PROGRAMMES when no local plan session is bound.
        final viewProgrammes = find.text('VIEW PROGRAMMES');
        final programmeLink = find.widgetWithText(TextButton, 'Programme');
        expect(programmeLink, findsOneWidget);

        if (viewProgrammes.evaluate().isNotEmpty) {
          await tester.tap(viewProgrammes);
        } else {
          await tester.tap(programmeLink);
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        // Either Programme overview or selection is acceptable entry.
        final onProgramme =
            find.byType(AthleteProgrammeScreen).evaluate().isNotEmpty ||
            find
                .byType(AthleteProgrammeSelectionScreen)
                .evaluate()
                .isNotEmpty ||
            find.text('Current programme').evaluate().isNotEmpty ||
            find.textContaining('S13 Staging').evaluate().isNotEmpty;
        expect(onProgramme, isTrue);

        // Prefer opening selection catalogue if overview is showing.
        final viewProgrammesMuted = find.text('View programmes');
        if (viewProgrammesMuted.evaluate().isNotEmpty) {
          await tester.tap(viewProgrammesMuted);
          await tester.pump();
          await tester.pump(const Duration(seconds: 3));
        }

        expect(find.byType(PlanLibraryScreen), findsNothing);

        // Eligible fixture visible; negatives not listed by name.
        expect(find.textContaining('PROG-S13-ELIG'), findsWidgets);
        expect(find.textContaining('PROG-S13-DRAFT'), findsNothing);
        expect(find.textContaining('PROG-S13-UNAPP'), findsNothing);
        expect(find.textContaining('PROG-S13-PRIV'), findsNothing);

        // Prohibited commercial language absent (disclaimer may mention purchase).
        for (final banned in [
          'Buy',
          'Checkout',
          'Payment complete',
          'Your purchase',
          'Subscription management',
          'Owned',
          'Order',
          'Price',
        ]) {
          expect(find.text(banned), findsNothing);
        }

        // Enrol flow
        final eligibleCard = find.textContaining(eligibleName);
        expect(eligibleCard, findsWidgets);
        await tester.tap(eligibleCard.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Enrol in'), findsOneWidget);
        expect(find.textContaining('not a purchase'), findsOneWidget);

        final enrolButton = find.widgetWithText(TextButton, 'Enrol');
        expect(enrolButton, findsOneWidget);
        await tester.tap(enrolButton);
        await tester.pump();
        // In-progress / network
        await tester.pump(const Duration(seconds: 4));

        // Success snackbar or enrolled/current programme visibility.
        final enrolledSignals =
            find.textContaining('Enrolled').evaluate().isNotEmpty ||
            find.textContaining('Already enrolled').evaluate().isNotEmpty ||
            find
                .textContaining('Your programme is ready')
                .evaluate()
                .isNotEmpty ||
            find.text('Current programme').evaluate().isNotEmpty;
        expect(enrolledSignals, isTrue);

        // Idempotent revisit via Programme entry from a fresh shell.
        await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.widgetWithText(TextButton, 'Programme'));
        await tester.pump(const Duration(seconds: 3));
        expect(
          find.textContaining('PROG-S13-ELIG').evaluate().isNotEmpty ||
              find.text('Current programme').evaluate().isNotEmpty,
          isTrue,
        );

        // Plans tab remains Plan Library.
        await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Plans'));
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(PlanLibraryScreen), findsOneWidget);
        expect(find.byType(AthleteProgrammeSelectionScreen), findsNothing);

        // Home still has Programme entry and is not Plan Library.
        await tester.tap(find.text('Home'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Programme'), findsOneWidget);
      },
      skip: !enabled,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
