import 'package:cohort_platform/core/access/founder_access_config.dart';
import 'package:cohort_platform/core/access/founder_access_policy.dart';
import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/app_shell/founder_workspace_shell.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CurrentUserSession.clear();
    InternalToolsPolicy.reset();
    FounderAccessPolicy.reset();
  });

  group('Production athlete Home', () {
    testWidgets('athlete Home has no founder/knowledge/history cards', (
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
        const MaterialApp(home: HomeScreen(embeddedInShell: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Training History'), findsNothing);
      expect(find.text('Protocol Library'), findsNothing);
      expect(find.text('Exercise Library'), findsNothing);
      expect(find.text('Coach Studio'), findsNothing);
      expect(find.text('My Athletes'), findsNothing);
      expect(find.text('Internal tools'), findsNothing);
      expect(find.text('Help & feedback'), findsNothing);

      for (final label in _forbiddenProductionLabels) {
        expect(
          find.text(label),
          findsNothing,
          reason: 'Found forbidden label: $label',
        );
      }

      expect(
        find.widgetWithText(TextButton, 'Programme'),
        findsOneWidget,
        reason: 'Home must expose catalogue enrolment entry',
      );
    });

    testWidgets('coach profile still does not put coach tools on athlete Home', (
      tester,
    ) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-1',
          displayName: 'Sam',
          isCoach: true,
          isAthlete: false,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(embeddedInShell: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coach Studio'), findsNothing);
      expect(find.text('My Athletes'), findsNothing);
      expect(find.text('Internal tools'), findsNothing);
    });

    testWidgets('athlete shell exposes four destinations', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsWidgets);
      expect(find.text('Plans'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sessions'), findsNothing);
    });
  });

  group('Founder workspace separation', () {
    testWidgets('founder workspace hosts coach tools', (tester) async {
      FounderAccessPolicy.configure(
        const FounderAccessConfig(developmentOverride: true),
      );
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
}
