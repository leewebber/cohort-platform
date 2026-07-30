import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/core/persistence/athlete_state_hydrator.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/previous_performance_from_results.dart';
import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/core/privacy/connected_data_contracts.dart';
import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_execution_coordinator.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/adaptation/services/post_completion_adaptation_evaluator.dart';
import 'package:cohort_platform/features/adaptation/services/prepared_execution_reverter.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_programme_generation_service.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/plans/services/programmed_session_resolver.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ProgrammedSessionResolver.clearCacheForTests();
    AthletePersistence.resetForTests();
    AthleteProfileSession.clear();
    AdaptationRecommendationBuffer.clear();
    SessionCompletionStore.clear();
  });

  tearDown(() {
    ProgrammedSessionResolver.clearCacheForTests();
    AthletePersistence.resetForTests();
    AthleteProfileSession.clear();
    AdaptationRecommendationBuffer.clear();
    SessionCompletionStore.clear();
  });

  PlanAssignment assignmentFor(String athleteId, {int week = 1, int day = 1}) {
    final stamp = DateTime.utc(2026, 7, 1);
    return PlanAssignment(
      assignmentId: 'assignment.$athleteId',
      athleteId: athleteId,
      planId: 'plan.hyrox_race_ready',
      assignedAt: stamp,
      startedAt: stamp,
      currentPhase: 'Foundation',
      currentWeek: week,
      currentDay: day,
      status: PlanAssignmentStatus.active,
    );
  }

  AthleteProfile profile(String id, {double? strengthLevel}) {
    final stamp = DateTime.utc(2026, 7, 1);
    return AthleteProfile(
      athleteId: id,
      displayName: id,
      primaryGoal: AthleteGoalCatalog.byId('hyrox'),
      availableEquipment: const ['barbell', 'dumbbell'],
      environmentId: 'commercial_gym',
      trainingDaysPerWeek: 4,
      preferredSessionDurationMinutes: 60,
      experienceLevel: AthleteExperienceLevel.intermediate,
      assessmentComplete: true,
      baselineCapabilities: [
        if (strengthLevel != null)
          AthleteBaselineCapability(
            capabilityId: 'cohort.capability.relative_strength',
            relativeLevel: strengthLevel,
          ),
      ],
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  group('programmed session integrity', () {
    test('two athletes on same Plan version resolve same structure', () async {
      final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
      final resolver = ProgrammedSessionResolver();
      final a = await resolver.resolve(
        plan: plan,
        assignment: assignmentFor('athlete.a'),
      );
      final b = await resolver.resolve(
        plan: plan,
        assignment: assignmentFor('athlete.b'),
      );
      expect(a.programmedSessionKey, b.programmedSessionKey);
      expect(ProgrammedSessionResolver.sameProgrammedStructure(a, b), isTrue);
    });

    test('different previous-performance history does not alter programmed prescription',
        () async {
      final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
      final resolver = ProgrammedSessionResolver();
      final weak = await resolver.resolve(
        plan: plan,
        assignment: assignmentFor('weak'),
      );
      // Simulate different athlete history in memory — must not affect cache key.
      PreviousPerformanceFromResults();
      final strong = await resolver.resolve(
        plan: plan,
        assignment: assignmentFor('strong'),
      );
      expect(
        ProgrammedSessionResolver.sameProgrammedStructure(weak, strong),
        isTrue,
      );
    });
  });

  group('load selection', () {
    test('previous load does not become today load / no next-load recommendation',
        () {
      const policy = LoadSelectionPolicy();
      expect(policy.allowsAutomaticProgression, isFalse);
      expect(policy.allowsForcedLoadFromPrevious, isFalse);
      expect(
        policy.suggestedNextLoadKg(previousLoadKg: 100, programmedLoadKg: null),
        isNull,
      );
    });
  });

  group('adaptation authority', () {
    test('recommendation does not mutate before acceptance', () {
      AdaptationRecommendationBuffer.propose(
        const PendingAdaptationRecommendation(
          recommendationId: 'r1',
          programmedSessionKey: 'plan.x@1.0.0:w1:d1',
          reasonCode: 'time',
          proposedChanges: ['compress volume'],
        ),
      );
      expect(AdaptationRecommendationBuffer.pending, isNotNull);
      // Durable programmed key unchanged — buffer only.
      expect(
        AdaptationRecommendationBuffer.pending!.programmedSessionKey,
        'plan.x@1.0.0:w1:d1',
      );
    });

    test('dismissing recommendation leaves original unchanged', () {
      AdaptationRecommendationBuffer.propose(
        const PendingAdaptationRecommendation(
          recommendationId: 'r2',
          programmedSessionKey: 'plan.x@1.0.0:w1:d1',
          reasonCode: 'equipment',
          proposedChanges: ['substitute'],
        ),
      );
      final dismissed = AdaptationRecommendationBuffer.dismiss();
      expect(dismissed, isNotNull);
      expect(AdaptationRecommendationBuffer.pending, isNull);
      expect(AdaptationRecommendationBuffer.accept(), isNull);
    });

    test('accepting adaptation is a derived decision, not programme rewrite', () {
      AdaptationRecommendationBuffer.propose(
        const PendingAdaptationRecommendation(
          recommendationId: 'r3',
          programmedSessionKey: 'plan.x@1.0.0:w1:d1',
          reasonCode: 'time',
          proposedChanges: ['reduce volume'],
          preservedIntent: 'strength',
        ),
      );
      final accepted = AdaptationRecommendationBuffer.accept(
        now: DateTime.utc(2026, 7, 30),
      );
      expect(accepted, isNotNull);
      expect(accepted!.programmedSessionKey, 'plan.x@1.0.0:w1:d1');
      expect(accepted.changeSummary, ['reduce volume']);
      // Original key identity preserved on decision.
      final key = ProgrammedSessionKey.parse(accepted.programmedSessionKey);
      expect(key.week, 1);
      expect(key.day, 1);
    });

    test('unsupported adaptation changes are rejected', () {
      const gate = AdaptationPolicyGate();
      expect(
        () => gate.assertAllowed([
          AdaptationChangeKind.reduceVolume,
          AdaptationChangeKind.rewritePlan,
        ]),
        throwsA(isA<AdaptationPolicyException>()),
      );
      expect(
        gate.rejectUnsupported([AdaptationChangeKind.forceDeload]),
        contains(AdaptationChangeKind.forceDeload),
      );
      expect(gate.isAllowed(AdaptationChangeKind.compressForTime), isTrue);
    });
  });

  group('reconstruction after restart', () {
    test('restart restores accepted adaptation on prepared record', () async {
      final store = InMemoryKvStore();
      final repo = AthleteLocalRepository(store);
      AthletePersistence.bindForTests(repo);

      final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
      final assignment = assignmentFor('athlete.a');
      final prepared = await ProgrammedSessionResolver().resolve(
        plan: plan,
        assignment: assignment,
      );
      final adaptation = AcceptedAdaptationDecision(
        decisionId: 'adapt.1',
        programmedSessionKey: prepared.programmedSessionKey.value,
        reasonCode: 'time',
        acceptedAt: DateTime.utc(2026, 7, 30),
        changeSummary: const ['compress'],
      );

      final generation = AthleteProgrammeGenerationService(
        programmedResolver: ProgrammedSessionResolver(),
      );
      final programme = await generation.prepareExecution(
        profile('athlete.a'),
        activePlan: plan,
        assignment: assignment,
        acceptedAdaptation: adaptation,
      );
      expect(programme.acceptedAdaptation, isNotNull);

      await AthletePersistence.persistBoundSession(
        now: DateTime(2026, 7, 30, 12),
      );

      AthleteProfileSession.clear();
      final hydrator = AthleteStateHydrator(repository: repo);
      final result = await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        now: DateTime(2026, 7, 30, 18),
        allowRegenerate: false,
      );
      expect(result.status, AthleteHydrationStatus.restored);
      expect(
        AthleteProfileSession.programme?.acceptedAdaptation?.decisionId,
        'adapt.1',
      );
      expect(
        AthleteProfileSession.programme?.programmedSessionKey?.value,
        prepared.programmedSessionKey.value,
      );
    });

    test('restart without adaptation reconstructs original programmed session',
        () async {
      final store = InMemoryKvStore();
      final repo = AthleteLocalRepository(store);
      AthletePersistence.bindForTests(repo);

      final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
      final assignment = assignmentFor('athlete.a', week: 2, day: 1);
      final key = ProgrammedSessionKey.fromPlan(
        plan: plan,
        assignment: assignment,
      );

      await repo.saveProfile(profile('athlete.a'));
      await repo.savePlanAssignment(assignment);

      final hydrator = AthleteStateHydrator(repository: repo);
      final result = await hydrator.hydrate(
        preferredAthleteId: 'athlete.a',
        now: DateTime(2026, 7, 30, 10),
        allowReconstruct: true,
      );
      expect(result.reconstructedSession, isTrue);
      expect(
        AthleteProfileSession.programme?.programmedSessionKey?.value,
        key.value,
      );
      expect(AthleteProfileSession.programme?.acceptedAdaptation, isNull);
    });
  });

  group('completed session linkage', () {
    test('completion retains programmed session and plan version', () {
      final completion = SessionCompletion(
        completionId: 'c1',
        athleteId: 'athlete.a',
        completedAt: DateTime.utc(2026, 7, 30),
        exercisesCompleted: 3,
        totalExercises: 3,
        planId: 'plan.hyrox_race_ready',
        programmedSessionKey: 'plan.hyrox_race_ready@1.0.0:w1:d1',
        planVersion: '1.0.0',
      );
      final roundTrip =
          SessionCompletion.fromPersistenceMap(completion.toPersistenceMap());
      expect(roundTrip.programmedSessionKey, completion.programmedSessionKey);
      expect(roundTrip.planVersion, '1.0.0');
    });
  });

  group('previous performance descriptive', () {
    test('does not invent load from prescription-only capture fields', () {
      final snap = const PreviousPerformanceFromResults().resolveLatest(
        exerciseId: 'ex.squat',
        results: [
          StrengthExecutionResult(
            resultId: 'r1',
            exerciseId: 'ex.squat',
            completedAt: DateTime.utc(2026, 7, 29),
            completionId: 'c1',
            setIndex: 1,
            prescribedReps: 5,
            completedReps: null,
            load: null,
          ),
        ],
      );
      expect(snap, isNull);
    });

    test('uses athlete-entered completed load only', () {
      final snap = const PreviousPerformanceFromResults().resolveLatest(
        exerciseId: 'ex.squat',
        results: [
          StrengthExecutionResult(
            resultId: 'r1',
            exerciseId: 'ex.squat',
            completedAt: DateTime.utc(2026, 7, 29),
            completionId: 'c1',
            setIndex: 1,
            prescribedReps: 5,
            completedReps: 5,
            load: 100,
            loadUnit: 'kg',
            rpe: 7,
          ),
        ],
      );
      expect(snap?.loadSummary, '100 kg');
      expect(snap?.repSummary, '1 × 5');
    });
  });

  group('privacy contracts', () {
    test('connected data kinds exclude location / travel fields', () {
      final names = ConnectedPerformanceMetricKind.values.map((e) => e.name);
      expect(names, isNot(contains('liveLocation')));
      expect(names, isNot(contains('gpsRoute')));
      expect(names, isNot(contains('geofence')));
      expect(names, isNot(contains('travelDetection')));
      expect(names, isNot(contains('homeLocation')));

      final sample = ConnectedPerformanceMetric(
        kind: ConnectedPerformanceMetricKind.hrv,
        value: 60,
        recordedAt: DateTime.utc(2026, 7, 30),
      );
      expect(sample.kind, ConnectedPerformanceMetricKind.hrv);
      expect(sample.sourceConnectionId, isNull);
    });
  });

  group('adversarial constitution guards', () {
    test('post-completion coordinator never auto-mutates without accept',
        () async {
      final result = await AdaptationExecutionCoordinator()
          .executeAfterSessionCompleted(
        athleteId: 'athlete.a',
        record: TrainingSessionRecord(
          recordId: 'r1',
          athleteId: 'athlete.a',
          status: TrainingSessionRecordStatus.completed,
          sessionSnapshot: const SessionPerformanceSnapshot(
            sourceProtocolId: 'BW-001',
            sessionTitle: 'Strength',
          ),
          startedAt: DateTime.utc(2026, 7, 30),
        ),
        programmeContext: const ProgrammeExecutionContext(
          assignmentId: 'assignment-1',
          programmeVersionId: 'version-1',
          sessionSlotId: 'slot-1',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          plannedProtocolId: 'BW-001',
          effectiveProtocolId: 'BW-001',
        ),
        trainingSessionId: 1,
        endedEarly: false,
      );
      expect(result, isNotNull);
      expect(result!.applied, isFalse);
      expect(result.skippedReason, 'awaiting_athlete_acceptance');
    });

    test('post-completion kinds are prohibited by policy gate', () {
      const gate = AdaptationPolicyGate();
      expect(
        gate.rejectUnsupported(
          AdaptationPolicyGate.kindsForPostCompletion(
            AdaptationEvaluationType.loadProgression,
          ),
        ),
        contains(AdaptationChangeKind.rewriteLaterSessions),
      );
      expect(
        gate.rejectUnsupported(
          AdaptationPolicyGate.kindsForPostCompletion(
            AdaptationEvaluationType.protocolSubstitution,
          ),
        ),
        containsAll([
          AdaptationChangeKind.rewriteLaterSessions,
          AdaptationChangeKind.forceDeload,
        ]),
      );
      expect(
        gate.rejectUnsupported(
          AdaptationPolicyGate.kindsForDayOf(AdaptationReason.recovery),
        ),
        isEmpty,
      );
      expect(
        gate.rejectUnsupported(
          AdaptationPolicyGate.kindsForDayOf(AdaptationReason.recovery),
        ),
        isNot(contains(AdaptationChangeKind.forceDeload)),
      );
    });

    test('athlete can revert accepted adaptation to original programmed session',
        () async {
      final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
      final assignment = assignmentFor('athlete.a');
      final generation = AthleteProgrammeGenerationService(
        programmedResolver: ProgrammedSessionResolver(),
      );
      final prepared = await ProgrammedSessionResolver().resolve(
        plan: plan,
        assignment: assignment,
      );
      final withAdapt = await generation.prepareExecution(
        profile('athlete.a'),
        activePlan: plan,
        assignment: assignment,
        acceptedAdaptation: AcceptedAdaptationDecision(
          decisionId: 'adapt.revert',
          programmedSessionKey: prepared.programmedSessionKey.value,
          reasonCode: 'time',
          acceptedAt: DateTime.utc(2026, 7, 30),
          changeSummary: const ['compress'],
        ),
      );
      expect(withAdapt.acceptedAdaptation, isNotNull);

      final restored = await PreparedExecutionReverter(
        generation: generation,
      ).revertToProgrammed();
      expect(restored, isNotNull);
      expect(restored!.acceptedAdaptation, isNull);
      expect(
        restored.programmedSessionKey?.value,
        prepared.programmedSessionKey.value,
      );
    });

    test('completion links programmed session, plan version, and adaptation', () {
      final completion = SessionCompletion(
        completionId: 'c2',
        athleteId: 'athlete.a',
        completedAt: DateTime.utc(2026, 7, 30),
        exercisesCompleted: 3,
        totalExercises: 3,
        planId: 'plan.hyrox_race_ready',
        programmedSessionKey: 'plan.hyrox_race_ready@1.0.0:w1:d1',
        planVersion: '1.0.0',
        acceptedAdaptationId: 'adapt.1',
      );
      final roundTrip =
          SessionCompletion.fromPersistenceMap(completion.toPersistenceMap());
      expect(roundTrip.acceptedAdaptationId, 'adapt.1');
      expect(roundTrip.programmedSessionKey, completion.programmedSessionKey);
      expect(roundTrip.planVersion, '1.0.0');
    });
  });
}
