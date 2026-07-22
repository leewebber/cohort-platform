import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/widgets/home_today_session_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CurrentUserSession.clear);

  testWidgets('dual-role empty state shows CHOOSE PROGRAMME', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'lee',
        displayName: 'Lee',
        isCoach: true,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTodaySessionSection(
          athleteId: 'lee',
          loadOverride: (_) async => const HomeTodaySessionEmpty(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Set up your training'), findsOneWidget);
    expect(find.text('CHOOSE PROGRAMME'), findsOneWidget);
    expect(find.textContaining('published programme'), findsOneWidget);
  });

  testWidgets('athlete-only empty state keeps join-coach guidance', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'alex',
        displayName: 'Alex',
        isCoach: false,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTodaySessionSection(
            athleteId: 'alex',
            loadOverride: (_) async => const HomeTodaySessionEmpty(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No programme assigned'), findsOneWidget);
    expect(find.textContaining('Join your coach'), findsOneWidget);
    expect(find.text('CHOOSE PROGRAMME'), findsNothing);
  });

  testWidgets('coach-only user does not see athlete setup CTA', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'pat',
        displayName: 'Pat',
        isCoach: true,
        isAthlete: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTodaySessionSection(
          athleteId: 'pat',
          loadOverride: (_) async => const HomeTodaySessionEmpty(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('CHOOSE PROGRAMME'), findsNothing);
    expect(find.text('Set up your training'), findsNothing);
  });
}
