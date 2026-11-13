import 'dart:async';

import 'package:cohort_platform/core/widgets/cohort_athlete_bottom_nav_bar.dart';
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/models/auth_view_state.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/screens/login_screen.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_runtime_capabilities.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:cohort_platform/features/programme_acquisition/training_setup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller_test.dart' show FakeAuthSessionPort;
import '../programme_acquisition/acquisition_test_support.dart';
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
        rpc: () async =>
            throw PostgrestException(message: 'JWT expired', code: 'PGRST301'),
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
      authService.setAuthenticated(
        userId: 'user-123',
        email: 'lee@example.com',
      );
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
        MaterialApp(
          home: AuthGate(
            controller: controller,
            // M1.2 requires confirmed setup before the shell. Capability
            // discovery remains unconfigured and must not block entry.
            acquisitionStore: FakeAcquisitionStore()..setup = _completedSetup,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AthleteAppShell), findsOneWidget);
      final navigation = find.byType(CohortAthleteBottomNavBar);
      String selectedDestination() {
        final bar = tester.widget<CohortAthleteBottomNavBar>(navigation);
        return bar.destinations![bar.selectedIndex].label;
      }

      expect(selectedDestination(), 'Home');
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Preparing…'), findsNothing);

      await tester.tap(
        find.descendant(of: navigation, matching: find.text('Programmes')),
      );
      await tester.pumpAndSettle();
      expect(selectedDestination(), 'Programmes');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(selectedDestination(), 'Programmes');
      controller.dispose();
    });

    testWidgets('sign-out with no local onboarding returns to login', (
      tester,
    ) async {
      final authService = FakeAuthSessionPort();
      authService.setAuthenticated(
        userId: 'user-123',
        email: 'lee@example.com',
      );
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
        MaterialApp(
          home: AuthGate(
            controller: controller,
            acquisitionStore: FakeAcquisitionStore()..setup = _completedSetup,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(AthleteAppShell), findsOneWidget);
      await controller.signOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Preparing…'), findsNothing);
      controller.dispose();
    });

    testWidgets('unconfigured setup backend holds authenticated entry closed', (
      tester,
    ) async {
      final controller = _authenticatedController(FakeAuthSessionPort());
      addTearDown(controller.dispose);
      // Reproduce the original fixture's missing Supabase initialization.
      expect(() => Supabase.instance, throwsAssertionError);
      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(controller.state.status, AuthStatus.authenticated);
      expect(CurrentUserSession.maybeInstance?.athleteId, 'user-123');
      expect(find.byType(TrainingSetupGate), findsOneWidget);
      expect(find.byKey(const Key('setup-error')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(AthleteAppShell), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'saved setup draft gates entry until confirmation and reopens',
      (tester) async {
        final controller = _authenticatedController(FakeAuthSessionPort());
        addTearDown(controller.dispose);
        final store = FakeAcquisitionStore()
          ..setup = const TrainingSetup(timezone: 'Europe/London');
        Future<void> open() async {
          await tester.pumpWidget(
            MaterialApp(
              home: AuthGate(controller: controller, acquisitionStore: store),
            ),
          );
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text('Finish setup'), findsOneWidget);
        expect(find.byType(AthleteAppShell), findsNothing);
        expect(store.saves, 0);
        await tester.tap(find.text('Finish setup'));
        await tester.pumpAndSettle();
        expect(find.byType(AthleteAppShell), findsOneWidget);
        expect(store.setup.complete, isTrue);
        expect(store.setup.timezone, 'Europe/London');
        expect(store.saves, 1);
        expect(store.acquisitions, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        await open();
        expect(find.byType(AthleteAppShell), findsOneWidget);
        expect(find.text('Finish setup'), findsNothing);
        expect(store.saves, 1);
        expect(store.acquisitions, 0);
      },
    );

    testWidgets(
      'setup failure retries without bypass or automatic acquisition',
      (tester) async {
        final controller = _authenticatedController(FakeAuthSessionPort());
        addTearDown(controller.dispose);
        final store = FakeAcquisitionStore()..failure = 'unavailable';
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(controller: controller, acquisitionStore: store),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('setup-error')), findsOneWidget);
        expect(find.byType(AthleteAppShell), findsNothing);
        store.failure = null;
        store.setup = _completedSetup;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.byType(AthleteAppShell), findsOneWidget);
        expect(store.saves, 0);
        expect(store.acquisitions, 0);
      },
    );

    testWidgets(
      'late completed setup cannot admit a different signed-in account',
      (tester) async {
        final port = FakeAuthSessionPort();
        final controller = _authenticatedController(port);
        addTearDown(controller.dispose);
        final store = _DelayedInitialSetupStore();
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(controller: controller, acquisitionStore: store),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(store.loads, 1);
        expect(find.byType(AthleteAppShell), findsNothing);

        await controller.signOut();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        port.setAuthenticated(userId: 'user-456', email: 'other@example.com');
        await tester.pumpAndSettle();
        expect(CurrentUserSession.maybeInstance?.athleteId, 'user-456');
        expect(store.loads, 2);
        expect(find.text('Set your training timezone'), findsOneWidget);
        store.firstLoad.complete(_completedSetup);
        await tester.pumpAndSettle();
        expect(find.byType(AthleteAppShell), findsNothing);
        expect(find.text('Set your training timezone'), findsOneWidget);
        expect(find.text('Finish setup'), findsNothing);
        expect(store.saves, 0);
        expect(store.acquisitions, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('production AthleteAppShell survives missing capability RPC', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AthleteAppShell(athleteIdOverride: 'athlete.local'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AthleteAppShell), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Preparing…'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

const _completedSetup = TrainingSetup(
  timezone: 'Europe/London',
  complete: true,
);

AuthController _authenticatedController(FakeAuthSessionPort port) {
  port.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
  return AuthController(
    authService: port,
    profileProvisioningService: ProfileProvisioningService(
      profileRepository: InMemoryProfileRepository()
        ..profiles.addEntries([
          for (final id in ['user-123', 'user-456'])
            MapEntry(
              id,
              UserProfile(
                id: id,
                displayName: 'Test athlete',
                isCoach: false,
                isAthlete: true,
              ),
            ),
        ]),
    ),
  );
}

class _DelayedInitialSetupStore extends FakeAcquisitionStore {
  final firstLoad = Completer<TrainingSetup>();
  int loads = 0;

  @override
  Future<TrainingSetup> loadSetup() {
    loads++;
    return loads == 1 ? firstLoad.future : super.loadSetup();
  }
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
