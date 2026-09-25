import 'dart:io';

import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_copy.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_projector.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  ProgrammeReviewCatalog realCatalog() {
    return ProgrammeReviewWorkspace(
      readAsset: (path) => File(path).readAsStringSync(),
    ).loadRealCatalog();
  }

  testWidgets('Coach Review is the default coaching workstation', (
    tester,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    expect(find.text(ProgrammeStudioCopy.coachReview), findsWidgets);
    expect(find.textContaining('Week 1 of 12'), findsWidgets);
    expect(find.text('Monday'), findsWidgets);
    expect(
      find.textContaining('Thoracic extension over foam roller'),
      findsWidgets,
    );
    expect(find.textContaining('Open-book rotation'), findsWidgets);
    expect(find.text('Serratus wall slide + reach'), findsWidgets);
    expect(find.text('Wall Y/lower-trap raise'), findsWidgets);
    expect(
      find.textContaining('Single-arm cable/band row with reach'),
      findsWidgets,
    );
    expect(find.textContaining('81033429'), findsNothing);
    expect(find.textContaining('supabase/migrations'), findsNothing);
    expect(find.textContaining('sql_correction'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Replace default'), findsNothing);
    expect(find.text('Enrol'), findsNothing);
  });

  testWidgets('shows honest inventory and planned families without hashes', (
    tester,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    expect(find.text('Apollo Build — 12-Week Initial Block'), findsWidgets);
    expect(find.textContaining('Internal / personal'), findsWidgets);
    expect(find.textContaining('Spartan Physique Block 1'), findsWidgets);
    expect(find.textContaining('Legacy / withheld'), findsWidgets);
    expect(find.textContaining('1 week'), findsWidgets);
    expect(find.textContaining('6 sessions / week'), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.plannedTitle), findsWidgets);
    expect(find.textContaining('HYROX Base'), findsWidgets);
    expect(find.textContaining(ProgrammeStudioCopy.plannedBadge), findsWidgets);
    expect(find.text('PROG-FIXTURE-01'), findsNothing);
    expect(find.textContaining('hash '), findsNothing);
  });

  testWidgets('fixtures stay out of real inventory until the filter is on', (
    tester,
  ) async {
    const projector = ProgrammeReviewProjector();
    final catalog = projector.project(
      ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewWorkspace(
            readAsset: (path) => File(path).readAsStringSync(),
          ).loadBundle(ProgrammeReviewCatalogRegistry.realSpecs.first),
          const ProgrammeReviewSourceBundle(
            spec: ProgrammeReviewSourceSpec(
              catalogId: 'fixture-hidden',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'preview/invalid.yaml',
              fixture: true,
            ),
            planPackageYaml: '::: not yaml',
          ),
        ],
      ),
    );
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: catalog));
    expect(find.text('fixture-hidden'), findsNothing);
    await tester.tap(find.byTooltip(ProgrammeStudioCopy.developerMenu));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(ProgrammeStudioCopy.fixturesToggle));
    await tester.tap(
      find.text(ProgrammeStudioCopy.fixturesToggle),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('fixture-hidden'), findsOneWidget);
  });

  testWidgets('week and day controls reveal corrected Apollo sessions', (
    tester,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.nextWeek));
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 2 of 12'), findsWidgets);
    await tester.tap(find.text(ProgrammeStudioCopy.previousWeek));
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 1 of 12'), findsWidgets);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(ProgrammeStudioCopy.nextWeek));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Week 5 of 12'), findsWidgets);
    await tester.ensureVisible(find.text('Thursday'));
    await tester.tap(find.text('Thursday'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zone 2'), findsWidgets);
    expect(find.textContaining('60 min'), findsWidgets);
    await tester.ensureVisible(find.text('Saturday'));
    await tester.tap(find.text('Saturday'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fixed-work capture'), findsWidgets);
    expect(find.textContaining('athlete selected'), findsWidgets);
    expect(find.textContaining('Sled Push'), findsWidgets);
  });

  testWidgets(
    'Quality Gate uses readable statuses and is not launch approved',
    (tester) async {
      await setDesktop(tester);
      await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ProgrammeStudioCopy.qualityGate));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(ProgrammeStudioCopy.technicallyValid),
        findsWidgets,
      );
      expect(
        find.textContaining(ProgrammeStudioCopy.notLaunchApproved),
        findsWidgets,
      );
      expect(find.textContaining('Source compiled — Passed'), findsOneWidget);
      expect(
        find.textContaining('Package identity stable — Passed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Coaching review — Not assessed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Athlete device execution — Not assessed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Running pace calculations — Not implemented'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Programme metrics profile — Not implemented'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Garmin/device interoperability — Not implemented'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Launch approval — Not assessed'),
        findsOneWidget,
      );
      expect(find.text('Ready to launch'), findsNothing);
    },
  );

  testWidgets('Technical Integrity retains hashes and correction evidence', (
    tester,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.technicalIntegrity));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canonical hash'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
      ),
      findsWidgets,
    );
    await tester.tap(find.text('Applied Apollo correction chain'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sql_correction_applied'), findsWidgets);
    expect(find.textContaining('supabase/migrations'), findsWidgets);
  });

  testWidgets('Athlete Preview contains no technical evidence', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.athletePreview));
    await tester.pumpAndSettle();
    expect(find.text(ProgrammeStudioCopy.athletePreviewBanner), findsOneWidget);
    expect(find.textContaining('SHA-256'), findsNothing);
    expect(find.textContaining('sql_correction'), findsNothing);
    expect(find.textContaining('lineage'), findsNothing);
  });

  testWidgets('planned family shows an empty planning state', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HYROX Base'));
    await tester.pumpAndSettle();
    expect(find.text(ProgrammeStudioCopy.plannedEmptySessions), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.plannedAuthoringClosed), findsWidgets);
    expect(find.text('Monday'), findsNothing);
  });

  testWidgets('keyboard can change week and review mode', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.appTitle));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 2 of 12'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();
    expect(find.textContaining('Source compiled — Passed'), findsOneWidget);
  });

  testWidgets('narrow viewport and large text remain usable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.7),
        ),
        child: ProgrammeStudioApp(catalog: realCatalog()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(ProgrammeStudioCopy.appTitle), findsOneWidget);
    expect(find.textContaining('Week 1 of 12'), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.emptyInventory), findsNothing);
  });

  testWidgets('empty inventory and missing protocol fixtures stay labelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProgrammeStudioApp(
        catalog: ProgrammeReviewCatalog(
          authority: ProgrammeReviewCatalog.derivedAuthority,
          sourceInputs: [],
          programmes: [],
          plannedFamilies: [],
        ),
      ),
    );
    expect(find.text(ProgrammeStudioCopy.emptyInventory), findsOneWidget);

    const projector = ProgrammeReviewProjector();
    final missing = projector.project(
      const ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewSourceBundle(
            spec: ProgrammeReviewSourceSpec(
              catalogId: 'fixture-missing-protocol',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'preview/missing.yaml',
              fixture: true,
            ),
            planPackageYaml: '''
package_schema_version: 1
programme:
  lineage_code: FIXTURE-ONE
  version_number: 1
  name: Fixture one session
  library_scope: organisation
  owner_type: organisation
  coaching_intent: Fixture only
  duration_weeks: 1
  sessions_per_week: 1
sessions:
  - session_key: SES-FIX
    protocol_id: PROTO-X
    session_lineage_id: 00000000-0000-4000-8000-000000000099
    revision_number: 1
    title: Fixture session
phases: []
weeks:
  - week_number: 1
    title: Week 1
    days:
      - day_key: day_1
        day_order: 1
        day_type: training
        title: Monday
        slots:
          - slot_key: W1D1S1
            session_order: 1
            session_key: SES-FIX
            completion_expectation: required
            progression:
              prescription_summary: Fixture slot
adaptation_permissions: []
protected_invariants: []
assessments: []
performance_evidence_requirements: []
comparison_identities: []
''',
          ),
        ],
      ),
    );
    expect(missing.developerFixtures, isNotEmpty);
    await setDesktop(tester);
    await tester.pumpWidget(
      ProgrammeStudioApp(
        key: const Key('missing-protocol'),
        catalog: missing,
        showDeveloperFixtures: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(missing.developerFixtures.single.title),
      findsWidgets,
    );
    expect(find.text(ProgrammeStudioCopy.missingProtocol), findsOneWidget);
  });
}
