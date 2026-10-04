import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_controller.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_copy.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProgrammeReviewWorkspace workspace() => ProgrammeReviewWorkspace(
    readAsset: (path) => File(path).readAsStringSync(),
  );

  ProgrammeReviewCatalog catalog() =>
      workspace().loadRealCatalog(includeDeveloperFixtures: true);

  ProgrammeReviewProgramme fixture() => catalog().developerFixtures.singleWhere(
    (item) => item.catalogId == 'b3-device-validation-v1',
  );

  test('retains exact structured running review from attested sources', () {
    final first = fixture();
    final second = fixture();
    expect(first.toJson(), second.toJson());
    expect(
      first.compile.contentHashSha256,
      'fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a',
    );
    final sessions = first.weeks.single.days.single.sessions;
    expect(sessions, hasLength(4));
    for (final session in sessions) {
      final running = session.structuredRunning!;
      expect(running.status, ProgrammeReviewRunningStatus.verified);
      expect(running.groups, hasLength(1));
      expect(running.groups.single.repeatCount, 3);
      expect(running.groups.single.steps.map((step) => step.role), [
        'work',
        'recovery',
      ]);
      expect(running.groups.single.steps.map((step) => step.durationValue), [
        20000,
        15000,
      ]);
      expect(running.groups.single.steps.first.hasAdvisoryTarget, isTrue);
      expect(running.groups.single.steps.last.hasAdvisoryTarget, isFalse);
      expect(
        running.executionMappingSha256,
        '91dac4d3717737d84ab31c805a9b69be3c28db68500cfbd368176e587af5a421',
      );
      expect(
        running.protocolGraphSha256,
        '44e00cacd3e86d6c440279c58aca44f50d46d1af102020bdd6636310ca1f4a17',
      );
    }
  });

  test('hash-pinned graph mismatch remains visible and fails closed', () {
    final spec = ProgrammeReviewCatalogRegistry.developerSpecs.single;
    final exact = workspace().loadBundle(spec);
    final changed = ProgrammeReviewSourceBundle(
      spec: exact.spec,
      planPackageYaml: exact.planPackageYaml,
      publicationJson: exact.publicationJson,
      reviewedProtocolGraphJson: exact.reviewedProtocolGraphJson!.replaceFirst(
        '"work_seconds": 20',
        '"work_seconds": 21',
      ),
    );
    final programme = workspace().projector.projectBundle(changed);
    expect(
      programme.findings.map((item) => item.code),
      contains('protocol_graph_hash_mismatch'),
    );
    expect(
      programme.weeks.single.days.single.sessions.every(
        (session) =>
            session.structuredRunning!.status ==
            ProgrammeReviewRunningStatus.invalidBinding,
      ),
      isTrue,
    );
  });

  test('developer fixture stays outside real inventory', () {
    final review = catalog();
    expect(
      review
          .realInventory(includeFixtures: false)
          .map((item) => item.catalogId),
      ['apollo-build-v2', 'bali-hybrid-base-v1', 'spartan-physique-v3'],
    );
    expect(
      review.realInventory(includeFixtures: true).map((item) => item.catalogId),
      contains('b3-device-validation-v1'),
    );
  });

  test('unattached v2 remains authored without claiming execution', () {
    final programme = workspace().projector.projectBundle(
      ProgrammeReviewSourceBundle(
        spec: const ProgrammeReviewSourceSpec(
          catalogId: 'unattached-v2',
          classification: ProgrammeReviewClassification.fixtureTestExample,
          planPackagePath:
              'packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.yaml',
          fixture: true,
        ),
        planPackageYaml: File(
          'packages/cohort_plan_package/test/fixtures/minimal_plan_package_v2.yaml',
        ).readAsStringSync(),
      ),
    );
    final running =
        programme.weeks.single.days.single.sessions.single.structuredRunning!;
    expect(running.status, ProgrammeReviewRunningStatus.authoredUnattached);
    expect(running.groups, isEmpty);
    expect(running.bindings, isEmpty);
    expect(running.policies, hasLength(1));
  });

  test('overlap is visible but remains a proposed canonical authority fix', () {
    final spec = ProgrammeReviewCatalogRegistry.developerSpecs.single;
    final exact = workspace().loadBundle(spec);
    final overlappingYaml = exact.planPackageYaml.replaceFirst(
      '          - slot_key: W1D1S2-PACE-UNAVAILABLE',
      '''                - attachment_id: B3-DEV-TEST-ONLY-OVERLAP
                  step_ids:
                    - rw1:p:5b3e7ec49df769e8:s:work
                  policy:
                    policy_id: B3-DEV-TEST-ONLY-OVERLAP
                    policy_version: 1
                    method_id: PERCENT-BENCHMARK-SPEED
                    method_version: 1
                    benchmark_eligibility:
                      cohort_completed_tests_eligible: false
                      manual_completed_tests_eligible: true
                      external_completed_tests_eligible: false
                    freshness_local_civil_days: 90
                    minimum_speed_basis_points: 9000
                    maximum_speed_basis_points: 10000
                    display_rounding:
                      increment_milliseconds_per_kilometre: 1000
                      direction: nearest
          - slot_key: W1D1S2-PACE-UNAVAILABLE''',
    );
    final compiled = const PlanPackageCompiler().compile(overlappingYaml);
    expect(
      compiled.isValid,
      isTrue,
      reason: 'This documents the unresolved canonical overlap gap.',
    );
    final publication = Map<String, dynamic>.from(
      jsonDecode(exact.publicationJson!) as Map,
    )..['source_package_hash'] = compiled.contentHashSha256;
    final programme = workspace().projector.projectBundle(
      ProgrammeReviewSourceBundle(
        spec: exact.spec,
        planPackageYaml: overlappingYaml,
        publicationJson: jsonEncode(publication),
        reviewedProtocolGraphJson: exact.reviewedProtocolGraphJson,
      ),
    );
    final first = programme.weeks.single.days.single.sessions.first;
    expect(
      first.structuredRunning!.status,
      ProgrammeReviewRunningStatus.invalidBinding,
    );
    expect(
      first.findings.map((item) => item.code),
      contains('overlapping_advisory_scope'),
    );
  });

  testWidgets(
    'coach review shows structure and explicit hypothetical calculation',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProgrammeStudioApp(
          catalog: catalog(),
          showDeveloperFixtures: true,
          initialSelection: const ProgrammeStudioSelection(
            catalogId: 'b3-device-validation-v1',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionKey: 'SES-B3-DEVICE-VALIDATION',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ProgrammeStudioCopy.structuredRun), findsOneWidget);
      expect(
        find.text(ProgrammeStudioCopy.verifiedStructuredRun),
        findsOneWidget,
      );
      expect(find.text('Repeat 3 times'), findsOneWidget);
      expect(find.textContaining('Work · 20 seconds'), findsOneWidget);
      expect(find.textContaining('Recovery · 15 seconds'), findsOneWidget);
      expect(find.text('Final recovery is included.'), findsOneWidget);
      expect(find.text('Scope: Work step 1'), findsOneWidget);
      expect(find.textContaining('90%–100%'), findsOneWidget);
      expect(
        find.text(ProgrammeStudioCopy.paceTargetUnavailable),
        findsOneWidget,
      );
      expect(find.textContaining('rw1:p:'), findsNothing);

      await tester.ensureVisible(
        find.text(ProgrammeStudioCopy.hypotheticalPreview),
      );
      await tester.tap(find.text(ProgrammeStudioCopy.hypotheticalPreview));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('If an eligible 5 km result were'),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), '22:00');
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'If an eligible 5 km result were 22:00, this authored policy would display 4:24/km–4:53/km.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(ProgrammeStudioCopy.hypotheticalSeparation),
        findsOneWidget,
      );
    },
  );

  for (final layout in <({String name, Size size, double textScale})>[
    (name: 'short desktop', size: const Size(1440, 720), textScale: 1),
    (name: 'narrow', size: const Size(520, 640), textScale: 1),
    (name: 'large text', size: const Size(520, 640), textScale: 1.7),
  ]) {
    testWidgets(
      '${layout.name} can scroll through policy and hypothetical controls',
      (tester) async {
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: layout.size,
              textScaler: TextScaler.linear(layout.textScale),
            ),
            child: ProgrammeStudioApp(
              catalog: catalog(),
              showDeveloperFixtures: true,
              initialSelection: const ProgrammeStudioSelection(
                catalogId: 'b3-device-validation-v1',
                weekNumber: 1,
                dayKey: 'day_1',
                sessionKey: 'SES-B3-DEVICE-VALIDATION',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final hypothetical = find.text(ProgrammeStudioCopy.hypotheticalPreview);
        await tester.ensureVisible(hypothetical);
        await tester.pumpAndSettle();
        expect(hypothetical, findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(hypothetical);
        await tester.pumpAndSettle();
        final input = find.byType(TextField);
        await tester.ensureVisible(input);
        await tester.enterText(input, '22:00');
        await tester.pumpAndSettle();
        final separation = find.text(
          ProgrammeStudioCopy.hypotheticalSeparation,
        );
        await tester.ensureVisible(separation);
        await tester.pumpAndSettle();
        expect(separation, findsOneWidget);
        expect(find.textContaining('4:24/km–4:53/km'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('technical IDs remain behind Technical Integrity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProgrammeStudioApp(
        catalog: catalog(),
        showDeveloperFixtures: true,
        initialSelection: const ProgrammeStudioSelection(
          catalogId: 'b3-device-validation-v1',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionKey: 'SES-B3-DEVICE-VALIDATION',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('91dac4'), findsNothing);
    await tester.tap(find.text(ProgrammeStudioCopy.technicalIntegrity));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Structured running evidence'));
    await tester.pumpAndSettle();
    expect(find.textContaining('91dac4'), findsOneWidget);
    expect(find.textContaining('rw1:p:5b3e7ec49df769e8'), findsOneWidget);
  });
}
