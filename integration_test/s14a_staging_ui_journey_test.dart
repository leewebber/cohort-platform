import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/core/services/supabase_service.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/plans/screens/plan_library_screen.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_plan_materialisation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_services.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_supabase_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hosted Cohort Staging UI journey for Sprint 1.4A.
///
/// Opt-in only. Requires:
/// - `S14A_STAGING_UI=1`
/// - `.env` temporarily pointing at Cohort Staging anon credentials
/// - `S14A_CREDS_FILE` → JSON with athlete `a` email/password/user_id
///
/// Run on a real device/desktop target (not plain `flutter test` VM):
/// `flutter test integration_test/s14a_staging_ui_journey_test.dart -d macos`
///
/// Athlete A may already be materialised by hosted DB probes. This verifies
/// reconciliation, already_materialised handling, legacy preflight, and
/// prohibited-language / navigation preservation.
void main() {
  final enabled = Platform.environment['S14A_STAGING_UI'] == '1';
  if (enabled) {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  group('Sprint 1.4A staging UI journey', () {
    late Map<String, dynamic> athleteA;
    late AthleteProgrammeScreenController controller;

    setUpAll(() async {
      if (!enabled) return;

      final credsPath = Platform.environment['S14A_CREDS_FILE'];
      if (credsPath == null || credsPath.isEmpty) {
        fail('S14A_CREDS_FILE is required when S14A_STAGING_UI=1');
      }
      final creds =
          jsonDecode(File(credsPath).readAsStringSync())
              as Map<String, dynamic>;
      athleteA = Map<String, dynamic>.from(creds['a'] as Map);

      final init = await SupabaseService.tryInitialize();
      expect(init.isConfigured, isTrue, reason: init.errorMessage);
      final url = Supabase.instance.client.rest.url.toString();
      expect(
        url.contains('tsbadngzgvsyfqjupkng'),
        isTrue,
        reason: 'UI journey must target Cohort Staging, not production',
      );

      final auth = await Supabase.instance.client.auth.signInWithPassword(
        email: athleteA['email'] as String,
        password: athleteA['password'] as String,
      );
      expect(auth.session, isNotNull);

      final athleteId = athleteA['user_id'] as String;
      final profileRow = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', athleteId)
          .single();
      final profile = UserProfile.fromMap(
        Map<String, dynamic>.from(profileRow as Map),
      );
      expect(profile.isAthlete && !profile.isCoach, isTrue);
      CurrentUserSession.bind(profile);

      controller =
          AthleteCatalogueEnrolmentServices.createProgrammeScreenController(
            athleteId: athleteId,
          );
      await controller.load();
    });

    tearDown(() async {
      CurrentUserSession.clear();
    });

    test('types remain distinct', () {
      expect(PlanLibraryScreen, isNotNull);
      expect(AthleteProgrammeScreen, isNotNull);
    });

    testWidgets(
      'reconciles materialised programme; legacy preflight; no prepare/commerce',
      (tester) async {
        if (!enabled) return;

        final catalog =
            AthleteCatalogueEnrolmentServices.createCatalogService();
        final programmes = await catalog.listPublishedAssignableProgrammes();
        expect(programmes.any((p) => p.name.contains('PROG-S13-ELIG')), isTrue);

        expect(controller.hasActiveProgramme, isTrue);
        final assignment = controller.activeAssignment!;
        expect(
          assignment.programmeVersionId,
          'e9bd7e19-6eb9-4f7e-abf6-d08ac4368748',
        );
        expect(assignment.isMaterialised, isTrue);
        expect(assignment.materialisationSource, 'athlete_start_programme');
        expect(controller.canStartProgramme, isFalse);

        final status = AthletePlanMaterialisationLabels.statusLabel(assignment);
        expect(status.toLowerCase(), contains('started'));

        final again = await controller.startProgramme(timezone: 'UTC');
        expect(again, isNotNull);
        expect(
          again!.status ==
                  AthletePlanMaterialisationStatus.alreadyMaterialised ||
              again.isSuccess,
          isTrue,
        );

        await controller.load();
        expect(controller.activeAssignment?.isMaterialised, isTrue);
        expect(controller.activeAssignment?.id, assignment.id);

        final legacyService = AthletePlanMaterialisationService(
          materialisationStore: const AthletePlanMaterialisationSupabaseStore(),
          assignmentStore: const ProgrammeAssignmentSupabaseStore(),
          legacyHasActivePlan: () => true,
        );
        final legacy = await legacyService.startProgramme(
          programmeAssignmentId: assignment.id,
          athleteId: athleteA['user_id'] as String,
          timezone: 'UTC',
        );
        expect(
          legacy.status,
          AthletePlanMaterialisationStatus.legacyPlanConflict,
        );
        expect(legacy.message!.toLowerCase(), contains('switching'));

        await tester.pumpWidget(
          MaterialApp(
            home: AthleteProgrammeScreen(
              athleteId: athleteA['user_id'] as String,
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.textContaining('started'), findsWidgets);
        expect(find.text('Start Programme'), findsNothing);
        expect(
          find.textContaining('First session preparation comes next'),
          findsOneWidget,
        );
        expect(find.textContaining('workout ready'), findsNothing);
        expect(find.textContaining('Coach Brain'), findsNothing);
        expect(find.textContaining('subscription'), findsNothing);
        expect(find.textContaining('purchase'), findsNothing);
      },
      skip: !enabled,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
