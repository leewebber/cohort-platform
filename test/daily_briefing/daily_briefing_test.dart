import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/daily_briefing/models/daily_briefing.dart';
import 'package:cohort_platform/features/daily_briefing/services/daily_briefing_service.dart';
import 'package:cohort_platform/features/daily_briefing/widgets/daily_briefing_section.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
  });

  group('DailyBriefingService', () {
    test('builds greeting, focus, plan position, and standards', () {
      _bindSession(
        sessionName: 'Threshold Development',
        trainingIntent: 'Aerobic Power',
        duration: 52,
        displayName: 'Lee Webber',
      );

      final briefing = const DailyBriefingService().build(
        asOf: DateTime(2026, 7, 29, 9),
      );

      expect(briefing.hasActivePlan, isTrue);
      expect(briefing.greeting, 'Good morning, Lee.');
      expect(briefing.sessionHeadline, contains('Threshold Development'));
      expect(briefing.trainingFocus, 'Aerobic Power');
      expect(briefing.estimatedDurationMinutes, 52);
      expect(briefing.planName, isNotEmpty);
      expect(briefing.weekDayLabel, 'Week 4 · Day 2');
      expect(briefing.standards, hasLength(4));
      expect(briefing.standards.map((s) => s.label), contains('Hydration'));
      expect(briefing.isRestDay, isFalse);
    });

    test('includes yesterday summary from prior-day completion', () {
      _bindSession(
        sessionName: 'Threshold Development',
        trainingIntent: 'Threshold',
        duration: 45,
      );

      final briefing = const DailyBriefingService().build(
        asOf: DateTime.utc(2026, 7, 29, 10),
        completions: [
          SessionCompletion(
            completionId: 'c1',
            athleteId: 'athlete.lee',
            completedAt: DateTime.utc(2026, 7, 28, 18),
            exercisesCompleted: 5,
            totalExercises: 5,
            duration: const Duration(minutes: 48),
            sessionRpe: 7,
            sessionName: 'Upper Body Strength',
          ),
        ],
      );

      expect(briefing.yesterday, isNotNull);
      expect(briefing.yesterday!.sessionName, 'Upper Body Strength');
      expect(briefing.yesterday!.sessionRpe, 7);
    });

    test('marks recovery sessions as rest day', () {
      _bindSession(
        sessionName: 'Active Recovery',
        trainingIntent: 'Recovery',
        duration: 30,
      );

      final briefing = const DailyBriefingService().build(
        asOf: DateTime(2026, 7, 29, 11),
      );

      expect(briefing.isRestDay, isTrue);
      expect(briefing.sessionHeadline, contains('Recovery'));
    });

    test('motivation rotates deterministically by calendar day', () {
      const service = DailyBriefingService();
      final a = service.motivationFor(DateTime.utc(2026, 7, 29));
      final b = service.motivationFor(DateTime.utc(2026, 7, 29));
      final c = service.motivationFor(DateTime.utc(2026, 7, 30));

      expect(a, b);
      expect(DailyBriefingService.motivationLibrary, contains(a));
      expect(c, isNot(equals(a)));
    });
  });

  group('DailyBriefingSection UI', () {
    testWidgets('renders briefing and execute CTA', (tester) async {
      _bindSession(
        sessionName: 'Threshold Development',
        trainingIntent: 'Aerobic Power',
        duration: 52,
        displayName: 'Lee',
      );

      final briefing = const DailyBriefingService().build(
        asOf: DateTime(2026, 7, 29, 9),
        completions: [
          SessionCompletion(
            completionId: 'c1',
            athleteId: 'athlete.lee',
            completedAt: DateTime(2026, 7, 28, 18),
            exercisesCompleted: 4,
            totalExercises: 4,
            duration: const Duration(minutes: 50),
            sessionRpe: 6,
            sessionName: 'Upper Body Strength',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyBriefingSection(briefing: briefing),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Good morning, Lee.'), findsOneWidget);
      expect(find.textContaining('Threshold Development'), findsWidgets);
      expect(find.text('Aerobic Power'), findsWidgets);
      expect(find.text('52 minutes'), findsOneWidget);
      expect(find.text('Upper Body Strength'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('EXECUTE TODAY\'S TRAINING'), findsOneWidget);
      expect(briefing.motivation, isNotEmpty);
      expect(find.text(briefing.motivation), findsOneWidget);
    });

    testWidgets('rest day hides execute CTA', (tester) async {
      final briefing = DailyBriefing(
        greeting: 'Good morning, Lee.',
        sessionHeadline: 'Today is a Recovery day.',
        trainingFocus: 'Recovery',
        motivation: 'Recovery is part of the work.',
        standards: DailyBriefingService.defaultStandards,
        hasActivePlan: true,
        isRestDay: true,
        planName: 'Fat Loss Foundation',
        weekDayLabel: 'Week 1 · Day 3',
        estimatedDurationMinutes: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyBriefingSection(briefing: briefing),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rest day'), findsOneWidget);
      expect(find.text('EXECUTE TODAY\'S TRAINING'), findsNothing);
    });
  });
}

void _bindSession({
  required String sessionName,
  required String trainingIntent,
  required int duration,
  String displayName = 'Lee',
}) {
  final now = DateTime.utc(2026, 7, 29);
  final plan = PlanCatalog.byId('plan.hyrox_race_ready')!;
  final assignment = PlanAssignment(
    assignmentId: 'a1',
    athleteId: 'athlete.lee',
    planId: plan.planId,
    assignedAt: now,
    currentWeek: 4,
    currentDay: 2,
    currentPhase: 'Build',
  );
  final execution = SessionExecutionPlan(
    sessionId: 's1',
    sessionTitle: sessionName,
    durationMin: duration,
    blocks: const [
      SessionExecutionBlock(
        blockId: 'b1',
        title: 'Primary',
        blockType: SessionBlockType.conditioning,
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [],
      ),
    ],
  );
  final context = PlanningContext(
    orchestrationId: 'orch',
    startedAt: now,
    completedAt: now,
    orchestrationStatus: OrchestrationStatus.complete,
    input: PlanningInput(
      athleteId: 'athlete.lee',
      goalContext: PlanningGoalContext(goalId: plan.ontologyGoalId),
      capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
      knowledgeOntologyVersion: '1.3.0',
      asOf: now,
    ),
    sessionExecutionPlan: execution,
  );

  AthleteProfileSession.bind(
    profile: AthleteProfile(
      athleteId: 'athlete.lee',
      displayName: displayName,
      primaryGoal: plan.primaryGoal,
      availableEquipment: const ['cohort.equipment.bodyweight'],
      environmentId: 'cohort.environment.commercial_gym',
      trainingDaysPerWeek: 4,
      preferredSessionDurationMinutes: 60,
      experienceLevel: AthleteExperienceLevel.intermediate,
      assessmentComplete: true,
      createdAt: now,
      updatedAt: now,
    ),
    programme: AthleteGeneratedProgramme(
      planBundle: CoachBrainWorkoutPlan(
        planningContext: context,
        plan: execution,
        brief: WorkoutSessionBrief(
          sessionName: sessionName,
          estimatedDurationMinutes: duration,
          trainingIntent: trainingIntent,
          primaryFocus: trainingIntent,
        ),
      ),
      programmeName: plan.name,
      phaseLabel: 'Build',
    ),
    activePlan: plan,
    assignment: assignment,
  );
}
