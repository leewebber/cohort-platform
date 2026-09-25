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

  testWidgets('shows honest inventory and no mutation controls', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    expect(find.text('Apollo Build — 12-Week Initial Block'), findsWidgets);
    expect(find.textContaining('Internal / personal'), findsWidgets);
    expect(find.textContaining('Spartan Physique Block 1'), findsWidgets);
    expect(find.textContaining('Legacy / withheld'), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.plannedTitle), findsWidgets);
    expect(find.textContaining('HYROX'), findsWidgets);
    expect(find.text('PROG-FIXTURE-01'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Replace default'), findsNothing);
    expect(find.text('Enrol'), findsNothing);
    expect(find.textContaining('enrol_athlete'), findsNothing);
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
    await tester.tap(find.text(ProgrammeStudioCopy.fixturesToggle));
    await tester.pumpAndSettle();
    expect(find.text('fixture-hidden'), findsOneWidget);
  });

  testWidgets('navigates week day session and distinguishes launch readiness', (
    tester,
  ) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.validation));
    await tester.pumpAndSettle();
    expect(find.textContaining('Compiler success is not launch approval'), findsWidgets);
    await tester.tap(find.text(ProgrammeStudioCopy.readiness));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not implemented'), findsWidgets);
    expect(find.textContaining('Pace-calculation readiness'), findsOneWidget);
    expect(find.textContaining('Device / Garmin readiness'), findsOneWidget);
    await tester.tap(find.text(ProgrammeStudioCopy.session));
    await tester.pumpAndSettle();
    expect(find.textContaining('APOLLO-W'), findsWidgets);
  });

  testWidgets('keyboard focus can change views', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: realCatalog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProgrammeStudioCopy.appTitle));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.pumpAndSettle();
    expect(find.textContaining('Coaching approval'), findsOneWidget);
  });

  testWidgets('narrow viewport and large text remain usable', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(1.7),
        ),
        child: ProgrammeStudioApp(catalog: realCatalog()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(ProgrammeStudioCopy.appTitle), findsOneWidget);
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
    await tester.tap(find.widgetWithText(ChoiceChip, ProgrammeStudioCopy.session));
    await tester.pumpAndSettle();
    expect(find.text(ProgrammeStudioCopy.missingProtocol), findsOneWidget);
  });
}
