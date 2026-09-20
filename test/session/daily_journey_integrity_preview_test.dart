import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_integrity_preview_catalog.dart';
import 'package:cohort_platform/features/session/presentation/production_restore_athlete_copy.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/main_daily_journey_integrity_preview.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scenarios = dailyJourneyIntegrityPreviewScenarios();

  test('each selector maps to its claimed resolver outcome', () {
    expect(scenarios, hasLength(18));
    for (final scenario in scenarios) {
      scenario.assertConsistent();
      if (scenario.state == DailyJourneyIntegrityPreviewState.unsafeLegacy) {
        continue;
      }
      expect(
        scenario.decision().outcome,
        scenario.expectedOutcome,
        reason: scenario.label,
      );
    }
  });

  test('stale states cannot report resumable', () {
    for (final scenario in scenarios.where(
      (item) =>
          item.state == DailyJourneyIntegrityPreviewState.staleOccurrence ||
          item.state == DailyJourneyIntegrityPreviewState.staleVersion,
    )) {
      expect(scenario.decision().outcome, isNot(ProductionRestoreOutcome.resumable));
      expect(
        ProductionRestoreAthleteCopyGuards.staleMayNotResume(
          scenario.decision().outcome,
        ),
        isTrue,
      );
    }
  });

  test('corrupt and unsupported versions fail closed', () {
    final corrupt = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.corruptDraft,
    );
    final unsupported = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.unsupportedDraft,
    );
    expect(corrupt.decision().outcome, ProductionRestoreOutcome.corrupt);
    expect(
      unsupported.decision().outcome,
      ProductionRestoreOutcome.unsupportedVersion,
    );
    expect(corrupt.decision().mayBeginFresh, isFalse);
    expect(unsupported.decision().mayBeginFresh, isFalse);
  });

  test('foreign-athlete copy does not claim sign-in is required', () {
    final decision = const ProductionRestoreResolver().resolve(
      restoreRequest(DailyJourneyIntegrityPreviewState.foreignAthlete),
    );
    expect(decision.athleteMessage, isNot(contains('Sign in required')));
    expect(
      decision.athleteMessage,
      ProductionRestoreAthleteCopy.foreignAthleteTitle,
    );
  });

  test('completion retry preserves the same idempotency identity', () {
    const key = 'finish-4-preview-frozen';
    expect(key, startsWith('finish-4-'));
    expect(key, isNot(contains(DateTime.now().toIso8601String())));
  });

  testWidgets('preview selector, blocked actions and format surfaces', (
    tester,
  ) async {
    Future<void> show(DailyJourneyIntegrityPreviewState state) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        DailyJourneyIntegrityPreviewApp(initialState: state),
      );
      await tester.pump();
      await tester.pump();
    }

    await show(DailyJourneyIntegrityPreviewState.noDraft);
    expect(find.text('PREVIEW ONLY'), findsOneWidget);
    expect(find.text('1 No draft — Begin'), findsOneWidget);
    expect(find.text('Begin'), findsWidgets);
    expect(find.text('Preview resolver: noDraft'), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.strengthResume);
    expect(find.text('Couldn’t load previous performance'), findsNothing);
    expect(find.text('Back squat'), findsWidgets);
    expect(
      find.text('First recorded performance').evaluate().isNotEmpty ||
          find.text('Loading previous performance…').evaluate().isEmpty,
      isTrue,
    );

    await show(DailyJourneyIntegrityPreviewState.intervalResume);
    expect(find.text('Intervals'), findsWidgets);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsOneWidget);
    expect(find.text('ROUND 4 OF 8'), findsOneWidget);
    expect(find.text('EMOM'), findsNothing);

    await show(DailyJourneyIntegrityPreviewState.emomResume);
    expect(find.text('EMOM'), findsWidgets);
    expect(find.text('MINUTE 4 OF 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('block-timer-current-station')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.circuitResume);
    expect(find.textContaining('CIRCUIT PERFORMANCE'), findsOneWidget);
    expect(find.textContaining('Circuit ended early'), findsOneWidget);
    expect(find.text('Kettlebell swing'), findsWidgets);
    expect(find.textContaining('MINUTE'), findsNothing);
    expect(find.text('EMOM'), findsNothing);

    await show(DailyJourneyIntegrityPreviewState.forTimeResume);
    expect(find.text('Elapsed seconds'), findsOneWidget);
    expect(find.text('412'), findsWidgets);
    expect(find.text('EMOM'), findsNothing);

    await show(DailyJourneyIntegrityPreviewState.amrapResume);
    expect(find.text('AMRAP'), findsWidgets);
    expect(find.byKey(const ValueKey('block-timer-clock')), findsOneWidget);
    expect(find.text('EMOM'), findsNothing);

    await show(DailyJourneyIntegrityPreviewState.legacyPartial);
    expect(find.text(ProductionRestoreAthleteCopy.continueSafely), findsOneWidget);
    expect(find.text('Preview resolver: legacyPartiallyRecoverable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('restore-continue-safely')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(DailyJourneyIntegrityPreviewApp), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.unsafeLegacy);
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);
    expect(find.text(ProductionRestoreAthleteCopy.unsafeLegacyTitle), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.staleOccurrence);
    expect(find.text('Preview resolver: staleOccurrence'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-open-calendar')), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.staleVersion);
    expect(find.text('Preview resolver: staleProgrammeVersion'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);

    await show(DailyJourneyIntegrityPreviewState.foreignAthlete);
    expect(find.text('Sign in required'), findsNothing);
    expect(
      find.text(ProductionRestoreAthleteCopy.foreignAthleteTitle),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.corruptDraft);
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-discard-draft')), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.unsupportedDraft);
    expect(find.text('Preview resolver: unsupportedVersion'), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.completionPending);
    expect(find.byKey(const ValueKey('completion-pending-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-pending-return')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('completion-pending-idempotency')),
      findsOneWidget,
    );

    await show(DailyJourneyIntegrityPreviewState.structuredRecovery);
    expect(find.text('Recovery'), findsWidgets);
    expect(find.text('Full-body mobility'), findsOneWidget);
    expect(find.text('Begin'), findsWidgets);

    await show(DailyJourneyIntegrityPreviewState.guidanceRest);
    expect(find.text('Rest day'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.byKey(const ValueKey('rest-day-next-session')), findsOneWidget);
    expect(find.textContaining('guidanceOnly'), findsNothing);
    expect(find.textContaining('ProductionRecovery'), findsNothing);
  });

  testWidgets('blocked states never create a training session', (tester) async {
    for (final state in [
      DailyJourneyIntegrityPreviewState.unsafeLegacy,
      DailyJourneyIntegrityPreviewState.staleOccurrence,
      DailyJourneyIntegrityPreviewState.corruptDraft,
      DailyJourneyIntegrityPreviewState.unsupportedDraft,
      DailyJourneyIntegrityPreviewState.foreignAthlete,
    ]) {
      await tester.pumpWidget(
        DailyJourneyIntegrityPreviewApp(initialState: state),
      );
      await tester.pump();
      expect(find.text('Finish Session'), findsNothing);
    }
  });

  testWidgets('narrow width and larger text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const DailyJourneyIntegrityPreviewApp(
        initialState: DailyJourneyIntegrityPreviewState.staleOccurrence,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('preview-state-selector')), findsOneWidget);
    expect(
      find.text(ProductionRestoreAthleteCopy.staleOccurrenceTitle),
      findsOneWidget,
    );
    expect(find.text(ProductionRestoreAthleteCopy.returnHome), findsWidgets);
  });

  test('circuit for-time and AMRAP plans are not EMOM', () {
    expect(previewCircuitPlan().blocks.first.workoutFormat, WorkoutFormat.rounds);
    expect(previewForTimePlan().blocks.first.workoutFormat, WorkoutFormat.forTime);
    expect(previewAmrapPlan().blocks.first.workoutFormat, WorkoutFormat.amrap);
    expect(previewEmomPlan().blocks.first.workoutFormat, WorkoutFormat.emom);
    expect(previewIntervalPlan().blocks.first.workoutFormat, WorkoutFormat.intervals);
  });
}
