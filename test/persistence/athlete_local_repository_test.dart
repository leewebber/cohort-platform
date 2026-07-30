import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/athlete_state_hydrator.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/core/persistence/persistence_envelope.dart';
import 'package:cohort_platform/core/persistence/previous_performance_from_results.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/features/adaptive_progression/models/capability_timeline.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

AthleteProfile _profile(String id) {
  final stamp = DateTime.utc(2026, 7, 30, 8);
  return AthleteProfile(
    athleteId: id,
    displayName: 'Lee',
    primaryGoal: AthleteGoalCatalog.byId('hyrox'),
    availableEquipment: const ['bodyweight'],
    environmentId: 'home',
    trainingDaysPerWeek: 4,
    preferredSessionDurationMinutes: 45,
    experienceLevel: AthleteExperienceLevel.intermediate,
    assessmentComplete: true,
    preferredTrainingStyle: 'hybrid',
    createdAt: stamp,
    updatedAt: stamp,
  );
}

PlanAssignment _assignment(String athleteId) {
  final stamp = DateTime.utc(2026, 7, 28);
  return PlanAssignment(
    assignmentId: 'assignment.$athleteId.plan.1',
    athleteId: athleteId,
    planId: 'plan.hyrox_race_ready',
    assignedAt: stamp,
    startedAt: stamp,
    currentPhase: 'Foundation',
    currentWeek: 2,
    currentDay: 3,
    status: PlanAssignmentStatus.active,
  );
}

