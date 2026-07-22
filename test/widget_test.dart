import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_session_port.dart';
import 'support/in_memory_profile_repository.dart';

void main() {
  testWidgets('AuthGate shows login when unauthenticated', (tester) async {
    final controller = AuthController(
      authService: FakeAuthSessionPort(),
      profileProvisioningService: ProfileProvisioningService(
        profileRepository: InMemoryProfileRepository(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    controller.dispose();
  });
}
