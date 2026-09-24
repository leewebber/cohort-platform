import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/main_completion_history_integrity_preview.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_fixture.dart';
import 'package:cohort_platform/preview/completion_history_integrity_preview_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  Future<void> pumpBounded(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 800, height: 1200, child: child),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('completedProgrammes fixture renders completed continuity', (
    tester,
  ) async {
    await pumpBounded(
      tester,
      CompletionHistoryPreviewFixtures.completedProgrammesScreen(),
    );
    expect(find.byType(AthleteProgrammeScreen), findsOneWidget);
    expect(find.text('COMPLETED PROGRAMME'), findsOneWidget);
    expect(find.text('Apollo Strength'), findsWidgets);
    expect(find.text('Complete'), findsWidgets);
    expect(find.text('You completed Apollo Strength.'), findsOneWidget);
    expect(
      find.text('You can still review the programme and your results.'),
      findsOneWidget,
    );
    expect(find.text('Completed 1 September'), findsOneWidget);
    expect(find.text('12 weeks'), findsOneWidget);
    expect(find.text('Browse programmes'), findsOneWidget);
    expect(find.text('View Programme Calendar'), findsOneWidget);
    expect(find.text('CURRENT PROGRAMME'), findsNothing);
    expect(find.text('Week 1 · Day 1'), findsNothing);
    expect(find.textContaining('Week 1'), findsNothing);
    expect(find.textContaining("Today's authored session"), findsNothing);
    expect(find.textContaining('available on Home'), findsNothing);
    expect(find.textContaining('Completed-programme preview fixture'), findsNothing);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Start Programme'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active Programmes composition stays current', (tester) async {
    await pumpBounded(
      tester,
      CompletionHistoryPreviewFixtures.activeProgrammesScreen(),
    );
    expect(find.text('CURRENT PROGRAMME'), findsOneWidget);
    expect(find.text('Apollo Strength'), findsWidgets);
    expect(find.text('Week 1 · Day 1'), findsOneWidget);
    expect(
      find.text("Today's authored session is available on Home."),
      findsOneWidget,
    );
    expect(find.text('COMPLETED PROGRAMME'), findsNothing);
    expect(find.text('You completed Apollo Strength.'), findsNothing);
    expect(
      find.text('You can still review the programme and your results.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed plus new active keeps current assignment and historical completed',
    (tester) async {
      await pumpBounded(
        tester,
        CompletionHistoryPreviewFixtures.completedPlusNewActiveProgrammesScreen(),
      );
      expect(find.text('CURRENT PROGRAMME'), findsOneWidget);
      expect(find.text('Spartan'), findsWidgets);
      expect(find.text('Spartan is your current programme.'), findsOneWidget);
      expect(
        find.text('Your completed Apollo Strength results remain in History.'),
        findsOneWidget,
      );
      expect(find.text('Week 2 · Day 1'), findsOneWidget);
      expect(find.text('COMPLETED PROGRAMME'), findsNothing);
      expect(find.text('You completed Apollo Strength.'), findsNothing);
      expect(find.text('Week 1 · Day 1'), findsNothing);
      expect(find.text('Completed-programme preview fixture.'), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progressRefreshFailed fixture keeps last-good and Retry', (
    tester,
  ) async {
    final builder = RefreshFailingProgressBuilder();
    await pumpBounded(
      tester,
      CompletionHistoryPreviewFixtures.progressRefreshFailed(
        progressBuilder: builder,
      ),
    );
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('8 sessions completed'), findsOneWidget);
    expect(find.text('Refresh failed'), findsOneWidget);
    expect(find.text('Couldn’t refresh progress'), findsOneWidget);
    expect(
      find.text('Showing your most recently loaded progress.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No recorded sessions yet.'), findsNothing);
    expect(builder.builds, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(builder.builds, 2);
    expect(find.text('8 sessions completed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh failure retains last-good only for the same athlete', (
    tester,
  ) async {
    final seen = <String>[];
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressScreen(
          key: const ValueKey('progress-state'),
          athleteIdOverride: 'athlete-a',
          summary: CompletionHistoryPreviewFixtures.lastGoodProgress(),
          progressBuilder: RefreshFailingProgressBuilder(onBuild: seen.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 sessions completed'), findsOneWidget);
    expect(seen, ['athlete-a']);

    await tester.pumpWidget(
      MaterialApp(
        home: ProgressScreen(
          key: const ValueKey('progress-state'),
          athleteIdOverride: 'athlete-b',
          summary: CompletionHistoryPreviewFixtures.lastGoodProgress(),
          progressBuilder: RefreshFailingProgressBuilder(onBuild: seen.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, ['athlete-a', 'athlete-b']);
    expect(find.text('Progress couldn’t be loaded'), findsOneWidget);
    expect(find.text('8 sessions completed'), findsNothing);
  });

  testWidgets('sign-out clears last-good Progress', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressScreen(
          key: const ValueKey('progress-state'),
          athleteIdOverride: previewAthleteId,
          summary: CompletionHistoryPreviewFixtures.lastGoodProgress(),
          progressBuilder: RefreshFailingProgressBuilder(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 sessions completed'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProgressScreen(key: ValueKey('progress-state')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 sessions completed'), findsNothing);
    expect(
      find.text('We couldn’t open your athlete profile'),
      findsOneWidget,
    );
  });

  testWidgets('preview completedProgrammes and progressRefreshFailed are not blank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      const CompletionHistoryIntegrityPreviewApp(
        initialState: CompletionPreviewState.completedProgrammes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED PROGRAMME'), findsOneWidget);
    expect(find.text('You completed Apollo Strength.'), findsOneWidget);
    expect(find.text('CURRENT PROGRAMME'), findsNothing);
    expect(find.text('Week 1 · Day 1'), findsNothing);
    expect(find.text('Begin'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const CompletionHistoryIntegrityPreviewApp(
        initialState: CompletionPreviewState.progressRefreshFailed,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Refresh failed'), findsOneWidget);
    expect(find.text('Couldn’t refresh progress'), findsOneWidget);
    expect(find.text('8 sessions completed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('preview fixture names route to production states', () {
    expect(
      CompletionPreviewState.completedProgrammes.name,
      'completedProgrammes',
    );
    expect(
      CompletionPreviewState.progressRefreshFailed.name,
      'progressRefreshFailed',
    );
    expect(
      CompletionHistoryPreviewFixtures.completedProgrammesScreen().runtimeType,
      AthleteProgrammeScreen,
    );
    expect(
      CompletionHistoryPreviewFixtures.progressRefreshFailed().runtimeType,
      ProgressScreen,
    );
    expect(previewAthleteId, isNotEmpty);
  });
}
