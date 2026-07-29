import 'dart:io';

import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_planning_input_builder.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/widgets/athlete_generated_today_section.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/plans/models/plan_definition.dart';
import 'package:cohort_platform/features/plans/screens/plan_library_screen.dart';
import 'package:cohort_platform/features/plans/services/plan_assignment_service.dart';
import 'package:cohort_platform/features/plans/services/plan_start_service.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
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

  late PlanAssignmentService assignments;

  setUp(() {
    assignments = PlanAssignmentService();
  });

  tearDown(() {
    AthleteProfileSession.clear();
    CurrentUserSession.clear();
    assignments.resetForTests();
  });

  group('PlanDefinition model', () {
    test('catalog products have philosophy and no workout fields', () {
      expect(PlanCatalog.published, isNotEmpty);
      for (final plan in PlanCatalog.published) {
        expect(plan.planId, isNotEmpty);
        expect(plan.slug, isNotEmpty);
        expect(plan.shortDescription, isNotEmpty);
        expect(plan.longDescription, isNotEmpty);
        expect(plan.progressionModel, isNotEmpty);
        expect(plan.coachingFocus, isNotEmpty);
        expect(plan.capabilityPriorities, isNotEmpty);
        expect(plan.durationWeeks, greaterThan(0));
        expect(plan.published, isTrue);
      }
    });
  });

  group('PlanAssignment model', () {
    test('tracks progress only', () {
      final assignment = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: 'plan.fat_loss_foundation',
        assignedAt: DateTime.utc(2026, 7, 29),
        startedAt: DateTime.utc(2026, 7, 29),
        currentPhase: 'Foundation',
        currentWeek: 2,
        currentDay: 3,
      );
      expect(assignment.isActive, isTrue);
      expect(assignment.weekDayLabel, 'Week 2 · Day 3');
      expect(assignment.completedAt, isNull);
      expect(assignment.configuration, isEmpty);
    });
  });

  group('PlanAssignmentService', () {
    test('assign / read / replace / clear', () {
      final planA = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final planB = PlanCatalog.byId('plan.strength_emphasis')!;

      final first = assignments.assign(athleteId: 'athlete.lee', plan: planA);
      expect(assignments.readActiveAssignment()?.assignmentId, first.assignmentId);
      expect(assignments.readActivePlan()?.planId, planA.planId);
      expect(assignments.hasActivePlan, isTrue);

      final second = assignments.replaceActivePlan(
        athleteId: 'athlete.lee',
        plan: planB,
      );
      expect(second.planId, planB.planId);
      expect(assignments.readActivePlan()?.planId, planB.planId);
      expect(assignments.history(), hasLength(1));
      expect(assignments.history().first.status, PlanAssignmentStatus.cancelled);

      assignments.clearActivePlan();
      expect(assignments.readActiveAssignment(), isNull);
      expect(assignments.readActivePlan(), isNull);
      expect(assignments.hasActivePlan, isFalse);
    });
  });

  group('Plan catalog + filters', () {
    test('filters by goal, days, experience, duration, equipment', () {
      const filters = PlanLibraryFilters(
        goalId: 'fat_loss',
        daysPerWeek: 3,
        experienceLevel: AthleteExperienceLevel.beginner,
        maxDurationMinutes: 45,
        equipmentPresetId: 'home_gym',
      );
      final result = filters.apply(PlanCatalog.published);
      expect(result, isNotEmpty);
      expect(result.every((p) => p.primaryGoal.id == 'fat_loss'), isTrue);
      expect(result.every((p) => p.recommendedDaysPerWeek == 3), isTrue);
      expect(
        result.every((p) => p.experienceLevel == AthleteExperienceLevel.beginner),
        isTrue,
      );
    });
  });

  group('PlanningInput includes active plan', () {
    test('preference tags carry plan definition + assignment', () {
      final plan = PlanCatalog.byId('plan.strength_emphasis')!;
      final profile = assignments.ensureProfile(
        plan: plan,
        athleteId: 'athlete.lee',
      );
      final assignment = assignments.assign(
        athleteId: 'athlete.lee',
        plan: plan,
      );

      final input = const AthletePlanningInputBuilder().build(
        profile: profile,
        knowledgeOntologyVersion: '1.3.0',
        activePlan: plan,
        assignment: assignment,
      );

      expect(
        input.athletePreferences?.tags,
        contains('${AthletePlanningInputBuilder.planIdTagPrefix}${plan.planId}'),
      );
      expect(
        input.athletePreferences?.tags,
        contains(
          '${AthletePlanningInputBuilder.assignmentIdTagPrefix}'
          '${assignment.assignmentId}',
        ),
      );
      expect(
        input.athletePreferences?.tags,
        contains(
          '${AthletePlanningInputBuilder.progressionModelTagPrefix}'
          '${plan.progressionModel}',
        ),
      );
      expect(input.availableTimeMinutes, plan.typicalSessionDurationMinutes);
      expect(input.goalContext.goalId, plan.ontologyGoalId);
      expect(input.progressionPathId, isNull);
    });
  });

  group('Plan start → Coach Brain', () {
    test('startPlan binds assignment and programme via Coach Brain', () async {
      final knowledgeRoot = _findKnowledgeRoot(Directory.current);
      final knowledge = InMemoryKnowledgeGraphReader(
        await YamlKnowledgeOntologyLoader().loadFromDirectory(knowledgeRoot),
      );
      var brainCalls = 0;
      final instrumented = _CountingBrain(
        knowledge: knowledge,
        onRun: () => brainCalls++,
      );

      final service = PlanStartService(
        assignmentService: assignments,
        planService: CoachBrainWorkoutPlanService(
          coachBrain: instrumented,
          knowledgeRoot: knowledgeRoot,
        ),
      );

      final result = await service.startPlan(
        planId: 'plan.fat_loss_foundation',
        athleteId: 'athlete.lee',
        displayName: 'Lee',
      );

      expect(brainCalls, 1);
      expect(result.assignment.planId, 'plan.fat_loss_foundation');
      expect(AthleteProfileSession.hasActivePlan, isTrue);
      expect(AthleteProfileSession.activePlan?.planId, result.plan.planId);
      expect(
        AthleteProfileSession.programme!.planBundle.plan.blocks,
        isNotEmpty,
      );
    });
  });

  group('Plan Library UI', () {
    testWidgets('library lists plans and opens details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: PlanLibraryScreen(athleteId: 'athlete.lee')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose your plan'), findsOneWidget);
      expect(find.text('Fat Loss Foundation'), findsOneWidget);

      await tester.tap(find.text('Fat Loss Foundation'));
      await tester.pumpAndSettle();

      expect(find.text('START PLAN'), findsOneWidget);
      expect(find.textContaining('WHO IT'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);
    });

    testWidgets('filter chips narrow the list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: PlanLibraryScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('plan_filter_beginner')));
      await tester.pumpAndSettle();

      expect(find.text('Fat Loss Foundation'), findsOneWidget);
      expect(find.text('Military Selection Prep'), findsNothing);
    });
  });

  group('Home active plan', () {
    testWidgets('empty state invites Browse Plans', (tester) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Choose a Plan'), findsOneWidget);
      expect(find.text('BROWSE PLANS'), findsOneWidget);
      expect(find.text("EXECUTE TODAY'S TRAINING"), findsNothing);
    });

    testWidgets('active plan shows phase week day and today session', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 7, 29);
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final assignment = PlanAssignment(
        assignmentId: 'assignment.test',
        athleteId: 'athlete.home',
        planId: plan.planId,
        assignedAt: now,
        startedAt: now,
        currentPhase: 'Foundation',
        currentWeek: 2,
        currentDay: 3,
      );
      final execution = SessionExecutionPlan(
        sessionId: 'session.home',
        sessionTitle: 'Personal Strength Session',
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
        orchestrationId: 'orch.home',
        startedAt: now,
        completedAt: now,
        orchestrationStatus: OrchestrationStatus.complete,
        input: PlanningInput(
          athleteId: 'athlete.home',
          goalContext: const PlanningGoalContext(
            goalId: 'cohort.goal.general_fat_loss',
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
              sessionName: 'Personal Strength Session',
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

      expect(find.text('ACTIVE PLAN'), findsOneWidget);
      expect(find.textContaining('Fat Loss Foundation'), findsWidgets);
      expect(find.textContaining('Foundation · Week 2 · Day 3'), findsOneWidget);
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
