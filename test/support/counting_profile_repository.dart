import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/repositories/profile_repository.dart';

class CountingProfileRepository implements ProfileRepository {
  CountingProfileRepository({Map<String, UserProfile>? seed})
      : profiles = seed ?? {};

  final Map<String, UserProfile> profiles;
  int getProfileCallCount = 0;
  int createProfileCallCount = 0;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    getProfileCallCount++;
    return profiles[userId];
  }

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    createProfileCallCount++;
    profiles[profile.id] = profile;
    return profile;
  }
}
