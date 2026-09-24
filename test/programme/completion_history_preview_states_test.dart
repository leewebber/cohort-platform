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
    expect(find.text('Complete'), findsWidgets);
    expect(find.text('You completed Apollo Strength.'), findsOneWidget);
    expect(
      find.text('You can still review the programme and your results.'),
      findsOneWidget,
    );
    expect(find.text('Browse programmes'), findsOneWidget);
    expect(find.text('View Programme Calendar'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Start Programme'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('You completed Apollo Strength.'), findsOneWidget);
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
