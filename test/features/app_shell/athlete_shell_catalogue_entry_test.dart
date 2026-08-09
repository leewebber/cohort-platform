import 'dart:io';

import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/plans/screens/plan_library_screen.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_selection_screen.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_programme_stores.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(AthleteProfileSession.clear);

  group('Phase 2.6 athlete shell catalogue entry', () {
    testWidgets('Plans tab opens canonical AthleteProgrammeScreen', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables();
      final controller = _controller(tables);
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteAppShell(programmeScreenController: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      expect(find.byType(AthleteProgrammeScreen), findsOneWidget);
      expect(find.byType(PlanLibraryScreen), findsNothing);
      expect(find.text('Choose your plan'), findsNothing);
      expect(find.text('START PLAN'), findsNothing);
      expect(find.text('CURRENT PROGRAMME'), findsOneWidget);
      expect(find.text('View programmes'), findsOneWidget);
    });

    testWidgets(
      'shell Plans entry cannot mount Plan Library or create hasActivePlan',
      (tester) async {
        expect(AthleteProfileSession.hasActivePlan, isFalse);
        final tables = InMemoryProgrammeTables();
        final controller = _controller(tables);
        await tester.pumpWidget(
          MaterialApp(
            home: AthleteAppShell(programmeScreenController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plans'));
        await tester.pumpAndSettle();

        expect(find.byType(PlanLibraryScreen), findsNothing);
        expect(AthleteProfileSession.hasActivePlan, isFalse);
        expect(AthleteProfileSession.activeAssignment, isNull);
        expect(AthleteProfileSession.activePlan, isNull);
      },
    );

    testWidgets(
      'View programmes reaches canonical selection screen (not Plan Library)',
      (tester) async {
        final tables = InMemoryProgrammeTables();
        final controller = _controller(tables);
        await tester.pumpWidget(
          MaterialApp(
            home: AthleteAppShell(programmeScreenController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plans'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View programmes'));
        await tester.pumpAndSettle();

        expect(find.byType(AthleteProgrammeSelectionScreen), findsOneWidget);
        expect(find.byType(PlanLibraryScreen), findsNothing);
        expect(find.text('Choose your plan'), findsNothing);
      },
    );

    testWidgets(
      'catalogue unavailable/error does not expose Plan Library fallback',
      (tester) async {
        // Controller with null stores → "Programme data is unavailable."
        final controller = AthleteProgrammeScreenController(
          athleteId: 'athlete.local',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AthleteAppShell(programmeScreenController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plans'));
        await tester.pumpAndSettle();

        expect(find.text('Programme data is unavailable.'), findsOneWidget);
        expect(find.byType(PlanLibraryScreen), findsNothing);
        expect(find.text('Choose your plan'), findsNothing);
        expect(find.text('START PLAN'), findsNothing);
      },
    );

    testWidgets(
      'catalogue empty enrolment does not expose Plan Library fallback',
      (tester) async {
        final tables = InMemoryProgrammeTables();
        final controller = _controller(tables);
        await tester.pumpWidget(
          MaterialApp(
            home: AthleteAppShell(programmeScreenController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plans'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('not enrolled in a programme'),
          findsOneWidget,
        );
        expect(find.byType(PlanLibraryScreen), findsNothing);
        expect(find.text('Choose your plan'), findsNothing);
      },
    );

    testWidgets(
      'opening catalogue does not mutate existing legacy hasActivePlan',
      (tester) async {
        _bindLegacyActivePlan();
        expect(AthleteProfileSession.hasActivePlan, isTrue);
        final assignmentBefore = AthleteProfileSession.activeAssignment;
        final planBefore = AthleteProfileSession.activePlan;

        final tables = InMemoryProgrammeTables();
        final controller = _controller(tables);
        await tester.pumpWidget(
          MaterialApp(
            home: AthleteAppShell(programmeScreenController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plans'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(AthleteProfileSession.hasActivePlan, isTrue);
        expect(
          AthleteProfileSession.activeAssignment?.assignmentId,
          assignmentBefore?.assignmentId,
        );
        expect(AthleteProfileSession.activePlan?.planId, planBefore?.planId);
        // Catalogue entry must not rewrite legacy session bind.
        expect(find.byType(PlanLibraryScreen), findsNothing);
      },
    );

    test(
      'athlete shell source closes Plan Library start and mounts programme screen',
      () {
        final root = _repoRoot(Directory.current);
        final shell = File(
          '$root/lib/features/app_shell/athlete_app_shell.dart',
        ).readAsStringSync();
        expect(shell.contains('AthleteProgrammeScreen'), isTrue);
        expect(shell.contains('embeddedInShell: true'), isTrue);
        expect(shell.contains('PlanLibraryScreen'), isFalse);
        expect(shell.contains('plan_library_screen'), isFalse);
        expect(shell.contains('PlanStartService'), isFalse);
        expect(shell.contains('startPlan('), isFalse);
      },
    );
  });
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return start.path;
    dir = dir.parent;
  }
}

AthleteProgrammeScreenController _controller(InMemoryProgrammeTables tables) {
  return AthleteProgrammeScreenController(
    athleteId: 'athlete.local',
    assignmentStore: InMemoryProgrammeAssignmentStore(tables),
    versionStore: InMemoryProgrammeVersionStore(tables),
  );
}

void _bindLegacyActivePlan() {
  final now = DateTime.utc(2026, 7, 29);
  final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
  final assignment = PlanAssignment(
    assignmentId: 'assignment.legacy',
    athleteId: 'athlete.local',
    planId: plan.planId,
    assignedAt: now,
    startedAt: now,
    currentPhase: 'Foundation',
    currentWeek: 1,
    currentDay: 1,
  );
  final execution = SessionExecutionPlan(
    sessionId: 'session.legacy',
    sessionTitle: 'Legacy Session',
    durationMin: 40,
    blocks: const [],
  );
  AthleteProfileSession.bind(
    profile: AthleteProfile(
      athleteId: 'athlete.local',
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
        planningContext: PlanningContext(
          orchestrationId: 'orch.legacy',
          startedAt: now,
          completedAt: now,
          orchestrationStatus: OrchestrationStatus.complete,
          input: PlanningInput(
            athleteId: 'athlete.local',
            goalContext: const PlanningGoalContext(
              goalId: 'cohort.goal.general_fat_loss',
            ),
            capabilityEvidence:
                const AthleteCapabilityEvidenceProfile(items: []),
            knowledgeOntologyVersion: '1.3.0',
            asOf: now,
          ),
        ),
        plan: execution,
        brief: const WorkoutSessionBrief(
          sessionName: 'Legacy Session',
          estimatedDurationMinutes: 40,
        ),
      ),
      programmeName: plan.name,
      phaseLabel: 'Foundation',
    ),
    activePlan: plan,
    assignment: assignment,
  );
}