import 'dart:io';

import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_controller.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_copy.dart';
import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_quality.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProgrammeReviewCatalog catalog() {
    return ProgrammeReviewWorkspace(
      readAsset: (path) => File(path).readAsStringSync(),
    ).loadRealCatalog();
  }

  ProgrammeReviewProgramme bali() {
    return catalog().programmes.singleWhere(
      (item) => item.catalogId == 'bali-hybrid-base-v1',
    );
  }

  Future<void> setDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('Bali review projection keeps 71 sessions and AM/PM', () {
    final programme = bali();
    expect(programme.classification, ProgrammeReviewClassification.internalPrivate);
    expect(programme.libraryScope, 'coachPrivate');
    expect(programme.durationWeeks, 8);
    expect(programme.weeks, hasLength(8));
    final sessions = programme.weeks
        .expand((week) => week.days)
        .expand((day) => day.sessions)
        .toList();
    expect(sessions, hasLength(71));
    expect(sessions.every((session) => session.bodiesResolved), isTrue);
    final sunday = programme.weeks.first.days.singleWhere(
      (day) => day.dayOrder == 2,
    );
    expect(sunday.sessions, hasLength(2));
    expect(sunday.sessions.first.timeOfDay, 'morning');
    expect(sunday.sessions.last.timeOfDay, 'afternoon');
    expect(programme.weeks.last.days.map((day) => day.dayOrder), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
    ]);
  });

  test('Bali quality gate is honest', () {
    final report = buildStudioQualityReport(bali());
    expect(report.technicallyValid, isTrue);
    expect(report.launchApproved, isFalse);
    StudioQualityItem item(String id) {
      return report.groups
          .expand((group) => group.items)
          .singleWhere((entry) => entry.id == id);
    }

    expect(item('session_count_71').status, StudioQualityStatus.passed);
    expect(item('same_day_ampm').status, StudioQualityStatus.passed);
    expect(item('spillover_retained').status, StudioQualityStatus.passed);
    expect(item('private_classification').status, StudioQualityStatus.passed);
    expect(item('source_fidelity').status, StudioQualityStatus.passed);
    expect(item('coaching_approval').status, StudioQualityStatus.notAssessed);
    expect(item('metrics_profile').status, StudioQualityStatus.notImplemented);
    expect(item('pace_calculation').status, StudioQualityStatus.notImplemented);
    expect(item('device_garmin').status, StudioQualityStatus.notImplemented);
    expect(item('lee_assignment').status, StudioQualityStatus.notAssessed);
    expect(item('hosted_private_publication').status, StudioQualityStatus.notAssessed);
  });

  testWidgets('defaults to Bali Week 1 Saturday Strength A', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(ProgrammeStudioApp(catalog: catalog()));
    await tester.pumpAndSettle();
    expect(find.text('Bali Hybrid Base'), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.baliSessionCount), findsWidgets);
    expect(find.text(ProgrammeStudioCopy.baliNoRunning), findsOneWidget);
    expect(find.textContaining('Week 1 of 8'), findsWidgets);
    expect(find.textContaining('Strength A — Heavy Lower + Pull'), findsWidgets);
    expect(find.text('Front squat'), findsWidgets);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Enrol'), findsNothing);
  });

  testWidgets('shows Sunday AM and PM together', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(
      ProgrammeStudioApp(
        catalog: catalog(),
        initialSelection: const ProgrammeStudioSelection(
          catalogId: 'bali-hybrid-base-v1',
          weekNumber: 1,
          dayKey: 'day_2',
          sessionKey: 'SES-BALI-W01-D02-S01',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('AM · Long Aerobic — BikeErg'), findsWidgets);
    expect(find.textContaining('PM · Strength B — Upper Strength'), findsWidgets);
  });

  testWidgets('shows Week 8 spillover Saturday and Sunday', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(
      ProgrammeStudioApp(
        catalog: catalog(),
        initialSelection: const ProgrammeStudioSelection(
          catalogId: 'bali-hybrid-base-v1',
          weekNumber: 8,
          dayKey: 'day_8',
          sessionKey: 'SES-BALI-W08-D08-S01',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 8 of 8'), findsWidgets);
    expect(find.textContaining('Saturday (spillover)'), findsWidgets);
    expect(find.textContaining('Sunday (spillover)'), findsWidgets);
    expect(find.textContaining('Week 9'), findsNothing);
  });

  testWidgets('manual 2 km Row capture remains visible', (tester) async {
    await setDesktop(tester);
    await tester.pumpWidget(
      ProgrammeStudioApp(
        catalog: catalog(),
        initialSelection: const ProgrammeStudioSelection(
          catalogId: 'bali-hybrid-base-v1',
          weekNumber: 4,
          dayKey: 'day_5',
          sessionKey: 'SES-BALI-W04-D05-S01',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2 km Row'), findsWidgets);
    expect(find.textContaining('Manual'), findsWidgets);
  });
}
