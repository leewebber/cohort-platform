import 'dart:ui' show Tristate;

import 'package:cohort_platform/core/widgets/cohort_athlete_bottom_nav_bar.dart';
import 'package:cohort_platform/core/widgets/cohort_brand_lockup.dart';
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CurrentUserSession.clear();
    AthleteProfileSession.clear();
  });

  testWidgets('authenticated Home shows lockup and time-aware first name', (
    tester,
  ) async {
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayNotStarted,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          embeddedInShell: true,
          assignmentStore: bundle.assignmentStore,
          fixedOccurrenceStore: bundle.projectionStore,
          prepareService: bundle.prepare,
          greetingNowUtc: () => DateTime.utc(2026, 9, 10, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CohortBrandLockup), findsOneWidget);
    expect(find.text('COHORT'), findsOneWidget);
    expect(find.byKey(const ValueKey('cohort-brand-mark')), findsOneWidget);
    expect(find.text('Good morning, Lee'), findsOneWidget);
    expect(find.text('Cohort Performance Ltd'), findsNothing);
    expect(find.text('Human Performance Platform'), findsNothing);
    expect(find.text('Apollo Strength'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('Incomplete'), findsNothing);
    expect(find.text('Apollo Intervals'), findsNothing);
    expect(find.byType(AthleteCalendarScreen), findsNothing);
  });

  testWidgets('missing first name does not block Home', (tester) async {
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayNotStarted,
    );
    CurrentUserSession.bind(
      const UserProfile(
        id: previewAthleteId,
        displayName: '',
        isCoach: false,
        isAthlete: true,
      ),
    );
    AthleteProfileSession.bind(
      profile: AthleteProfileSession.profile!.copyWith(displayName: ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          embeddedInShell: true,
          assignmentStore: bundle.assignmentStore,
          fixedOccurrenceStore: bundle.projectionStore,
          prepareService: bundle.prepare,
          greetingNowUtc: () => DateTime.utc(2026, 9, 10, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Good morning, Lee'), findsNothing);
    expect(find.text('Apollo Strength'), findsOneWidget);
  });

  testWidgets('greeting uses assignment timezone not UTC', (tester) async {
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayNotStarted,
    );
    bundle.assignmentStore.assignment = bundle.assignmentStore.assignment
        .copyWith(timezone: 'America/New_York');
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          embeddedInShell: true,
          assignmentStore: bundle.assignmentStore,
          fixedOccurrenceStore: bundle.projectionStore,
          prepareService: bundle.prepare,
          greetingNowUtc: () => DateTime.utc(2026, 9, 11, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good evening, Lee'), findsOneWidget);
    expect(find.text('Good morning, Lee'), findsNothing);
  });

  testWidgets('completed today expands results on Home', (tester) async {
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayComplete,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          embeddedInShell: true,
          assignmentStore: bundle.assignmentStore,
          fixedOccurrenceStore: bundle.projectionStore,
          prepareService: bundle.prepare,
          performanceRecordStore: bundle.performance,
          greetingNowUtc: () => DateTime.utc(2026, 9, 10, 8),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AthleteHomeCompletedTodayCard), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();
    expect(find.text('Hide results'), findsOneWidget);
    expect(
      find.text('First recorded performance — no previous comparable result.'),
      findsOneWidget,
    );
  });

  testWidgets('shell keeps five destinations and preserves tab state', (
    tester,
  ) async {
    final bundle = AthleteShellPreviewBundle.seed(
      AthleteShellPreviewScenario.todayNotStarted,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteAppShell(
          assignmentStore: bundle.assignmentStore,
          fixedOccurrenceStore: bundle.projectionStore,
          prepareService: bundle.prepare,
          executionLauncher: bundle.execution,
          previewService: bundle.previewService,
          performanceRecordStore: bundle.performance,
          progressBuilder: bundle.progressBuilder,
          swapStore: bundle.swapStore,
          programmeScreenController: bundle.programmeController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CohortAthleteBottomNavBar), findsOneWidget);
    for (final label in const [
      'Home',
      'Calendar',
      'Programmes',
      'Progress',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byType(CohortBrandLockup), findsWidgets);
    expect(find.textContaining('Lee'), findsWidgets);
    expect(find.text('Apollo Strength'), findsOneWidget);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(AthleteCalendarScreen), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('Incomplete'), findsWidgets);
    expect(find.text('Apollo Intervals'), findsOneWidget);

    await tester.tap(find.text('Programmes'));
    await tester.pumpAndSettle();
    expect(find.byType(AthleteProgrammeScreen), findsOneWidget);
    expect(find.text('Programmes'), findsWidgets);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('PROGRESS'), findsWidgets);
    expect(find.text('Complete your first session to begin'), findsWidgets);
    expect(find.text('0 sessions completed'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Help & feedback'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Help & feedback'), findsOneWidget);
    expect(find.textContaining('supabase'), findsNothing);
    expect(find.textContaining('service_role'), findsNothing);
    expect(find.textContaining('JWT'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Apollo Strength'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.byType(AthleteAppShell), findsOneWidget);
  });

  testWidgets('narrow iPhone width keeps all five nav labels', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CohortAthleteBottomNavBar(
            selectedIndex: 0,
            onDestinationSelected: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const [
      'Home',
      'Calendar',
      'Programmes',
      'Progress',
      'Profile',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected tab is exposed as Semantics selected', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CohortAthleteBottomNavBar(
            selectedIndex: 2,
            onDestinationSelected: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final programmes = tester.getSemantics(find.text('Programmes'));
    expect(programmes.flagsCollection.isButton, isTrue);
    expect(programmes.flagsCollection.isSelected, Tristate.isTrue);
  });
}

void _noop(int index) {}
