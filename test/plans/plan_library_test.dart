
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_planning_input_builder.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/plans/services/plan_assignment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';

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
      expect(
        assignments.readActiveAssignment()?.assignmentId,
        first.assignmentId,
      );
      expect(assignments.readActivePlan()?.planId, planA.planId);
      expect(assignments.hasActivePlan, isTrue);

      final second = assignments.replaceActivePlan(
        athleteId: 'athlete.lee',
        plan: planB,
      );
      expect(second.planId, planB.planId);
      expect(assignments.readActivePlan()?.planId, planB.planId);
      expect(assignments.history(), hasLength(1));
      expect(
        assignments.history().first.status,
        PlanAssignmentStatus.cancelled,
      );

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
        result.every(
          (p) => p.experienceLevel == AthleteExperienceLevel.beginner,
        ),
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
        contains(
          '${AthletePlanningInputBuilder.planIdTagPrefix}${plan.planId}',
        ),
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


  group('Home empty state (Phase 2.8/2.9)', () {
    testWidgets('empty state invites catalogue programmes', (tester) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
      );
      final tables = InMemoryProgrammeTables();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a programme'), findsOneWidget);
      expect(find.text('VIEW PROGRAMMES'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Programme'), findsOneWidget);
      expect(find.text("EXECUTE TODAY'S TRAINING"), findsNothing);
      expect(find.textContaining('Daily Briefing'), findsNothing);
      expect(find.text('NEED TO ADAPT?'), findsNothing);
    });
  });
}
