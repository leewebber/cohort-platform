import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell destinations keep Home, Calendar and Progress separate', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
    await tester.pumpAndSettle();

    expect(find.text('VIEW PROGRAMMES'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('No programme scheduled'), findsNothing);
    expect(find.text('Programmes'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(AthleteCalendarScreen), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);
    expect(
      find.text('No programme scheduled').evaluate().isNotEmpty ||
          find
              .text(
                'This programme version is temporarily unavailable. Your '
                'training has not been changed.',
              )
              .evaluate()
              .isNotEmpty,
      isTrue,
    );

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('PROGRESS'), findsWidgets);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('VIEW PROGRAMMES'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
  });
}
