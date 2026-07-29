import 'package:cohort_platform/core/access/app_access_role.dart';
import 'package:cohort_platform/core/access/app_experience_resolver.dart';
import 'package:cohort_platform/core/access/founder_access_config.dart';
import 'package:cohort_platform/core/access/founder_access_policy.dart';
import 'package:cohort_platform/core/widgets/cohort_athlete_bottom_nav_bar.dart';
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/app_shell/founder_workspace_shell.dart';
import 'package:cohort_platform/features/app_shell/screens/athlete_profile_screen.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/widgets/athlete_generated_today_section.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/capability_radar_projection_service.dart';
import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/features/workout_player/services/previous_performance_resolver.dart';
import 'package:cohort_platform/features/workout_player/widgets/workout_player_widgets.dart';
import 'package:cohort_platform/core/presentation/athlete_safe_error_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CurrentUserSession.clear();
    FounderAccessPolicy.reset();
    PreviousPerformanceStore.clear();
    SessionCompletionStore.clear();
    AthleteProfileSession.clear();
  });

  group('Founder access policy', () {
    test('defaults to athlete — coach role does not imply founder', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'a1',
          displayName: 'Alex',
          isCoach: true,
          isAthlete: true,
        ),
      );
      expect(
        const AppExperienceResolver().resolve(email: 'coach@example.com'),
        AppAccessRole.athlete,
      );
    });

    test('allowlist email receives founder', () {
      FounderAccessPolicy.configure(
        const FounderAccessConfig(allowedEmails: {'lee@cohort.test'}),
      );
      expect(
        const AppExperienceResolver().resolve(email: 'lee@cohort.test'),
        AppAccessRole.founder,
      );
      expect(
        const AppExperienceResolver().resolve(email: 'other@example.com'),
        AppAccessRole.athlete,
      );
    });

    test('development override authorises founder without email', () {
      FounderAccessPolicy.configure(
        const FounderAccessConfig(developmentOverride: true),
      );
      expect(
        const AppExperienceResolver().resolve(email: null),
        AppAccessRole.founder,
      );
    });

    test('policy is configurable and resettable', () {
      FounderAccessPolicy.configure(
        const FounderAccessConfig(allowedEmails: {'a@b.com'}),
      );
      expect(FounderAccessPolicy.isAuthorisedFounder(email: 'a@b.com'), isTrue);
      FounderAccessPolicy.reset();
      expect(FounderAccessPolicy.isAuthorisedFounder(email: 'a@b.com'), isFalse);
    });
  });

  group('Athlete navigation', () {
    test('athlete shell exposes exactly four destinations', () {
      expect(AthleteAppShell.destinations.length, 4);
      expect(
        AthleteAppShell.destinations.map((d) => d.label).toList(),
        ['Home', 'Plans', 'Progress', 'Profile'],
      );
      expect(
        AthleteAppShell.destinations.map((d) => d.label),
        isNot(contains('Sessions')),
      );
      expect(
        AthleteAppShell.destinations.map((d) => d.label),
        isNot(contains('Knowledge')),
      );
    });

    testWidgets('athlete shell bottom bar has four tabs only', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AthleteAppShell()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sessions'), findsNothing);
      expect(find.text('My Athletes'), findsNothing);
      expect(find.text('Coach Studio'), findsNothing);
      expect(find.text('Protocol Library'), findsNothing);
      expect(find.text('Exercise Library'), findsNothing);
      expect(find.text('Internal tools'), findsNothing);
    });

    testWidgets('default bottom nav destinations are four athlete tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CohortAthleteBottomNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      expect(CohortAthleteBottomNavBar.defaultDestinations.length, 4);
      expect(find.text('Sessions'), findsNothing);
    });
  });

  group('Founder workspace', () {
    testWidgets('founder shell shows workspace tools', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FounderWorkspaceShell()),
      );
      await tester.pump();

      expect(find.text('FOUNDER WORKSPACE'), findsOneWidget);
      expect(find.text('PREVIEW ATHLETE APP'), findsOneWidget);
      expect(find.text('My Athletes'), findsOneWidget);
      expect(find.text('Coach Studio'), findsWidgets);
    });
  });

  group('Home athlete surface', () {
    testWidgets('home has no history or knowledge cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(embeddedInShell: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Training History'), findsNothing);
      expect(find.text('Protocol Library'), findsNothing);
      expect(find.text('Exercise Library'), findsNothing);
      expect(find.text('My Athletes'), findsNothing);
      expect(find.text('Coach Studio'), findsNothing);
      expect(find.text('Help & feedback'), findsNothing);
      expect(find.text('Knowledge'), findsNothing);
    });

    testWidgets('profile exposes Training History', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AthleteProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Training History'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('no-plan copy is concise and not redundant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChoosePlanEntryCard(onChoosePlan: () {}),
          ),
        ),
      );
      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('Choose a Plan'), findsOneWidget);
      expect(find.text('BROWSE PLANS'), findsOneWidget);
      expect(find.text('Choose Your First Plan'), findsNothing);
      expect(find.textContaining('No plan assigned'), findsNothing);
      expect(find.textContaining('Start with a plan'), findsNothing);
    });
  });

  group('Progress honesty', () {
    test('radar does not fabricate unsupported scores', () {
      final model = const CapabilityRadarProjectionService().project(
        timeline: const [],
        compliance: null,
      );
      expect(model.hasAnyEvidence, isFalse);
      for (final axis in model.axes) {
        if (axis.dimension != CapabilityRadarDimension.discipline) {
          expect(axis.available, isFalse);
          expect(axis.normalisedValue, isNull);
        }
      }
    });

    testWidgets('empty progress shows placeholders and CTA', (tester) async {
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
      expect(find.text('CAPABILITY OVERVIEW'), findsOneWidget);
    });
  });

  group('Previous performance', () {
    test('strength performance resolves by exercise id', () {
      PreviousPerformanceStore.record(
        PreviousPerformanceSnapshot(
          exerciseId: 'ex.squat',
          sessionType: PreviousPerformanceSessionType.strength,
          performedAt: DateTime(2026, 7, 1),
          loadSummary: '100 kg',
          setSummary: '3 × 10',
          rpe: 8,
        ),
      );
      final snap = const PreviousPerformanceResolver().resolveLatest(
        exerciseId: 'ex.squat',
      );
      expect(snap, isNotNull);
      expect(snap!.loadSummary, '100 kg');
      expect(snap.setSummary, '3 × 10');
      expect(snap.rpe, 8);
    });

    test('interval performance resolves correctly', () {
      PreviousPerformanceStore.record(
        PreviousPerformanceSnapshot(
          exerciseId: 'ex.800m',
          sessionType: PreviousPerformanceSessionType.runningInterval,
          performedAt: DateTime(2026, 7, 20),
          setSummary: '3 × 800 m',
          paceSummary: 'Average pace 4:45/km',
        ),
      );
      final snap = const PreviousPerformanceResolver().resolveLatest(
        exerciseId: 'ex.800m',
      );
      expect(snap!.paceSummary, contains('4:45'));
      expect(snap.setSummary, '3 × 800 m');
    });

    test('no prior history returns null', () {
      expect(
        const PreviousPerformanceResolver().resolveLatest(
          exerciseId: 'ex.missing',
        ),
        isNull,
      );
    });

    testWidgets('player section renders last time when snapshot present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviousPerformanceSection(
              snapshot: PreviousPerformanceSnapshot(
                exerciseId: 'ex.squat',
                sessionType: PreviousPerformanceSessionType.strength,
                performedAt: DateTime(2026, 7, 1),
                loadSummary: '100 kg',
                setSummary: '3 × 10',
                rpe: 8,
              ),
            ),
          ),
        ),
      );
      expect(find.text('LAST TIME'), findsOneWidget);
      expect(find.text('100 kg'), findsOneWidget);
      expect(find.text('3 × 10'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
    });

    testWidgets('no media placeholder without media', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExerciseMediaSlot()),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    });
  });

  group('Athlete-safe errors', () {
    test('presenter returns calm fallback without engine terms', () {
      final message = AthleteSafeErrorPresenter.message(
        StateError('ExecutionPlan Blueprint planning_engine_v2'),
        fallback: "We couldn't prepare today's training.",
      );
      expect(message.toLowerCase(), isNot(contains('executionplan')));
      expect(message.toLowerCase(), isNot(contains('blueprint')));
      expect(message.toLowerCase(), isNot(contains('planning_engine')));
    });
  });
}
