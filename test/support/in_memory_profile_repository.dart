import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/repositories/profile_repository.dart';

class InMemoryProfileRepository implements ProfileRepository {
  final profiles = <String, UserProfile>{};

  @override
  Future<UserProfile?> getProfile(String userId) async {
    return profiles[userId];
  }

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    profiles[profile.id] = profile;
    return profile;
  }
}
