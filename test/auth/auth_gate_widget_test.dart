import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_profile_repository.dart';
import 'auth_controller_test.dart' show FakeAuthSessionPort;

void main() {
  testWidgets('AuthGate shows login when unauthenticated', (tester) async {
    CurrentUserSession.clear();
    final authService = FakeAuthSessionPort();
    final profileRepository = InMemoryProfileRepository();
    final controller = AuthController(
      authService: authService,
      profileProvisioningService: ProfileProvisioningService(
        profileRepository: profileRepository,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('AuthGate routes to home when authenticated with profile', (tester) async {
    CurrentUserSession.clear();
    final authService = FakeAuthSessionPort();
    authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
    final profileRepository = InMemoryProfileRepository()
      ..profiles['user-123'] = const UserProfile(
        id: 'user-123',
        displayName: 'Lee',
        isCoach: true,
        isAthlete: true,
      );

    final controller = AuthController(
      authService: authService,
      profileProvisioningService: ProfileProvisioningService(
        profileRepository: profileRepository,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Lee'), findsOneWidget);
  });
}
