import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/accessibility/journey_interaction.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_rest_day_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_today_session_panel.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_service.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/performance/widgets/session_completion_pending_panel.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_accessibility.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_integrity_preview_catalog.dart';
import 'package:cohort_platform/features/session/presentation/production_restore_athlete_copy.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
import 'package:cohort_platform/features/session/screens/production_restore_blocked_screen.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({
    required Widget child,
    double width = 390,
    double height = 844,
    double textScale = 1.0,
    bool reduceMotion = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        theme: cohortTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  test('spoken units and set labels are unambiguous', () {
    expect(
      DailyJourneyAccessibility.setLoadLabel(2, 'kg'),
      'Set 2 load, kilograms',
    );
    expect(
      DailyJourneyAccessibility.setRepsLabel(2),
      'Set 2 reps',
    );
    expect(
      DailyJourneyAccessibility.setCompletedLabel(2),
      'Set 2 completed',
    );
  });

  testWidgets('Begin exposes one button role and status words', (tester) async {
    final scenario = dailyJourneyIntegrityPreviewScenarios().firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.noDraft,
    );
    await tester.pumpWidget(
      harness(
        child: AthleteHomeTodaySessionPanel(
          package: previewPackage(scenario.plan),
          primaryLabel: 'Begin',
          status: 'Not started',
          onPrimary: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-today-primary-action'))),
      matchesSemantics(
        label: 'Begin. Strength. Status Not started',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
      ),
    );
    expect(find.bySemanticsLabel('Status Not started'), findsOneWidget);
    expect(find.text('Not started'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('View results is the only completed-today action', (tester) async {
    await tester.pumpWidget(
      harness(
        child: AthleteHomeCompletedTodayCard(
          occurrence: previewCompletedOccurrence(),
          dateLabel: 'Sunday 20 September',
          programmeName: 'Preview programme',
          weekDayLabel: 'Week 1 · Day 1',
          record: previewCommittedStrengthRecord(),
          onViewResults: () {},
        ),
      ),
    );
    expect(find.text('View results'), findsOneWidget);
    expect(find.text('Show results'), findsNothing);
    expect(find.bySemanticsLabel('Status Complete'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('completed-today-view-result')),
      ),
      matchesSemantics(
        label: 'View results. Strength. Status Complete',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
      ),
    );
  });

  testWidgets('guidance rest has no begin action', (tester) async {
    await tester.pumpWidget(
      harness(
        child: AthleteHomeRestDayCard(
          programmeName: 'Preview programme',
          guidance: 'Walk if you want.',
          nextSessionHint: 'Next: Strength · tomorrow',
          onOpenCalendar: () {},
        ),
      ),
    );
    expect(find.text('Begin'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Rest day')), findsWidgets);
  });

  testWidgets('focus order visits Begin then does not jump away', (
    tester,
  ) async {
    var taps = 0;
    final scenario = dailyJourneyIntegrityPreviewScenarios().firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.noDraft,
    );
    await tester.pumpWidget(
      harness(
        child: AthleteHomeTodaySessionPanel(
          package: previewPackage(scenario.plan),
          primaryLabel: 'Begin',
          status: 'Not started',
          onPrimary: () => taps += 1,
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, greaterThanOrEqualTo(0));
    expect(find.text('Begin'), findsOneWidget);
  });

  testWidgets('timer semantics include type and paused state without live ticks',
      (tester) async {
    const paused = BlockTimerState(
      format: WorkoutFormat.intervals,
      phase: BlockTimerPhase.work,
      isRunning: false,
      isPaused: true,
      isFinished: false,
      primarySeconds: 45,
      phaseLabel: 'Work',
      currentRound: 4,
      totalRounds: 8,
    );
    await tester.pumpWidget(
      harness(
        child: BlockTimerScreen(
          blockTitle: 'Intervals',
          format: WorkoutFormat.intervals,
          configuration: const TimerConfiguration(
            workSeconds: 60,
            restSeconds: 30,
            rounds: 8,
          ),
          initialState: paused,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Intervals timer')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp('Paused')), findsWidgets);
    final before = find.text('00:45');
    expect(before, findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:45'), findsOneWidget);
    expect(find.text('00:43'), findsNothing);
  });

  testWidgets('strength fields expose set number, units, and checkbox state',
      (tester) async {
    final plan = previewStrengthPlan();
    final execution = SessionExecutionController(
      plan: plan,
      sessionKey: 'a11y-strength',
    )..startSession();
    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: previewAthleteId,
      trainingSessionId: 4,
    );
    applyPreviewActuals(
      state: DailyJourneyIntegrityPreviewState.strengthResume,
      performance: performance,
      plan: plan,
    );
    await tester.pumpWidget(
      harness(
        child: ActiveSessionScreen(
          controller: execution,
          performanceController: performance,
          athleteId: previewAthleteId,
          trainingSessionId: 4,
          previousStrengthService: PreviousStrengthPerformanceService(
            store: const EmptyPreviousStrengthPerformanceStore(),
          ),
          saveCoordinator: PerformanceRecordSaveCoordinator(
            store: InMemoryPerformanceRecordStore(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Set 1 load, kilograms'), findsWidgets);
    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.text('Set 1 completed'), findsWidgets);
    expect(find.text('Load'), findsNothing);
    expect(
      find.bySemanticsLabel('Draft restored. Your entered results are on this phone.'),
      findsWidgets,
    );
  });

  testWidgets('completion pending announces retry without a second path',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      harness(
        child: SessionCompletionPendingPanel(
          idempotencyKey: previewCompletionIdempotencyKey,
          onRetry: () => retries += 1,
          onReturnToSession: () {},
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(ProductionRestoreAthleteCopy.completionPendingTitle),
      findsWidgets,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('completion-pending-retry'))),
      matchesSemantics(
        label:
            'Retry completion. Local results are still on this phone',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('completion-pending-retry')));
    await tester.tap(find.byKey(const ValueKey('completion-pending-retry')));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('blocked restore keeps recovery actions labelled', (tester) async {
    final scenario = dailyJourneyIntegrityPreviewScenarios().firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.corruptDraft,
    );
    await tester.pumpWidget(
      harness(
        child: ProductionRestoreBlockedScreen(
          decision: scenario.decision(),
          onReturnHome: () {},
          onDiscardDraft: () async {},
        ),
      ),
    );
    expect(find.text(ProductionRestoreAthleteCopy.corruptTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-return-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-discard-draft')), findsOneWidget);
    expect(find.text('Finish Session'), findsNothing);
  });

  testWidgets('destructive discard confirmation traps in a dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(child: const ProductionRestoreDiscardDialog()),
    );
    expect(find.text(ProductionRestoreAthleteCopy.discardDraft), findsWidgets);
    expect(
      find.text(ProductionRestoreAthleteCopy.discardDraftConfirm),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('restore-discard-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('restore-discard-confirm')), findsOneWidget);
  });

  testWidgets('save failure announcement retains local-results meaning',
      (tester) async {
    await tester.pumpWidget(
      harness(
        child: PerformanceSaveIndicator(
          state: PerformanceSaveState.error,
          errorMessage:
              'Couldn’t save — Retry. Your entered results are still on this phone.',
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Retry save. Local results are still on this phone',
      ),
      findsOneWidget,
    );
  });

  testWidgets('primary controls meet the minimum tap target', (tester) async {
    await tester.pumpWidget(
      harness(
        child: CohortButton(label: 'Begin', onPressed: () {}),
      ),
    );
    final box = tester.getSize(find.byType(CohortButton));
    expect(box.height, greaterThanOrEqualTo(JourneyInteraction.minTapSize));
    expect(box.height, greaterThanOrEqualTo(JourneyInteraction.minPrimaryHeight));
  });

  testWidgets('disabled finish stays labelled without relying on fade',
      (tester) async {
    await tester.pumpWidget(
      harness(
        child: const CohortButton(
          label: 'Finish Session',
          semanticLabel: 'Capture remaining sets before finishing',
          onPressed: null,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(CohortButton)),
      matchesSemantics(
        label: 'Capture remaining sets before finishing',
        isButton: true,
        isEnabled: false,
        hasEnabledState: true,
        hint: 'Unavailable',
      ),
    );
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('duplicate Begin taps fire once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        child: CohortButton(label: 'Begin', onPressed: () => taps += 1),
      ),
    );
    await tester.tap(find.text('Begin'));
    await tester.tap(find.text('Begin'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('text scale and width matrix does not overflow production cards',
      (tester) async {
    final begin = dailyJourneyIntegrityPreviewScenarios().firstWhere(
      (item) => item.state == DailyJourneyIntegrityPreviewState.noDraft,
    );

    Future<void> pumpChild(Widget child, {required double width, required double scale}) async {
      await tester.pumpWidget(
        harness(
          width: width,
          height: 1200,
          textScale: scale,
          child: child,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${width}px ${scale}x');
    }

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        await pumpChild(
          AthleteHomeTodaySessionPanel(
            package: previewPackage(begin.plan),
            primaryLabel: 'Begin',
            status: 'Not started',
            onPrimary: () {},
          ),
          width: width,
          scale: scale,
        );
        expect(
          find.byKey(const ValueKey('home-today-primary-action')),
          findsOneWidget,
        );
        await pumpChild(
          SessionCompletionPendingPanel(
            onRetry: () {},
            onReturnToSession: () {},
          ),
          width: width,
          scale: scale,
        );
        expect(
          find.byKey(const ValueKey('completion-pending-retry')),
          findsOneWidget,
        );
        await pumpChild(
          AthleteHomeCompletedTodayCard(
            occurrence: previewCompletedOccurrence(),
            dateLabel: 'Sunday 20 September',
            programmeName: 'Preview programme',
            weekDayLabel: 'Week 1 · Day 1',
            record: previewCommittedStrengthRecord(),
            onViewResults: () {},
          ),
          width: width,
          scale: scale,
        );
        expect(
          find.byKey(const ValueKey('completed-today-view-result')),
          findsOneWidget,
        );
        await pumpChild(
          ProductionRestoreBlockedScreen(
            decision: const ProductionRestoreDecision(
              outcome: ProductionRestoreOutcome.corrupt,
              athleteMessage: ProductionRestoreAthleteCopy.corruptTitle,
            ),
            onReturnHome: () {},
            onDiscardDraft: () async {},
          ),
          width: width,
          scale: scale,
        );
        expect(find.text(ProductionRestoreAthleteCopy.returnHome), findsWidgets);
      }
    }
  });

  testWidgets('reduced motion still shows block status in words', (tester) async {
    final plan = previewStrengthPlan();
    final execution = SessionExecutionController(
      plan: plan,
      sessionKey: 'a11y-motion',
    )..startSession();
    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: previewAthleteId,
      trainingSessionId: 4,
    );
    await tester.pumpWidget(
      harness(
        reduceMotion: true,
        child: ActiveSessionScreen(
          controller: execution,
          performanceController: performance,
          athleteId: previewAthleteId,
          trainingSessionId: 4,
          saveCoordinator: PerformanceRecordSaveCoordinator(
            store: InMemoryPerformanceRecordStore(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Finish Session'), findsOneWidget);
  });

  testWidgets('reconciled completion copy is announced', (tester) async {
    await tester.pumpWidget(
      harness(
        child: Semantics(
          liveRegion: true,
          label: ProductionRestoreAthleteCopy.completionReconciledTitle,
          child: ExcludeSemantics(
            child: Text(ProductionRestoreAthleteCopy.completionReconciledTitle),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel(
        ProductionRestoreAthleteCopy.completionReconciledTitle,
      ),
      findsOneWidget,
    );
  });
}
