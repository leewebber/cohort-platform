import 'package:cohort_platform/app/app.dart';
import 'package:cohort_platform/core/services/supabase_service.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_controller_test.dart' show FakeAuthSessionPort;
import '../support/in_memory_profile_repository.dart';

void main() {
  test('invalid Supabase values are rejected before initialization', () {
    final invalid = SupabaseService.validateConfiguration(
      url: 'not-a-url',
      anonKey: 'short',
    );
    final configured = SupabaseService.validateConfiguration(
      url: 'https://project.supabase.co',
      anonKey: 'valid-test-key-with-safe-length',
    );

    expect(invalid.isConfigured, isFalse);
    expect(configured.isConfigured, isTrue);
  });

  testWidgets(
    'missing configuration renders safely without constructing auth dependencies',
    (tester) async {
      await tester.pumpWidget(
        const CohortPlatformApp(
          configurationError: 'Configuration unavailable',
        ),
      );

      expect(find.text('Configuration required'), findsOneWidget);
      expect(find.text('Configuration unavailable'), findsOneWidget);
      expect(find.byType(AuthGate), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('configured app preserves AuthGate startup', (tester) async {
    final controller = AuthController(
      authService: FakeAuthSessionPort(),
      profileProvisioningService: ProfileProvisioningService(
        profileRepository: InMemoryProfileRepository(),
      ),
    );

    await tester.pumpWidget(CohortPlatformApp(authController: controller));
    await tester.pump();

    expect(find.byType(AuthGate), findsOneWidget);
    expect(find.text('Configuration required'), findsNothing);
  });
}
