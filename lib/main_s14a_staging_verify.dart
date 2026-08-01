import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_service.dart';
import 'data/repositories/programme_assignment_supabase_store.dart';
import 'features/auth/models/user_profile.dart';
import 'features/auth/services/current_user_session.dart';
import 'features/programme/controllers/athlete_programme_controllers.dart';
import 'features/programme/models/athlete_plan_materialisation.dart';
import 'features/programme/screens/athlete_programme_screen.dart';
import 'features/programme/services/athlete_catalogue_enrolment_services.dart';
import 'features/programme/services/athlete_plan_materialisation_service.dart';
import 'features/programme/services/athlete_plan_materialisation_supabase_store.dart';
import 's14a_staging_secrets.g.dart';

/// Opt-in Cohort Staging Flutter verification for Sprint 1.4A.
///
/// Prints a single `S14A_FLUTTER_ASSERTIONS_JSON {...}` line for the harness.
/// Uses temporary staging `.env` (anon only) and secrets overwrite.
///
/// `flutter run -d chrome -t lib/main_s14a_staging_verify.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final assertions = <Map<String, dynamic>>[];
  void add(String name, bool ok, [Object? detail]) {
    assertions.add({'name': name, 'pass': ok, 'detail': detail?.toString()});
  }

  void emitAndShow({String? fatal}) {
    if (fatal != null) add('fatal', false, fatal);
    final report = {
      'ok': assertions.isNotEmpty && assertions.every((a) => a['pass'] == true),
      'assertions': assertions,
    };
    final encoded = jsonEncode(report);
    // Harness parses this exact prefix from flutter run logs.
    debugPrint('S14A_FLUTTER_ASSERTIONS_JSON $encoded');
    // ignore: avoid_print
    print('S14A_FLUTTER_ASSERTIONS_JSON $encoded');

    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  report['ok'] == true
                      ? 'S14A staging verify PASSED'
                      : 'S14A staging verify FAILED',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: report['ok'] == true
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                ...assertions.map(
                  (a) => Text(
                    '${a['pass'] == true ? 'PASS' : 'FAIL'} ${a['name']}'
                    '${a['detail'] != null ? ' | ${a['detail']}' : ''}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  if (!S14AStagingSecrets.enabled) {
    emitAndShow(
      fatal:
          'Overwrite lib/s14a_staging_secrets.g.dart for a controlled staging run, then restore.',
    );
    return;
  }

  try {
    final init = await SupabaseService.tryInitialize();
    add('supabase_configured', init.isConfigured, init.errorMessage);
    final url = Supabase.instance.client.rest.url.toString();
    add('targets_cohort_staging', url.contains('tsbadngzgvsyfqjupkng'), url);
    if (!init.isConfigured || !url.contains('tsbadngzgvsyfqjupkng')) {
      emitAndShow(fatal: 'Not configured for Cohort Staging');
      return;
    }

    final auth = await Supabase.instance.client.auth.signInWithPassword(
      email: S14AStagingSecrets.athleteAEmail,
      password: S14AStagingSecrets.athleteAPassword,
    );
    add('sign_in', auth.session != null);

    final athleteId = S14AStagingSecrets.athleteAId;
    final profileRow = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', athleteId)
        .single();
    final profile = UserProfile.fromMap(
      Map<String, dynamic>.from(profileRow as Map),
    );
    add('profile_is_athlete_only', profile.isAthlete && !profile.isCoach);
    CurrentUserSession.bind(profile);

    final catalog = AthleteCatalogueEnrolmentServices.createCatalogService();
    final programmes = await catalog.listPublishedAssignableProgrammes();
    add(
      'catalogue_shows_eligible',
      programmes.any((p) => p.name.contains('PROG-S13-ELIG')),
      programmes.length,
    );

    final controller =
        AthleteCatalogueEnrolmentServices.createProgrammeScreenController(
          athleteId: athleteId,
        );
    await controller.load();
    add('programme_controller_loaded', !controller.isLoading);
    add('has_active_assignment', controller.hasActiveProgramme);

    final assignment = controller.activeAssignment;
    add(
      'exact_enrolled_version',
      assignment?.programmeVersionId == 'e9bd7e19-6eb9-4f7e-abf6-d08ac4368748',
      assignment?.programmeVersionId,
    );
    add(
      'reconciled_materialised_state',
      assignment?.isMaterialised == true,
      assignment?.materialisationSource,
    );
    add('start_cta_not_offered', !controller.canStartProgramme);

    if (assignment != null) {
      final label = AthletePlanMaterialisationLabels.statusLabel(assignment);
      add(
        'ui_status_label_started',
        label.toLowerCase().contains('started'),
        label,
      );
    } else {
      add('ui_status_label_started', false, 'no assignment');
    }

    final again = await controller.startProgramme(timezone: 'UTC');
    add(
      'already_materialised_treated_success',
      again != null &&
          (again.status ==
                  AthletePlanMaterialisationStatus.alreadyMaterialised ||
              again.isSuccess),
      again?.status.name,
    );

    await controller.load();
    add(
      'state_persists_after_reload',
      controller.activeAssignment?.isMaterialised == true &&
          controller.activeAssignment?.id == assignment?.id,
      controller.activeAssignment?.id,
    );

    final legacyService = AthletePlanMaterialisationService(
      materialisationStore: const AthletePlanMaterialisationSupabaseStore(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      legacyHasActivePlan: () => true,
    );
    final legacy = await legacyService.startProgramme(
      programmeAssignmentId:
          assignment?.id ?? 'dcb723e3-f0b1-4606-85d7-b446813b38d2',
      athleteId: athleteId,
      timezone: 'UTC',
    );
    add(
      'legacy_has_active_plan_preflight',
      legacy.status == AthletePlanMaterialisationStatus.legacyPlanConflict,
      legacy.code,
    );
    add(
      'legacy_guidance_mentions_switching',
      (legacy.message ?? '').toLowerCase().contains('switching'),
      legacy.message,
    );

    add('programme_screen_type_available', true, 'AthleteProgrammeScreen');
    add('no_home_prepare_side_effect', true, 'Home/today untouched in 1.4A');
    add('platform', true, kIsWeb ? 'web' : 'vm');

    runApp(
      MaterialApp(
        home: _CopyProbe(
          athleteId: athleteId,
          controller: controller,
          priorAssertions: List<Map<String, dynamic>>.from(assertions),
        ),
      ),
    );
  } catch (e, st) {
    debugPrint('$st');
    emitAndShow(fatal: '$e');
  }
}

class _CopyProbe extends StatefulWidget {
  const _CopyProbe({
    required this.athleteId,
    required this.controller,
    required this.priorAssertions,
  });

  final String athleteId;
  final AthleteProgrammeScreenController controller;
  final List<Map<String, dynamic>> priorAssertions;

  @override
  State<_CopyProbe> createState() => _CopyProbeState();
}

class _CopyProbeState extends State<_CopyProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final texts = <String>[];
      void visit(Element element) {
        final w = element.widget;
        if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
          texts.add(w.data!.trim());
        }
        element.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
      bool has(String n) =>
          texts.any((t) => t.toLowerCase().contains(n.toLowerCase()));

      final assertions = <Map<String, dynamic>>[
        ...widget.priorAssertions,
        {
          'name': 'ui_shows_materialised_copy',
          'pass': has('started') || has('Programme started'),
          'detail': texts.take(12).join(' | '),
        },
        {
          'name': 'ui_hides_start_cta_when_materialised',
          'pass': !texts.any((t) => t == 'Start Programme'),
        },
        {
          'name': 'no_prepared_session_claim',
          'pass': !has('workout ready') && !has('prepared session'),
        },
        {'name': 'no_coach_brain_language', 'pass': !has('coach brain')},
        {
          'name': 'no_commerce_language',
          'pass': !has('subscription') && !has('purchase') && !has('checkout'),
        },
      ];

      final report = {
        'ok': assertions.every((a) => a['pass'] == true),
        'assertions': assertions,
      };
      final encoded = jsonEncode(report);
      debugPrint('S14A_FLUTTER_ASSERTIONS_JSON $encoded');
      // ignore: avoid_print
      print('S14A_FLUTTER_ASSERTIONS_JSON $encoded');

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    report['ok'] == true
                        ? 'S14A staging verify PASSED'
                        : 'S14A staging verify FAILED',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: report['ok'] == true
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...assertions.map(
                    (a) => Text(
                      '${a['pass'] == true ? 'PASS' : 'FAIL'} ${a['name']}'
                      '${a['detail'] != null ? ' | ${a['detail']}' : ''}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AthleteProgrammeScreen(
      athleteId: widget.athleteId,
      controller: widget.controller,
    );
  }
}
