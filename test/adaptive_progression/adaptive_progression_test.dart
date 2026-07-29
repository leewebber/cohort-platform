import 'dart:io';

import 'package:cohort_platform/features/adaptive_progression/models/capability_timeline.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/adaptive_progression/services/adaptive_progression_coordinator.dart';
import 'package:cohort_platform/features/adaptive_progression/services/plan_progression_service.dart';
import 'package:cohort_platform/features/adaptive_progression/services/training_evidence_update_service.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_programme_generation_service.dart';
import 'package:cohort_platform/features/athlete_profile/widgets/athlete_generated_today_section.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_player_result.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/coach_brain_service.dart';
import 'package:cohort_platform/planning/orchestration/models/coach_brain_orchestration_request.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
  });

  group('SessionCompletion', () {
    test('records completion fields and ratio', () {
      final completion = SessionCompletion(
        completionId: 'c1',
        athleteId: 'athlete.lee',
        completedAt: DateTime.utc(2026, 7, 29, 10),
        duration: const Duration(minutes: 42),
        exercisesCompleted: 4,
        totalExercises: 5,
        sessionRpe: 6,
        notes: 'Solid',
      );
      expect(completion.completionRatio, closeTo(0.8, 0.001));
      SessionCompletionStore.add(completion);
      expect(SessionCompletionStore.latest?.completionId, 'c1');
    });
  });

  group('TrainingEvidenceUpdateService', () {
    test('raises priority baselines deterministically after completion', () {
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final now = DateTime.utc(2026, 7, 29);
      final profile = AthleteProfile(
        athleteId: 'athlete.lee',
        displayName: 'Lee',
        primaryGoal: plan.primaryGoal,
        availableEquipment: const ['cohort.equipment.bodyweight'],
        environmentId: 'cohort.environment.home',
        trainingDaysPerWeek: 3,
        preferredSessionDurationMinutes: 45,
        experienceLevel: AthleteExperienceLevel.beginner,
        assessmentComplete: true,
        baselineCapabilities: const [
          AthleteBaselineCapability(
            capabilityId: 'cohort.capability.relative_strength',
            relativeLevel: 0.4,
          ),
          AthleteBaselineCapability(
            capabilityId: 'cohort.capability.work_capacity',
            relativeLevel: 0.4,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final completion = SessionCompletion(
        completionId: 'c1',
        athleteId: 'athlete.lee',
        completedAt: now,
        exercisesCompleted: 5,
        totalExercises: 5,
        sessionRpe: 6,
      );

      final updated = const TrainingEvidenceUpdateService().apply(
        profile: profile,
        completion: completion,
        activePlan: plan,
        now: now,
      );

      final strength = updated.baselineCapabilities.firstWhere(
        (c) => c.capabilityId == 'cohort.capability.relative_strength',
      );
      expect(strength.relativeLevel, greaterThan(0.4));
      expect(strength.relativeLevel, lessThanOrEqualTo(0.95));
    });
  });

  group('PlanProgressionService', () {
    test('advances day and rolls week', () {
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      const service = PlanProgressionService();
      final day1 = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: DateTime.utc(2026, 7, 29),
        currentDay: 1,
        currentWeek: 1,
        currentPhase: PlanProgressionService.phaseFoundation,
      );

      final day2 = service.advance(assignment: day1, plan: plan);
      expect(day2.currentDay, 2);
      expect(day2.currentWeek, 1);

      // Fat loss foundation is 3 days/week — day 3 → next is week 2 day 1.
      final day3 = service.advance(assignment: day2, plan: plan);
      final week2 = service.advance(assignment: day3, plan: plan);
      expect(week2.currentDay, 1);
      expect(week2.currentWeek, 2);
      expect(week2.currentPhase, PlanProgressionService.phaseFoundation);
    });

    test('moves phase across plan duration blocks', () {
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!; // 8 weeks
      const service = PlanProgressionService();
      final late = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: DateTime.utc(2026, 7, 29),
        currentDay: 3,
        currentWeek: 3,
        currentPhase: PlanProgressionService.phaseFoundation,
      );
      // After completing day 3 of week 3 → week 4 day 1; block size ceil(8/3)=3
      // week 4 > 3 → Build
      final next = service.advance(assignment: late, plan: plan);
      expect(next.currentWeek, 4);
      expect(next.currentPhase, PlanProgressionService.phaseBuild);
    });
  });

  group('AdaptiveProgressionCoordinator', () {
    test('regenerates next session via Coach Brain and refreshes Home data',
        () async {
      final knowledgeRoot = _findKnowledgeRoot(Directory.current);
      final knowledge = InMemoryKnowledgeGraphReader(
        await YamlKnowledgeOntologyLoader().loadFromDirectory(knowledgeRoot),
      );
      var brainCalls = 0;
      final brain = _CountingBrain(
        knowledge: knowledge,
        onRun: () => brainCalls++,
      );
      final planService = CoachBrainWorkoutPlanService(
        coachBrain: brain,
        knowledgeRoot: knowledgeRoot,
      );

      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final now = DateTime.utc(2026, 7, 29);
      final profile = AthleteProfile(
        athleteId: 'athlete.lee',
        displayName: 'Lee',
        primaryGoal: plan.primaryGoal,
        availableEquipment: AthleteEquipmentCatalog.byId(
          'home_gym',
        ).equipmentIds,
        environmentId: AthleteEquipmentCatalog.byId('home_gym').environmentId,
        trainingDaysPerWeek: 3,
        preferredSessionDurationMinutes: 45,
        experienceLevel: AthleteExperienceLevel.beginner,
        assessmentComplete: true,
        baselineCapabilities: const [
          AthleteBaselineCapability(
            capabilityId: 'cohort.capability.relative_strength',
            relativeLevel: 0.4,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final assignment = PlanAssignment(
        assignmentId: 'assignment.1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: now,
        startedAt: now,
        currentPhase: 'Foundation',
        currentWeek: 1,
        currentDay: 1,
      );

      // Seed today's programme (minimal) then run adaptive loop.
      final seedBundle = await planService.resolveFromProfile(
        profile: profile,
        activePlan: plan,
        assignment: assignment,
      );
      AthleteProfileSession.bind(
        profile: profile,
        programme: AthleteGeneratedProgramme(
          planBundle: seedBundle,
          programmeName: plan.name,
          phaseLabel: 'Foundation',
        ),
        activePlan: plan,
        assignment: assignment,
      );
      final seedCalls = brainCalls;
      final seedSessionId = seedBundle.plan.sessionId;

      final coordinator = AdaptiveProgressionCoordinator(
        generationService: AthleteProgrammeGenerationService(
          planService: planService,
        ),
      );

      final result = await coordinator.runAfterCompletion(
        result: const WorkoutPlayerResult(
          completed: true,
          trainingSessionId: 1,
          duration: Duration(minutes: 40),
          exercisesCompleted: 4,
          totalExercises: 4,
          sessionRpe: 6,
        ),
        athleteId: 'athlete.lee',
        now: now,
      );

      expect(brainCalls, greaterThan(seedCalls));
      expect(SessionCompletionStore.latest, isNotNull);
      expect(result.assignment.currentDay, 2);
      expect(result.assignment.currentWeek, 1);
      expect(
        AthleteProfileSession.activeAssignment?.currentDay,
        2,
      );
      expect(AthleteProfileSession.programme, isNotNull);
      expect(
        AthleteProfileSession.programme!.planBundle.plan.blocks,
        isNotEmpty,
      );
      // New planning run produced a bound session (may share or differ id).
      expect(
        AthleteProfileSession.programme!.planBundle.plan.sessionId,
        isNotEmpty,
      );
      expect(
        AthleteProfileSession.profile!.baselineCapabilities.first.relativeLevel,
        greaterThan(0.4),
      );
      // Keep seed id referenced so unused-warning free if equal.
      expect(seedSessionId, isNotEmpty);
    });
  });

  group('Home refresh after progression', () {
    testWidgets('shows advanced week/day after session rebind', (tester) async {
      final now = DateTime.utc(2026, 7, 29);
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final assignment = PlanAssignment(
        assignmentId: 'assignment.test',
        athleteId: 'athlete.home',
        planId: plan.planId,
        assignedAt: now,
        startedAt: now,
        currentPhase: 'Foundation',
        currentWeek: 1,
        currentDay: 2,
      );
      final execution = SessionExecutionPlan(
        sessionId: 'session.next',
        sessionTitle: 'Tomorrow Strength Session',
        durationMin: 45,
        blocks: [
          SessionExecutionBlock(
            blockId: 'b1',
            title: 'Primary',
            blockType: SessionBlockType.strength,
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'ex.1',
                displayName: 'Goblet Squat',
                prescription: StrengthExercisePrescription(
                  sets: 3,
                  reps: StrengthRepPrescription.exact(8),
                ),
              ),
            ],
          ),
        ],
      );
      final context = PlanningContext(
        orchestrationId: 'orch.next',
        startedAt: now,
        completedAt: now,
        orchestrationStatus: OrchestrationStatus.complete,
        input: PlanningInput(
          athleteId: 'athlete.home',
          goalContext: PlanningGoalContext(
            goalId: plan.ontologyGoalId,
          ),
          capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
          knowledgeOntologyVersion: '1.3.0',
          asOf: now,
        ),
        sessionExecutionPlan: execution,
      );

      AthleteProfileSession.bind(
        profile: AthleteProfile(
          athleteId: 'athlete.home',
          displayName: 'Casey',
          primaryGoal: plan.primaryGoal,
          availableEquipment: const ['cohort.equipment.bodyweight'],
          environmentId: 'cohort.environment.home',
          trainingDaysPerWeek: 3,
          preferredSessionDurationMinutes: 45,
          experienceLevel: AthleteExperienceLevel.beginner,
          assessmentComplete: true,
          createdAt: now,
          updatedAt: now,
        ),
        programme: AthleteGeneratedProgramme(
          planBundle: CoachBrainWorkoutPlan(
            planningContext: context,
            plan: execution,
            brief: const WorkoutSessionBrief(
              sessionName: 'Tomorrow Strength Session',
              estimatedDurationMinutes: 45,
              trainingIntent: 'Strength',
            ),
          ),
          programmeName: plan.name,
          phaseLabel: 'Foundation',
        ),
        activePlan: plan,
        assignment: assignment,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AthleteGeneratedTodaySection()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Week 1 · Day 2'), findsWidgets);
      expect(find.textContaining('TOMORROW STRENGTH SESSION'), findsOneWidget);
      expect(find.text('EXECUTE TODAY\'S TRAINING'), findsOneWidget);
    });
  });
}

class _CountingBrain extends CoachBrainService {
  _CountingBrain({
    required InMemoryKnowledgeGraphReader knowledge,
    required VoidCallback onRun,
  }) : _onRun = onRun,
       super(
         planningEngine: PlanningEngineService(
           knowledge: knowledge,
           gapAnalysis: CapabilityGapAnalysisService(knowledge),
           intentResolution: TrainingIntentFromGapsService(knowledge),
         ),
         blueprintGenerator: DeterministicSessionBlueprintGenerator(
           knowledge: knowledge,
         ),
         exercisePolicy: DeterministicExercisePolicyEngine(knowledge: knowledge),
         prescriptionEngine: DeterministicPrescriptionEngine(
           knowledge: knowledge,
         ),
       );

  final VoidCallback _onRun;

  @override
  PlanningContext run(CoachBrainOrchestrationRequest request) {
    _onRun();
    return super.run(request);
  }
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) return '${dir.path}/knowledge';
    if (dir.parent.path == dir.path) fail('knowledge root not found');
    dir = dir.parent;
  }
}
