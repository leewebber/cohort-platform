import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_session_port.dart';

const _forbiddenProductionLabels = <String>[
  'Analyze Current Protocol',
  'Compare BW-001 Similarity',
  'Compile RN-006 Interval Plan',
  'Compile Circuit Debug Plans',
  'Compare BW-001 Suitable Alternatives',
  'Assign Test Programme',
  'Resolve Test Programme',
  'Sync Resolved Session',
  'Complete Current Programme Slot',
  'Complete Current Slot Partial',
  'Reset Test Programme Assignment',
  'Install Founder Acceptance Programme',
  'Assign Founder Acceptance Programme',
  'Resolve Founder Acceptance Programme',
  'Reset Founder Acceptance Programme',
  'Admin Protocol Editor',
  'DEBUG',
];

Future<void> _pumpHome(
  WidgetTester tester, {
  required UserProfile profile,
  AuthController? authController,
}) async {
  CurrentUserSession.bind(profile);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(authController: authController),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CurrentUserSession.clear();
    InternalToolsPolicy.reset();
  });

  group('Production home navigation', () {
    testWidgets('athlete-only profile sees athlete destinations only', (tester) async {
      await _pumpHome(
        tester,
        profile: const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Training History'), findsOneWidget);
      expect(find.text('Adjust Today’s Session'), findsOneWidget);
      expect(find.text('Protocol Library'), findsOneWidget);
      expect(find.text('Help & feedback'), findsOneWidget);

      expect(find.text('Coach Studio'), findsNothing);
      expect(find.text('My Athletes'), findsNothing);
      expect(find.text('Internal tools'), findsNothing);

      for (final label in _forbiddenProductionLabels) {
        expect(find.text(label), findsNothing, reason: 'Found forbidden label: $label');
      }
    });

    testWidgets('coach-only profile sees coach destinations without athlete Today', (tester) async {
      await _pumpHome(
        tester,
        profile: const UserProfile(
          id: 'coach-1',
          displayName: 'Sam',
          isCoach: true,
          isAthlete: false,
        ),
      );

      expect(find.text('Coach Studio'), findsOneWidget);
      expect(find.text('My Athletes'), findsOneWidget);
      expect(find.textContaining('Manage athletes and programmes'), findsOneWidget);

      expect(find.text('Training History'), findsNothing);
      expect(find.text('Adjust Today’s Session'), findsNothing);
      expect(find.text('Internal tools'), findsNothing);

      for (final label in _forbiddenProductionLabels) {
        expect(find.text(label), findsNothing, reason: 'Found forbidden label: $label');
      }
    });

    testWidgets('dual-role profile sees athlete and coach sections', (tester) async {
      await _pumpHome(
        tester,
        profile: const UserProfile(
          id: 'dual-1',
          displayName: 'Lee',
          isCoach: true,
          isAthlete: true,
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Training History'), findsOneWidget);
      expect(find.text('Coach Studio'), findsOneWidget);
      expect(find.text('My Athletes'), findsOneWidget);
      expect(find.text('Internal tools'), findsNothing);

      for (final label in _forbiddenProductionLabels) {
        expect(find.text(label), findsNothing, reason: 'Found forbidden label: $label');
      }
    });

    testWidgets('internal tools entry appears only when explicitly enabled', (tester) async {
      InternalToolsPolicy.enableForTesting();

      await _pumpHome(
        tester,
        profile: const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(find.text('Internal tools'), findsOneWidget);
      await tester.ensureVisible(find.text('Internal tools'));
      await tester.tap(find.text('Internal tools'));
      await tester.pumpAndSettle();

      expect(find.text('Assign Test Programme'), findsOneWidget);
      expect(find.text('Admin Protocol Editor'), findsOneWidget);
    });

    testWidgets('account header opens account surface when controller provided', (tester) async {
      final auth = AuthController(authService: FakeAuthSessionPort());
      await auth.initialize();

      await _pumpHome(
        tester,
        profile: const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
        authController: auth,
      );

      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
    });
  });
}
