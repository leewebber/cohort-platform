import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../repositories/profile_repository.dart';
import '../repositories/supabase_profile_repository.dart';

class ProfileProvisioningService {
  ProfileProvisioningService({
    ProfileRepository? profileRepository,
  }) : _profileRepository =
            profileRepository ?? const SupabaseProfileRepository();

  final ProfileRepository _profileRepository;

  Future<UserProfile> provisionProfile({
    required String userId,
    required String displayName,
    required Set<UserRole> roles,
  }) async {
    if (roles.isEmpty) {
      throw ArgumentError('At least one role must be selected.');
    }

    final profile = UserProfile(
      id: userId,
      displayName: displayName.trim(),
      isCoach: roles.contains(UserRole.coach),
      isAthlete: roles.contains(UserRole.athlete),
    );

    return _profileRepository.createProfile(profile);
  }

  Future<UserProfile?> loadProfile(String userId) {
    return _profileRepository.getProfile(userId);
  }
}
