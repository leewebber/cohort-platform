import 'package:cohort_platform/features/adaptive_progression/models/capability_timeline.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
  });

  group('Progress UI (Phase 2.9 — ProgressSummaryService deleted)', () {
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
      final summary = ProgressSummary(
        hasActivePlan: true,
        planName: 'Fat Loss Foundation',
        weekLabel: 'Week 1 · Day 2',
        phaseLabel: 'Foundation',
        sessionsCompleted: 1,
        compliance: const ProgressCompliance(
          completed: 1,
          planned: 2,
          percentage: 50,
          currentStreak: 1,
          longestStreak: 1,
        ),
        recentImprovements: const ['Work Capacity ↑'],
        timeline: [
          CapabilityTimelineEvent(
            eventId: 'e1',
            recordedAt: now,
            capabilityId: 'cohort.capability.work_capacity',
            label: 'Work Capacity',
            direction: CapabilityChangeDirection.up,
          ),
        ],
        history: [
          ProgressSessionHistoryItem(
            completedAt: now,
            planName: 'Fat Loss Foundation',
            sessionName: 'Foundation Day',
            completionRatio: 1,
            duration: const Duration(minutes: 40),
            sessionRpe: 6,
          ),
        ],
        upcoming: const ProgressUpcoming(
          nextAssessmentLabel: 'Next assessment soon',
          nextMilestoneLabel: 'Next milestone soon',
          currentPhase: 'Foundation',
          weekLabel: 'Week 1 · Day 2',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ProgressScreen(summary: summary)),
      );
      await tester.pump();

      expect(find.text('Fat Loss Foundation'), findsWidgets);
      expect(find.textContaining('Work Capacity'), findsWidgets);
      expect(find.text('CAPABILITY OVERVIEW'), findsOneWidget);
      expect(find.text('CURRENT PLAN PROGRESS'), findsOneWidget);
    });
  });
}
