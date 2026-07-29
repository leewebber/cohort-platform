import 'package:cohort_platform/application/athlete_workout/athlete_workout_application.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/workout_execution_record/workout_execution_record_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  const orchestrator = AthleteWorkoutOrchestrator();
  const factory = ProgrammeSessionOccurrenceFactory();
  final date = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 8, 1));
  final t0 = DateTime.utc(2026, 7, 28, 8);

  late ProgrammeSessionOccurrenceRegistry registry;
  late AthleteSessionOccurrenceIndex index;

  setUp(() {
    registry = InMemoryProgrammeSessionOccurrenceRegistry();
    index = AthleteSessionOccurrenceIndex();
  });

  void materialize({String slotId = 'slot-1'}) {
    factory.createFromScheduledSlot(
      input: ProgrammeScheduledSlotInput(
        programmeAssignmentId: 'asgn-1',
        programmeSessionSlotId: slotId,
        athleteId: 'athlete-1',
        sourceSessionId: 'proto-1',
        plannedDate: date,
      ),
      recordedAt: t0,
      registry: registry,
      occurrenceRepository: index,
    );
  }

  AthleteWorkoutResult resolve() {
    return orchestrator.resolveToday(
      athleteId: 'athlete-1',
      date: date,
      occurrenceRepository: index,
    );
  }

  group('AthleteWorkoutOrchestrator', () {
    test('successful workout resolution for planned session', () {
      materialize();
      final result = resolve();
      expect(result.status, AthleteWorkoutResolutionStatus.workoutPlanned);
      expect(result.hasWorkout, isTrue);
      expect(result.occurrenceId, isNotNull);
      expect(result.adaptationAvailable, isTrue);
      expect(result.canStartWorkout, isTrue);
      expect(result.executionSnapshot, isNull);
    });

    test('no workout scheduled', () {
      final result = resolve();
      expect(result.status, AthleteWorkoutResolutionStatus.noWorkoutScheduled);
      expect(result.hasWorkout, isFalse);
      expect(result.adaptationAvailable, isFalse);
    });

    test('adapted workout exposes execution snapshot', () {
      materialize();
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 55,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;
      final planned = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single;
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: planned
            .attachAdaptation(executionSnapshot: snapshot, recordedAt: t0)
            .occurrence!,
      );

      final result = resolve();
      expect(result.status, AthleteWorkoutResolutionStatus.workoutAdapted);
      expect(result.executionSnapshot, isNotNull);
      expect(result.adaptationAvailable, isTrue);
      expect(result.canStartWorkout, isTrue);
    });

    test('completed workout disables start and adaptation flags', () {
      materialize();
      final done = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single
          .startInProgress(recordedAt: t0)
          .occurrence!
          .complete(completedAt: t0)
          .occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: done);

      final result = resolve();
      expect(result.status, AthleteWorkoutResolutionStatus.workoutCompleted);
      expect(result.adaptationAvailable, isFalse);
      expect(result.canStartWorkout, isFalse);
    });

    test('skipped workout', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .skip(recordedAt: t0)
            .occurrence!,
      );
      expect(resolve().status, AthleteWorkoutResolutionStatus.workoutSkipped);
    });

    test('cancelled workout', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .cancel(recordedAt: t0)
            .occurrence!,
      );
      expect(resolve().status, AthleteWorkoutResolutionStatus.workoutCancelled);
    });

    test('in progress workout cannot start again', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .startInProgress(recordedAt: t0)
            .occurrence!,
      );
      final result = resolve();
      expect(result.status, AthleteWorkoutResolutionStatus.workoutInProgress);
      expect(result.canStartWorkout, isFalse);
      expect(result.adaptationAvailable, isFalse);
    });

    test('deterministic for identical inputs', () {
      materialize();
      expect(resolve(), equals(resolve()));
    });

    test('delegates to resolver without reimplementing lookup', () {
      final tracking = _TrackingResolver();
      final custom = AthleteWorkoutOrchestrator(dailySessionResolver: tracking);
      custom.resolveToday(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(tracking.callCount, 1);
    });

    test('capabilities align with aggregate transition guards', () {
      materialize();
      final occurrence = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single;
      expect(AthleteWorkoutCapabilities.canStartWorkout(occurrence), isTrue);
      expect(occurrence.startInProgress(recordedAt: t0).isSuccess, isTrue);
    });
  });

  group('AthleteWorkoutOrchestrator adaptTodayWorkout', () {
    late ProtocolDraft draft;
    late PlannedSessionAdaptationInput plannedInput;

    setUp(() {
      draft = buildTimedPlanningSession(protocolId: 'proto-1');
      plannedInput = timedPlanningInputFromDraft(draft);
    });

    SessionAdaptationCoachDecisionContext context({
      AdaptationConstraintContext constraints =
          const AdaptationConstraintContext(availableDurationMin: 50),
    }) {
      return SessionAdaptationCoachDecisionContext(
        plannedSession: plannedInput,
        constraints: constraints,
      );
    }

    test(
      'successful adaptation attaches snapshot and returns updated workout',
      () {
        materialize();
        final before = index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single;
        final result = orchestrator.adaptTodayWorkout(
          athleteId: 'athlete-1',
          date: date,
          occurrenceRepository: index,
          adaptationContext: context(),
          recordedAt: t0,
          requestId: 'adapt-test-1',
        );

        expect(result.adaptationSucceeded, isTrue);
        expect(result.status, AthleteWorkoutResolutionStatus.workoutAdapted);
        expect(result.executionSnapshot, isNotNull);
        expect(result.canStartWorkout, isTrue);
        expect(
          before.lifecycleState,
          SessionOccurrenceLifecycleState.scheduled,
        );
        expect(before.executionSnapshot, isNull);
        expect(
          index
              .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
              .single,
          result.occurrence,
        );
      },
    );

    test('adaptation unavailable when workout completed', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .startInProgress(recordedAt: t0)
            .occurrence!
            .complete(completedAt: t0)
            .occurrence!,
      );
      final result = orchestrator.adaptTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        adaptationContext: context(),
        recordedAt: t0,
      );
      expect(
        result.adaptationStatus,
        AthleteWorkoutAdaptationStatus.unavailable,
      );
      expect(result.adaptationSucceeded, isFalse);
    });

    test('coach brain failure returns explicit outcome', () {
      materialize();
      final result = orchestrator.adaptTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        adaptationContext: context(
          constraints: const AdaptationConstraintContext(
            availableDurationMin: 20,
          ),
        ),
        recordedAt: t0,
      );
      expect(
        result.adaptationStatus,
        AthleteWorkoutAdaptationStatus.coachBrainFailed,
      );
      expect(result.status, AthleteWorkoutResolutionStatus.workoutPlanned);
    });

    test('source session mismatch rejected', () {
      materialize();
      final wrongDraft = buildTimedPlanningSession(protocolId: 'other-proto');
      final result = orchestrator.adaptTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        adaptationContext: SessionAdaptationCoachDecisionContext(
          plannedSession: timedPlanningInputFromDraft(wrongDraft),
          constraints: const AdaptationConstraintContext(
            availableDurationMin: 50,
          ),
        ),
        recordedAt: t0,
      );
      expect(
        result.adaptationStatus,
        AthleteWorkoutAdaptationStatus.sourceSessionMismatch,
      );
    });

    test('resolveToday behaviour unchanged after adapt path exists', () {
      materialize();
      expect(resolve().adaptationStatus, AthleteWorkoutAdaptationStatus.none);
    });
  });

  group('AthleteWorkoutOrchestrator startTodayWorkout', () {
    AthleteWorkoutResult start() {
      return orchestrator.startTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        startedAt: t0,
      );
    }

    test('successful start from scheduled', () {
      materialize();
      final before = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single;
      final result = start();
      expect(result.startSucceeded, isTrue);
      expect(result.status, AthleteWorkoutResolutionStatus.workoutInProgress);
      expect(result.canStartWorkout, isFalse);
      expect(before.lifecycleState, SessionOccurrenceLifecycleState.scheduled);
      expect(
        index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single,
        result.occurrence,
      );
    });

    test('successful start from adapted preserves execution snapshot', () {
      materialize();
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 55,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;
      final adapted = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single
          .attachAdaptation(executionSnapshot: snapshot, recordedAt: t0)
          .occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: adapted);

      final result = start();
      expect(result.startSucceeded, isTrue);
      expect(result.executionSnapshot, snapshot);
      expect(result.lifecycleState, SessionOccurrenceLifecycleState.inProgress);
    });

    test('original occurrence remains immutable after start', () {
      materialize();
      final before = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single;
      start();
      expect(before.lifecycleState, SessionOccurrenceLifecycleState.scheduled);
    });

    test('already in progress rejected explicitly', () {
      materialize();
      start();
      final again = start();
      expect(again.startStatus, AthleteWorkoutStartStatus.unavailable);
      expect(again.startDetail, 'already_in_progress');
      expect(again.startSucceeded, isFalse);
    });

    test('completed workout start unavailable', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .startInProgress(recordedAt: t0)
            .occurrence!
            .complete(completedAt: t0)
            .occurrence!,
      );
      final result = start();
      expect(result.startStatus, AthleteWorkoutStartStatus.unavailable);
    });

    test('skipped workout start unavailable', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .skip(recordedAt: t0)
            .occurrence!,
      );
      expect(start().startStatus, AthleteWorkoutStartStatus.unavailable);
    });

    test('cancelled workout start unavailable', () {
      materialize();
      index.upsert(
        athleteId: 'athlete-1',
        occurrence: index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single
            .cancel(recordedAt: t0)
            .occurrence!,
      );
      expect(start().startStatus, AthleteWorkoutStartStatus.unavailable);
    });

    test('no workout scheduled', () {
      final result = start();
      expect(result.startStatus, AthleteWorkoutStartStatus.noWorkoutScheduled);
    });

    test('multiple workouts scheduled', () {
      materialize(slotId: 'slot-a');
      materialize(slotId: 'slot-b');
      final result = start();
      expect(
        result.startStatus,
        AthleteWorkoutStartStatus.multipleWorkoutsScheduled,
      );
    });

    test('invalid lookup', () {
      final result = orchestrator.startTodayWorkout(
        athleteId: '  ',
        date: date,
        occurrenceRepository: index,
        startedAt: t0,
      );
      expect(result.startStatus, AthleteWorkoutStartStatus.invalidRequest);
    });

    test('resolveToday startStatus remains none', () {
      materialize();
      expect(resolve().startStatus, AthleteWorkoutStartStatus.none);
    });

    test('adapt workflow unchanged after start path added', () {
      materialize();
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final adapt = orchestrator.adaptTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        adaptationContext: SessionAdaptationCoachDecisionContext(
          plannedSession: timedPlanningInputFromDraft(draft),
          constraints: const AdaptationConstraintContext(
            availableDurationMin: 50,
          ),
        ),
        recordedAt: t0,
        requestId: 'regression-adapt',
      );
      expect(adapt.adaptationSucceeded, isTrue);
    });
  });

  group('AthleteWorkoutOrchestrator completeTodayWorkout', () {
    final tFinish = DateTime.utc(2026, 8, 1, 9);

    List<WorkoutExerciseExecutionEntry> allCompletedOutcomes(
      AdaptedSessionExecutionSnapshot snapshot,
    ) {
      final steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
      return [
        for (final step in steps)
          WorkoutExerciseExecutionEntry(
            sourceBlockLocalId: step.sourceBlockLocalId,
            exerciseLinkLocalId: step.exerciseLinkLocalId,
            exerciseId: snapshot.retainedBlocks
                .firstWhere(
                  (b) => b.sourceBlockLocalId == step.sourceBlockLocalId,
                )
                .exercises
                .firstWhere(
                  (e) => e.exerciseLinkLocalId == step.exerciseLinkLocalId,
                )
                .exerciseId,
            stepIndex: step.stepIndex,
            outcome: WorkoutExerciseExecutionOutcome.completed,
          ),
      ];
    }

    ({AdaptedSessionExecutionSnapshot snapshot, WorkoutPlayer player})
    activePlayerAfterStart() {
      materialize();
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 55,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;
      final adapted = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single
          .attachAdaptation(executionSnapshot: snapshot, recordedAt: t0)
          .occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: adapted);
      orchestrator.startTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        startedAt: t0,
      );
      final occurrence = index
          .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
          .single;
      final player = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: occurrence.occurrenceId,
        executionSnapshot: snapshot,
      ).player!.activate(recordedAt: t0).player!;
      return (snapshot: snapshot, player: player);
    }

    test('successful completion creates record and completes occurrence', () {
      final setup = activePlayerAfterStart();
      final playerBefore = setup.player;
      final result = orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        workoutPlayer: setup.player,
        exerciseOutcomes: allCompletedOutcomes(setup.snapshot),
        finishedAt: tFinish,
        recordId: 'rec-complete-1',
      );

      expect(result.completionSucceeded, isTrue);
      expect(result.status, AthleteWorkoutResolutionStatus.workoutCompleted);
      expect(result.canCompleteWorkout, isFalse);
      expect(result.workoutExecutionRecord, isNotNull);
      expect(
        result.workoutExecutionRecord!.lifecycleStatus,
        WorkoutExecutionRecordLifecycleStatus.completed,
      );
      expect(
        index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .single,
        result.occurrence,
      );
      expect(playerBefore.executionStatus, WorkoutPlayerExecutionStatus.active);
      expect(
        setup.player.finishWorkout(recordedAt: tFinish).player!.executionStatus,
        WorkoutPlayerExecutionStatus.completed,
      );
    });

    test(
      'adapted workout completion preserves execution snapshot on record',
      () {
        final setup = activePlayerAfterStart();
        final result = orchestrator.completeTodayWorkout(
          athleteId: 'athlete-1',
          date: date,
          occurrenceRepository: index,
          workoutPlayer: setup.player,
          exerciseOutcomes: allCompletedOutcomes(setup.snapshot),
          finishedAt: tFinish,
        );
        expect(result.completionSucceeded, isTrue);
        expect(
          result.workoutExecutionRecord!.executionSnapshot,
          same(setup.snapshot),
        );
      },
    );

    test('in progress workout exposes canCompleteWorkout', () {
      final setup = activePlayerAfterStart();
      expect(setup.player, isNotNull);
      final resolved = resolve();
      expect(resolved.canCompleteWorkout, isTrue);
    });

    test('already completed workout rejected', () {
      final setup = activePlayerAfterStart();
      orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        workoutPlayer: setup.player,
        exerciseOutcomes: allCompletedOutcomes(setup.snapshot),
        finishedAt: tFinish,
      );
      final again = orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        workoutPlayer: setup.player,
        exerciseOutcomes: allCompletedOutcomes(setup.snapshot),
        finishedAt: tFinish,
      );
      expect(
        again.completionStatus,
        AthleteWorkoutCompletionStatus.unavailable,
      );
      expect(again.completionDetail, 'already_completed');
    });

    test('player not active rejected', () {
      final setup = activePlayerAfterStart();
      final readyPlayer = WorkoutPlayer.openReady(
        playerId: 'player-ready',
        occurrenceId: setup.player.occurrenceId,
        executionSnapshot: setup.snapshot,
      ).player!;

      final result = orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        workoutPlayer: readyPlayer,
        exerciseOutcomes: allCompletedOutcomes(setup.snapshot),
        finishedAt: tFinish,
      );
      expect(
        result.completionStatus,
        AthleteWorkoutCompletionStatus.unavailable,
      );
      expect(result.completionDetail, WorkoutPlayerExecutionStatus.ready.name);
    });

    test('no workout scheduled', () {
      final setup = activePlayerAfterStart();
      final result = orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: AthleteSessionOccurrenceIndex(),
        workoutPlayer: setup.player,
        exerciseOutcomes: const [],
        finishedAt: tFinish,
      );
      expect(
        result.completionStatus,
        AthleteWorkoutCompletionStatus.noWorkoutScheduled,
      );
    });

    test('multiple workouts scheduled', () {
      materialize(slotId: 'slot-a');
      materialize(slotId: 'slot-b');
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 55,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;
      final player = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-unknown',
        executionSnapshot: snapshot,
      ).player!.activate(recordedAt: t0).player!;

      final result = orchestrator.completeTodayWorkout(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
        workoutPlayer: player,
        exerciseOutcomes: const [],
        finishedAt: tFinish,
      );
      expect(
        result.completionStatus,
        AthleteWorkoutCompletionStatus.multipleWorkoutsScheduled,
      );
    });

    test('resolveToday completionStatus remains none', () {
      materialize();
      expect(resolve().completionStatus, AthleteWorkoutCompletionStatus.none);
    });

    test('start workflow unchanged after complete path added', () {
      materialize();
      expect(
        orchestrator
            .startTodayWorkout(
              athleteId: 'athlete-1',
              date: date,
              occurrenceRepository: index,
              startedAt: t0,
            )
            .startSucceeded,
        isTrue,
      );
    });
  });
}

class _TrackingResolver extends AthleteDailySessionResolver {
  int callCount = 0;

  @override
  AthleteDailySessionResolutionResult resolve({
    required String athleteId,
    required SessionOccurrenceDate date,
    required SessionOccurrenceRepository occurrenceRepository,
  }) {
    callCount++;
    return super.resolve(
      athleteId: athleteId,
      date: date,
      occurrenceRepository: occurrenceRepository,
    );
  }
}
