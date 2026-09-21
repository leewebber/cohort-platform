import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
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
    expect(scenarios, hasLength(19));
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
    expect(previewCompletionIdempotencyKey, startsWith('finish-4-'));
    expect(
      previewCompletionIdempotencyKey,
      isNot(contains(DateTime.now().toIso8601String())),
    );
  });

  test('reconciliation finds one committed record for the same identity', () {
    final committed = previewCommittedStrengthRecord();
    final found = previewFindCommittedCompletion(
      hostedRecords: [committed],
      athleteId: previewAthleteId,
      trainingSessionId: 4,
      idempotencyKey: previewCompletionIdempotencyKey,
    );
    expect(found.recordId, committed.recordId);
    expect(found.trainingSessionId, 4);
    expect(found.status.name, 'completed');
    expect(
      () => previewFindCommittedCompletion(
        hostedRecords: [committed, committed],
        athleteId: previewAthleteId,
        trainingSessionId: 4,
        idempotencyKey: previewCompletionIdempotencyKey,
      ),
      throwsStateError,
    );
    expect(
      () => previewFindCommittedCompletion(
        hostedRecords: [committed],
        athleteId: previewAthleteId,
        trainingSessionId: 4,
        idempotencyKey: 'finish-4-new-key',
      ),
      throwsStateError,
    );
  });

  test('reconciled request has cleared local draft and hosted completion', () {
    final pending = restoreRequest(
      DailyJourneyIntegrityPreviewState.completionPending,
    );
    final reconciled = restoreRequest(
      DailyJourneyIntegrityPreviewState.completionReconciled,
    );
    expect(pending.actuals, isNotNull);
    expect(pending.hostedCompleted, isFalse);
    expect(reconciled.hostedCompleted, isTrue);
    expect(reconciled.actuals, isNull);
    expect(reconciled.persistedIdentity, isNull);
    expect(reconciled.cursor, isNull);
    expect(
      const ProductionRestoreResolver().resolve(reconciled).outcome,
      ProductionRestoreOutcome.completedHosted,
    );
  });

  test('reconciled result summary uses the committed record', () {
    final record = previewCommittedStrengthRecord();
    expect(record.sessionSnapshot.sessionTitle, 'Strength');
    expect(record.trainingSessionId, 4);
    expect(record.athleteId, previewAthleteId);
    expect(record.overallRpe, 7);
    expect(record.startedAt, DateTime.utc(2026, 9, 20, 10, 0));
    expect(record.completedAt, DateTime.utc(2026, 9, 20, 10, 45));
    expect(record.durationSeconds, 45 * 60);
    final sets = record.blockResults.single.exerciseResults.single.setResults;
    expect(sets, hasLength(3));
    expect(sets.first.reps, 5);
    expect(sets.first.load, 60);
  });

  test('production-facing reconciled copy has no technical language', () {
    const forbidden = [
      'idempotency',
      'RPC',
      'resolver',
      'payload',
      'Supabase',
      'hosted reconciliation',
      'cursor',
    ];
    final copy = [
      ProductionRestoreAthleteCopy.completionPendingTitle,
      ProductionRestoreAthleteCopy.completionPendingBody,
      ProductionRestoreAthleteCopy.completionReconciledTitle,
      ProductionRestoreAthleteCopy.completionReconciledBody,
    ].join(' ');
    for (final term in forbidden) {
      expect(copy.toLowerCase(), isNot(contains(term.toLowerCase())));
    }
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
    expect(find.text('For Time'), findsWidgets);
    expect(find.text('21-15-9 For Time'), findsOneWidget);
    expect(find.text('21 thrusters, 21 pull-ups'), findsOneWidget);
    expect(find.text('2 reps left'), findsOneWidget);
    expect(find.text('06:52'), findsOneWidget);
    expect(find.text('Resume'), findsWidgets);
    expect(find.text('Record time'), findsOneWidget);
    expect(find.text('Start timer'), findsNothing);
    expect(find.text('Rounds'), findsNothing);
    expect(find.text('Circuit'), findsNothing);
    expect(find.text('Three-station circuit'), findsNothing);
    expect(find.text('3 rounds'), findsNothing);
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
    expect(find.text(ProductionRestoreAthleteCopy.retry), findsOneWidget);

    await show(DailyJourneyIntegrityPreviewState.completionReconciled);
    expect(
      find.text(ProductionRestoreAthleteCopy.completionReconciledTitle),
      findsOneWidget,
    );
    expect(find.text('Strength'), findsWidgets);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.byType(AthleteHomeCompletedTodayCard), findsOneWidget);
    expect(find.textContaining('Duration 45m 00s'), findsOneWidget);
    expect(find.textContaining('Duration -'), findsNothing);
    expect(find.text('View results'), findsOneWidget);
    expect(find.text('Show results'), findsNothing);
    expect(find.text(ProductionRestoreAthleteCopy.retry), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Save and finish'), findsNothing);
    expect(find.text('Finish Session'), findsNothing);
    expect(find.textContaining('idempotency'), findsNothing);
    expect(find.textContaining('RPC'), findsNothing);

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

  test('for-time selector creates a canonical for-time plan', () {
    final forTime = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.forTimeResume,
    );
    final circuit = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.circuitResume,
    );
    forTime.assertConsistent();
    circuit.assertConsistent();
    expect(forTime.plan.sessionId, 'fortime');
    expect(forTime.plan.sessionTitle, '21-15-9 For Time');
    expect(forTime.plan.blocks.first.workoutFormat, WorkoutFormat.forTime);
    expect(forTime.plan.blocks.first.workoutFormatLabel, 'For Time');
    expect(forTime.format, WorkoutFormat.forTime);
    expect(forTime.openRestoredTimer, isTrue);
    expect(circuit.plan.sessionId, 'circuit');
    expect(circuit.plan.blocks.first.workoutFormat, WorkoutFormat.rounds);
    expect(circuit.format, WorkoutFormat.rounds);
    expect(forTime.plan.sessionId, isNot(circuit.plan.sessionId));
    expect(forTime.format, isNot(circuit.format));
    expect(
      forTime.plan.blocks.first.workoutFormat,
      isNot(circuit.plan.blocks.first.workoutFormat),
    );
  });

  test('preview-only relabelling cannot make a circuit fixture claim for-time', () {
    final circuit = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.circuitResume,
    );
    expect(
      () => DailyJourneyIntegrityPreviewScenario(
        state: circuit.state,
        label: '7 Relabelled circuit',
        expectedOutcome: circuit.expectedOutcome,
        kind: circuit.kind,
        plan: circuit.plan,
        format: WorkoutFormat.forTime,
      ).assertConsistent(),
      throwsStateError,
    );
  });

  test('for-time actuals and session identity survive restore', () {
    final scenario = scenarios.firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.forTimeResume,
    );
    final request = restoreRequest(scenario.state);
    expect(request.trainingSessionId, 4);
    expect(request.programmedSessionKey, previewSessionKey);
    expect(request.persistedIdentity?.trainingSessionId, 4);
    expect(request.actuals?.trainingSessionId, 4);
    expect(request.actuals?.recordId, 'preview-record');

    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: scenario.plan,
      athleteId: previewAthleteId,
      trainingSessionId: 4,
    );
    applyPreviewActuals(
      state: scenario.state,
      performance: performance,
      plan: scenario.plan,
    );
    final result =
        performance.draft.blockDrafts.first.resultData as ForTimeResultData;
    expect(performance.draft.trainingSessionId, 4);
    expect(performance.draft.athleteId, previewAthleteId);
    expect(performance.draft.recordId, isNotEmpty);
    expect(result.elapsedSeconds, 412);
    expect(result.remainingWorkNote, '2 reps left');
    expect(result.runtimeType, isNot(CircuitResultData));
  });

  testWidgets('pending Retry transitions to reconciled completion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const DailyJourneyIntegrityPreviewApp(
        initialState: DailyJourneyIntegrityPreviewState.completionPending,
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('completion-pending-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completion-pending-retry')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('17 Completion reconciled — already saved'),
      findsOneWidget,
    );
    expect(
      find.text(ProductionRestoreAthleteCopy.completionReconciledTitle),
      findsOneWidget,
    );
    expect(find.byType(AthleteHomeCompletedTodayCard), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.textContaining('Duration 45m 00s'), findsOneWidget);
    expect(find.textContaining('Duration -'), findsNothing);
    expect(find.byKey(const ValueKey('completion-pending-retry')), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Begin'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('completed-today-view-result')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('completed-today-view-result')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CompletedSessionResultView), findsOneWidget);
    expect(find.text('COMPLETED SESSION'), findsOneWidget);
    expect(find.text('Strength'), findsWidgets);
    expect(
      find.text(ProductionRestoreAthleteCopy.completionReconciledTitle),
      findsWidgets,
    );
  });

  testWidgets('reconciled Home stays valid on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const DailyJourneyIntegrityPreviewApp(
        initialState: DailyJourneyIntegrityPreviewState.completionReconciled,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.textContaining('Duration 45m 00s'), findsOneWidget);
    expect(find.textContaining('Duration -'), findsNothing);
    expect(
      tester.getSemantics(find.text('Complete')).label,
      contains('Complete'),
    );
    expect(find.text('View results'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('selector remounts for-time after circuit', (tester) async {
    await tester.pumpWidget(
      const DailyJourneyIntegrityPreviewApp(
        initialState: DailyJourneyIntegrityPreviewState.circuitResume,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('CIRCUIT PERFORMANCE'), findsOneWidget);
    expect(find.text('Rounds'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('preview-state-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 Resumed for-time').last);
    await tester.pumpAndSettle();

    expect(find.text('For Time'), findsWidgets);
    expect(find.text('06:52'), findsOneWidget);
    expect(find.text('Resume'), findsWidgets);
    expect(find.text('Start timer'), findsNothing);
    expect(find.text('Rounds'), findsNothing);
    expect(find.text('Circuit'), findsNothing);
    expect(find.textContaining('CIRCUIT PERFORMANCE'), findsNothing);
    expect(find.text('2 reps left'), findsOneWidget);
  });
}
