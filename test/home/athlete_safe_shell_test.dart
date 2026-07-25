import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/core/widgets/coach_route_guard.dart';
import 'package:cohort_platform/features/coach_studio/coach_studio_home_screen.dart';
import 'package:cohort_platform/features/training_library/screens/training_library_screen.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/coach_operations/screens/coach_home_dashboard_screen.dart';
import 'package:cohort_platform/features/coach_operations/controllers/coach_home_dashboard_controller.dart';
import 'package:cohort_platform/features/coach_operations/services/coach_athlete_daily_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubDailyStatusService implements CoachAthleteDailyStatusService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    CurrentUserSession.clear();
    InternalToolsPolicy.reset();
  });

  testWidgets('athlete cannot open protected coach dashboard content', (
    tester,
  ) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'athlete-1',
        displayName: 'Alex',
        isCoach: false,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CoachHomeDashboardScreen(
          controller: CoachHomeDashboardController(
            dailyStatusService: _StubDailyStatusService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invite athlete'), findsNothing);
    expect(find.text('Go back'), findsOneWidget);
    expect(
      find.text('Coach access is required to open Coach Studio.'),
      findsOneWidget,
    );
  });

  testWidgets('CoachRouteGuard blocks child when coach access missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoachRouteGuard(
          child: const Text('SECRET COACH CONTENT'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SECRET COACH CONTENT'), findsNothing);
    expect(find.text('Go back'), findsOneWidget);
  });

  testWidgets('athlete cannot access Coach Studio home screen', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'athlete-1',
        displayName: 'Alex',
        isCoach: false,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CoachStudioHomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authoring tools'), findsNothing);
    expect(find.text('Go back'), findsOneWidget);
  });

  testWidgets('athlete cannot access Training Library screen', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'athlete-1',
        displayName: 'Alex',
        isCoach: false,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: TrainingLibraryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Browse official Cohort Protocols'), findsNothing);
    expect(find.text('Go back'), findsOneWidget);
  });

  testWidgets('coach retains access to Coach Studio home', (tester) async {
    CurrentUserSession.bind(
      const UserProfile(
        id: 'coach-1',
        displayName: 'Sam',
        isCoach: true,
        isAthlete: false,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CoachStudioHomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authoring tools'), findsOneWidget);
    expect(find.text('Go back'), findsNothing);
  });

  testWidgets('founder build retains Coach Studio home access', (tester) async {
    InternalToolsPolicy.enableForTesting();
    CurrentUserSession.bind(
      const UserProfile(
        id: 'founder-1',
        displayName: 'Founder',
        isCoach: false,
        isAthlete: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CoachStudioHomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Authoring tools'), findsOneWidget);
  });
}
