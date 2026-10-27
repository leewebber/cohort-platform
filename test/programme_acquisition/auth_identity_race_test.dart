import 'dart:async';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_controller_test.dart' show FakeAuthSessionPort;
import '../support/in_memory_profile_repository.dart';

class DelayedProfileRepository extends InMemoryProfileRepository {
  final pending = Completer<UserProfile?>();
  @override
  Future<UserProfile?> getProfile(String userId) =>
      userId == 'athlete-a' ? pending.future : super.getProfile(userId);
}

void main() {
  tearDown(CurrentUserSession.clear);
  test(
    'delayed account bootstrap cannot restore signed-out identity',
    () async {
      final port = FakeAuthSessionPort()
        ..setAuthenticated(userId: 'athlete-a', email: 'a@example.com');
      final profiles = DelayedProfileRepository();
      final c = AuthController(
        authService: port,
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: profiles,
        ),
      );
      addTearDown(c.dispose);
      final initializing = c.initialize();
      await c.signOut();
      profiles.pending.complete(
        const UserProfile(
          id: 'athlete-a',
          displayName: 'Old',
          isCoach: false,
          isAthlete: true,
        ),
      );
      await initializing;
      expect(CurrentUserSession.maybeInstance, isNull);
    },
  );
}
