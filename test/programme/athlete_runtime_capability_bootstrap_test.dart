import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/screens/login_screen.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_runtime_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller_test.dart' show FakeAuthSessionPort;
import '../support/in_memory_profile_repository.dart';

void main() {
  tearDown(() {
    CurrentUserSession.clear();
    AthleteProfileSession.clear();
  });

  group('capability RPC fail-closed', () {
    test('permission-denied returns unavailable', () async {
      final loaded = await SupabaseAthleteRuntimeCapabilityStore(
        rpc: () async => throw PostgrestException(
          message: 'permission denied for function',
          code: '42501',
        ),
      ).load();
      expect(loaded.backfillResults, isFalse);
      expect(loaded.publisherAthleteMembershipRead, isFalse);
      expect(loaded.schemaVersion, 0);
    });

    test('missing function returns unavailable', () async {
      final loaded = await SupabaseAthleteRuntimeCapabilityStore(
        rpc: () async => throw PostgrestException(
          message: 'Could not find the function',
          code: 'PGRST202',
        ),
      ).load();
      expect(loaded.backfillResults, isFalse);
      expect(loaded.schemaVersion, 0);
    });

    test('expired session returns unavailable', () async {
      final loaded = await SupabaseAthleteRuntimeCapabilityStore(
        rpc: () async => throw PostgrestException(
          message: 'JWT expired',
          code: 'PGRST301',
        ),
      ).load();
      expect(loaded.overdueRecovery, isFalse);
      expect(loaded.schemaVersion, 0);
    });

    test('authentication_required payload returns unavailable', () async {
      final loaded = await const SupabaseAthleteRuntimeCapabilityStore(
        rpc: _authRequired,
      ).load();
      expect(loaded.backfillResults, isFalse);
      expect(loaded.schemaVersion, 0);
    });

    test('authenticated ok payload loads flags', () async {
      final loaded = await const SupabaseAthleteRuntimeCapabilityStore(
        rpc: _authenticatedOk,
      ).load();
      expect(loaded.backfillResults, isTrue);
      expect(loaded.publisherAthleteMembershipRead, isTrue);
      expect(loaded.schemaVersion, 3);
    });

    test('network failure returns unavailable', () async {
      final loaded = await SupabaseAthleteRuntimeCapabilityStore(
        rpc: () async => throw Exception('SocketException: Failed host lookup'),
      ).load();
      expect(loaded.schemaVersion, 0);
    });
  });

  group('AuthGate bootstrap does not wait on capabilities', () {
    testWidgets('cold start with no session shows sign-in', (tester) async {
      final controller = AuthController(
        authService: FakeAuthSessionPort(),
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: InMemoryProfileRepository(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Preparing…'), findsNothing);
      controller.dispose();
    });

    testWidgets('authenticated athlete reaches Home without waiting on RPC', (
      tester,
    ) async {
      final authService = FakeAuthSessionPort();
      authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
      final controller = AuthController(
        authService: authService,
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: InMemoryProfileRepository()
            ..profiles['user-123'] = const UserProfile(
              id: 'user-123',
              displayName: 'Lee',
              isCoach: false,
              isAthlete: true,
            ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AthleteAppShell), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Preparing…'), findsNothing);
      controller.dispose();
    });

    testWidgets('sign-out with no local onboarding returns to login', (
      tester,
    ) async {
      final authService = FakeAuthSessionPort();
      authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
      final controller = AuthController(
        authService: authService,
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: InMemoryProfileRepository()
            ..profiles['user-123'] = const UserProfile(
              id: 'user-123',
              displayName: 'Lee',
              isCoach: false,
              isAthlete: true,
            ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await controller.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Preparing…'), findsNothing);
      controller.dispose();
    });

    testWidgets(
      'production AthleteAppShell survives missing capability RPC',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: AthleteAppShell()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(AthleteAppShell), findsOneWidget);
        expect(find.text('Home'), findsWidgets);
        expect(find.text('Preparing…'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<dynamic> _authRequired() async {
  return {
    'status': 'authorization_failure',
    'code': 'authentication_required',
    'schema_version': 3,
    'overdue_recovery': false,
    'backfill_results': false,
  };
}

Future<dynamic> _authenticatedOk() async {
  return {
    'status': 'ok',
    'schema_version': 3,
    'overdue_recovery': true,
    'backfill_results': true,
    'content_graph_read': true,
    'publisher_athlete_membership_read': true,
    'publisher_athlete_membership_invite': false,
    'publisher_athlete_membership_manage': false,
  };
}
