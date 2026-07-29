import 'package:cohort_platform/features/adaptive_progression/models/capability_timeline.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/progress_summary_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
  });

  group('ProgressSummaryService compliance', () {
    test('computes completed, planned, percentage, and streaks', () {
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final assignment = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: DateTime.utc(2026, 7, 27),
        currentWeek: 1,
        currentDay: 3,
        currentPhase: 'Foundation',
      );

      final completions = [
        SessionCompletion(
          completionId: 'c1',
          athleteId: 'athlete.lee',
          completedAt: DateTime.utc(2026, 7, 27, 10),
          exercisesCompleted: 4,
          totalExercises: 4,
          sessionRpe: 6,
          planName: plan.name,
          sessionName: 'Session A',
        ),
        SessionCompletion(
          completionId: 'c2',
          athleteId: 'athlete.lee',
          completedAt: DateTime.utc(2026, 7, 28, 10),
          exercisesCompleted: 4,
          totalExercises: 4,
          sessionRpe: 6,
          planName: plan.name,
          sessionName: 'Session B',
        ),
      ];

      const service = ProgressSummaryService();
      final compliance = service.computeCompliance(
        completions: completions,
        assignment: assignment,
        plan: plan,
        asOf: DateTime.utc(2026, 7, 28),
      );

      expect(compliance.completed, 2);
      expect(compliance.planned, 2);
      expect(compliance.percentage, 100);
      expect(compliance.currentStreak, 2);
      expect(compliance.longestStreak, 2);
    });
  });

  group('Capability timeline + improvements', () {
    test('recent improvements use upward timeline language', () {
      const service = ProgressSummaryService();
      final lines = service.recentImprovements(
        timeline: [
          CapabilityTimelineEvent(
            eventId: 'e1',
            recordedAt: DateTime.utc(2026, 7, 28),
            capabilityId: 'cohort.capability.threshold',
            label: 'Threshold Capacity',
            direction: CapabilityChangeDirection.up,
          ),
          CapabilityTimelineEvent(
            eventId: 'e2',
            recordedAt: DateTime.utc(2026, 7, 28),
            capabilityId: 'cohort.capability.pushing_strength',
            label: 'Upper Body Strength',
            direction: CapabilityChangeDirection.up,
          ),
        ],
        compliance: const ProgressCompliance(
          completed: 2,
          planned: 2,
          percentage: 100,
          currentStreak: 2,
          longestStreak: 2,
        ),
        completions: [
          SessionCompletion(
            completionId: 'c1',
            athleteId: 'a',
            completedAt: DateTime.utc(2026, 7, 27),
            exercisesCompleted: 3,
            totalExercises: 3,
            sessionRpe: 6,
          ),
          SessionCompletion(
            completionId: 'c2',
            athleteId: 'a',
            completedAt: DateTime.utc(2026, 7, 28),
            exercisesCompleted: 3,
            totalExercises: 3,
            sessionRpe: 6,
          ),
        ],
      );

      expect(lines, contains('Threshold Capacity ↑'));
      expect(lines, contains('Upper Body Strength ↑'));
      expect(lines, contains('Training Consistency ↑'));
      expect(lines, contains('Recovery Compliance ↑'));
    });
  });

  group('Progress summary + history', () {
    test('build includes history and upcoming from active plan', () {
      final plan = PlanCatalog.byId('plan.strength_emphasis')!;
      final assignment = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: DateTime.utc(2026, 7, 20),
        currentWeek: 2,
        currentDay: 1,
        currentPhase: 'Foundation',
      );

      SessionCompletionStore.add(
        SessionCompletion(
          completionId: 'c1',
          athleteId: 'athlete.lee',
          completedAt: DateTime.utc(2026, 7, 28, 9),
          exercisesCompleted: 5,
          totalExercises: 5,
          duration: const Duration(minutes: 48),
          sessionRpe: 7,
          planName: plan.name,
          sessionName: 'Strength Focus',
        ),
      );

      CapabilityTimelineStore.add(
        CapabilityTimelineEvent(
          eventId: 'e1',
          recordedAt: DateTime.utc(2026, 7, 28),
          capabilityId: 'cohort.capability.relative_strength',
          label: 'Relative Strength',
          direction: CapabilityChangeDirection.up,
        ),
      );

      final summary = const ProgressSummaryService().build(
        activePlan: plan,
        assignment: assignment,
        asOf: DateTime.utc(2026, 7, 28),
      );

      expect(summary.hasActivePlan, isTrue);
      expect(summary.planName, plan.name);
      expect(summary.history, hasLength(1));
      expect(summary.history.first.sessionName, 'Strength Focus');
      expect(summary.history.first.sessionRpe, 7);
      expect(summary.timeline, isNotEmpty);
      expect(summary.upcoming, isNotNull);
      expect(summary.upcoming!.currentPhase, 'Foundation');
      expect(summary.upcoming!.weekLabel, 'Week 2 · Day 1');
    });
  });

  group('Progress UI', () {
    testWidgets('empty state when no active plan', (tester) async {
      const empty = ProgressSummary(
        hasActivePlan: false,
        sessionsCompleted: 0,
        compliance: ProgressCompliance(
          completed: 0,
          planned: 0,
          percentage: 0,
          currentStreak: 0,
          longestStreak: 0,
        ),
        recentImprovements: [],
        timeline: [],
        history: [],
        upcoming: null,
      );
      await tester.pumpWidget(
        const MaterialApp(home: ProgressScreen(summary: empty)),
      );
      await tester.pump();
      expect(find.text('Am I getting better?'), findsOneWidget);
      expect(find.textContaining('capability profile'), findsOneWidget);
      expect(find.text('CHOOSE A PLAN'), findsOneWidget);
    });

    testWidgets('shows plan summary and improvements', (tester) async {
      final now = DateTime.utc(2026, 7, 28);
      final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
      final assignment = PlanAssignment(
        assignmentId: 'a1',
        athleteId: 'athlete.lee',
        planId: plan.planId,
        assignedAt: now,
        currentWeek: 1,
        currentDay: 2,
        currentPhase: 'Foundation',
      );

      final summary = const ProgressSummaryService().build(
        activePlan: plan,
        assignment: assignment,
        completions: [
          SessionCompletion(
            completionId: 'c1',
            athleteId: 'athlete.lee',
            completedAt: now,
            exercisesCompleted: 3,
            totalExercises: 3,
            sessionRpe: 6,
            planName: plan.name,
            sessionName: 'Foundation Day',
            duration: const Duration(minutes: 40),
          ),
        ],
        timeline: [
          CapabilityTimelineEvent(
            eventId: 'e1',
            recordedAt: now,
            capabilityId: 'cohort.capability.work_capacity',
            label: 'Work Capacity',
            direction: CapabilityChangeDirection.up,
          ),
        ],
        asOf: now,
      );

      await tester.pumpWidget(
        MaterialApp(home: ProgressScreen(summary: summary)),
      );
      await tester.pump();

      expect(find.text('Fat Loss Foundation'), findsWidgets);
      expect(find.textContaining('Work Capacity'), findsWidgets);
      expect(find.text('CAPABILITY OVERVIEW'), findsOneWidget);
      expect(find.text('CURRENT PLAN PROGRESS'), findsOneWidget);
      expect(find.text('SESSION HISTORY'), findsNothing);
    });
  });
}