GeneratedSessionRecord _generated(String athleteId) {
  return GeneratedSessionRecord(
    athleteId: athleteId,
    planId: 'plan.hyrox_race_ready',
    assignmentId: 'assignment.$athleteId.plan.1',
    intendedTrainingDate: DateTime(2026, 7, 30),
    generatedAt: DateTime.utc(2026, 7, 30, 7),
    plan: const SessionExecutionPlan(
      sessionId: 'session.1',
      sessionTitle: "Today's Training",
      blocks: [
        SessionExecutionBlock(
          blockId: 'b1',
          title: 'Main',
          blockType: SessionBlockType.strength,
          content: 'Work',
          workoutFormat: WorkoutFormat.none,
          position: 0,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'ex.squat',
              displayName: 'Squat',
            ),
          ],
        ),
      ],
    ),
    brief: const WorkoutSessionBrief(
      sessionName: "Today's Training",
      estimatedDurationMinutes: 45,
    ),
    phaseLabel: 'Foundation',
    programmeName: 'HYROX Plan',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryKvStore store;
  late AthleteLocalRepository repo;

  setUp(() {
    store = InMemoryKvStore();
    repo = AthleteLocalRepository(store);
    AthletePersistence.resetForTests();
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
    PreviousPerformanceStore.clear();
  });

  tearDown(() {
    AthletePersistence.resetForTests();
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
    PreviousPerformanceStore.clear();
  });

  group('AthleteLocalRepository contract', () {
    test('save / read / overwrite profile', () async {
      final a = _profile('athlete.a');
      await repo.saveProfile(a);
      expect((await repo.readProfile('athlete.a'))?.displayName, 'Lee');

      final b = a.copyWith(displayName: 'Updated');
      await repo.saveProfile(b);
      expect((await repo.readProfile('athlete.a'))?.displayName, 'Updated');
    });

    test('plan assignment save / clear', () async {
      final assignment = _assignment('athlete.a');
      await repo.savePlanAssignment(assignment);
      expect(
        (await repo.readPlanAssignment('athlete.a'))?.currentWeek,
        2,
      );
      await repo.clearPlanAssignment('athlete.a');
      expect(await repo.readPlanAssignment('athlete.a'), isNull);
    });

    test('completions keep chronological order', () async {
      final items = [
        SessionCompletion(
          completionId: 'c2',
          athleteId: 'athlete.a',
          completedAt: DateTime.utc(2026, 7, 29),
          exercisesCompleted: 3,
          totalExercises: 3,
        ),
        SessionCompletion(
          completionId: 'c1',
          athleteId: 'athlete.a',
          completedAt: DateTime.utc(2026, 7, 28),
          exercisesCompleted: 2,
          totalExercises: 3,
        ),
      ];
      await repo.saveCompletions('athlete.a', items);
      final read = await repo.readCompletions('athlete.a');
      expect(read.map((c) => c.completionId), ['c1', 'c2']);
    });

    test('capability timeline deduplicates by eventId', () async {
      final stamp = DateTime.utc(2026, 7, 29);
      final events = [
        CapabilityTimelineEvent(
          eventId: 'e1',
          recordedAt: stamp,
          capabilityId: 'cohort.capability.threshold',
          label: 'Threshold Capacity',
          direction: CapabilityChangeDirection.up,
        ),
        CapabilityTimelineEvent(
          eventId: 'e1',
          recordedAt: stamp.add(const Duration(hours: 1)),
          capabilityId: 'cohort.capability.threshold',
          label: 'Threshold Capacity',
          direction: CapabilityChangeDirection.up,
          toLevel: 0.6,
        ),
      ];
      await repo.saveCapabilityTimeline('athlete.a', events);
      final read = await repo.readCapabilityTimeline('athlete.a');
      expect(read, hasLength(1));
      expect(read.first.toLevel, 0.6);
    });

    test('unknown schema version fails safely and clears aggregate', () async {
      final envelope = PersistenceEnvelope(
        schemaVersion: 99,
        savedAt: DateTime.utc(2026, 7, 30),
        payload: {'displayName': 'Bad'},
      );
      await store.writeString(
        PersistenceKeys.profile('athlete.a'),
        envelope.encode(),
      );
      expect(await repo.readProfile('athlete.a'), isNull);
      expect(await store.readString(PersistenceKeys.profile('athlete.a')), isNull);
    });

    test('corrupt JSON fails safely', () async {
      await store.writeString(
        PersistenceKeys.completions('athlete.a'),
        '{not-json',
      );
      expect(await repo.readCompletions('athlete.a'), isEmpty);
      expect(
        await store.readString(PersistenceKeys.completions('athlete.a')),
        isNull,
      );
    });

    test('clearAthlete removes scoped keys', () async {
      await repo.saveProfile(_profile('athlete.a'));
      await repo.savePlanAssignment(_assignment('athlete.a'));
      await repo.clearAthlete('athlete.a');
      expect(await repo.readProfile('athlete.a'), isNull);
      expect(await repo.readPlanAssignment('athlete.a'), isNull);
      expect(await repo.readLastLocalAthleteId(), isNull);
    });

    test('workout progress save / discard', () async {
      final snap = WorkoutProgressSnapshot(
        sessionId: 'session.1',
        athleteId: 'athlete.a',
        currentExerciseIndex: 1,
        currentSet: 2,
        completedExerciseIndexes: const [0],
        startedAt: DateTime.utc(2026, 7, 30, 9),
        lastUpdatedAt: DateTime.utc(2026, 7, 30, 9, 10),
      );
      await repo.saveWorkoutProgress(snap);
      expect(
        (await repo.readWorkoutProgress('athlete.a'))?.currentSet,
        2,
      );
      await repo.clearWorkoutProgress('athlete.a');
      expect(await repo.readWorkoutProgress('athlete.a'), isNull);
    });
  });

  group('hydration', () {
    test('profile and assignment survive hydrate restart', () async {
      AthletePersistence.bindForTests(repo);
      await repo.saveProfile(_profile('athlete.a'));
      await repo.savePlanAssignment(_assignment('athlete.a'));

      final hydrator = AthleteStateHydrator(repository: repo);
      final result = await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        now: DateTime(2026, 7, 30, 10),
        allowRegenerate: false,
      );

      expect(result.status, isNot(AthleteHydrationStatus.empty));
      expect(AthleteProfileSession.profile?.athleteId, 'athlete.a');
      expect(AthleteProfileSession.activeAssignment?.currentDay, 3);
    });

    test('generated session restores for same calendar day', () async {
      await repo.saveProfile(_profile('athlete.a'));
      await repo.savePlanAssignment(_assignment('athlete.a'));
      await repo.saveGeneratedSession(_generated('athlete.a'));

      final hydrator = AthleteStateHydrator(repository: repo);
      final result = await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        now: DateTime(2026, 7, 30, 12),
        allowRegenerate: false,
      );

      expect(result.regeneratedSession, isFalse);
      expect(AthleteProfileSession.programme?.sessionTitle, "Today's Training");
    });

    test('repeated hydration does not duplicate timeline events', () async {
      await repo.saveProfile(_profile('athlete.a'));
      await repo.saveCapabilityTimeline('athlete.a', [
        CapabilityTimelineEvent(
          eventId: 'e1',
          recordedAt: DateTime.utc(2026, 7, 29),
          capabilityId: 'cohort.capability.threshold',
          label: 'Threshold Capacity',
          direction: CapabilityChangeDirection.up,
        ),
      ]);

      final hydrator = AthleteStateHydrator(repository: repo);
      await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        allowRegenerate: false,
      );
      await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        allowRegenerate: false,
      );
      expect(CapabilityTimelineStore.all, hasLength(1));
    });

    test('sign-out clears memory and local aggregates', () async {
      AthletePersistence.bindForTests(repo);
      await repo.saveProfile(_profile('athlete.a'));
      AthleteProfileSession.bind(profile: _profile('athlete.a'));

      await AthletePersistence.clearForSignOut(athleteId: 'athlete.a');
      expect(AthleteProfileSession.profile, isNull);
      expect(await repo.readProfile('athlete.a'), isNull);
    });
  });

  group('previous performance from results', () {
    test('strength result survives restart derivation', () async {
      final results = [
        StrengthExecutionResult(
          resultId: 'r1',
          exerciseId: 'ex.squat',
          completedAt: DateTime.utc(2026, 7, 29, 10),
          completionId: 'c1',
          setIndex: 1,
          prescribedReps: 10,
          completedReps: 10,
          load: 100,
          loadUnit: 'kg',
          rpe: 8,
          totalSets: 3,
        ),
        StrengthExecutionResult(
          resultId: 'r2',
          exerciseId: 'ex.squat',
          completedAt: DateTime.utc(2026, 7, 29, 10, 1),
          completionId: 'c1',
          setIndex: 2,
          prescribedReps: 10,
          completedReps: 10,
          load: 100,
          loadUnit: 'kg',
          rpe: 8,
          totalSets: 3,
        ),
        StrengthExecutionResult(
          resultId: 'r3',
          exerciseId: 'ex.squat',
          completedAt: DateTime.utc(2026, 7, 29, 10, 2),
          completionId: 'c1',
          setIndex: 3,
          prescribedReps: 10,
          completedReps: 10,
          load: 100,
          loadUnit: 'kg',
          rpe: 8,
          totalSets: 3,
        ),
      ];
      await repo.saveExerciseResults('athlete.a', results);
      final read = await repo.readExerciseResults('athlete.a');
      final snap = const PreviousPerformanceFromResults().resolveLatest(
        exerciseId: 'ex.squat',
        results: read,
      );
      expect(snap, isNotNull);
      expect(snap!.loadSummary, '100 kg');
      expect(snap.repSummary, '3 × 10');
      expect(snap.rpe, 8);
    });

    test('interval result derives average pace', () async {
      final results = [
        RunningIntervalExecutionResult(
          resultId: 'i1',
          exerciseId: 'ex.run800',
          completedAt: DateTime.utc(2026, 7, 29),
          completionId: 'c1',
          intervalIndex: 1,
          distance: 800,
          distanceUnit: 'm',
          paceSecondsPerKm: 285,
        ),
        RunningIntervalExecutionResult(
          resultId: 'i2',
          exerciseId: 'ex.run800',
          completedAt: DateTime.utc(2026, 7, 29, 0, 1),
          completionId: 'c1',
          intervalIndex: 2,
          distance: 800,
          distanceUnit: 'm',
          paceSecondsPerKm: 285,
        ),
        RunningIntervalExecutionResult(
          resultId: 'i3',
          exerciseId: 'ex.run800',
          completedAt: DateTime.utc(2026, 7, 29, 0, 2),
          completionId: 'c1',
          intervalIndex: 3,
          distance: 800,
          distanceUnit: 'm',
          paceSecondsPerKm: 285,
        ),
      ];
      final snap = const PreviousPerformanceFromResults().resolveLatest(
        exerciseId: 'ex.run800',
        results: results,
      );
      expect(snap?.distanceSummary, '3 × 800 m');
      expect(snap?.paceSummary, 'Average pace 4:45/km');
    });

    test('abandoned sets are excluded', () async {
      final results = [
        StrengthExecutionResult(
          resultId: 'r1',
          exerciseId: 'ex.squat',
          completedAt: DateTime.utc(2026, 7, 29),
          completionId: 'c1',
          setIndex: 1,
          completedReps: 5,
          load: 60,
          loadUnit: 'kg',
          abandoned: true,
        ),
      ];
      expect(
        const PreviousPerformanceFromResults().resolveLatest(
          exerciseId: 'ex.squat',
          results: results,
        ),
        isNull,
      );
    });
  });
}
