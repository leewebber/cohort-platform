import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> getProfile(String userId);

  Future<UserProfile> createProfile(UserProfile profile);
}
