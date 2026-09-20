import '../models/user_profile.dart';

/// Process-local last hosted profile for a persisted Supabase user id.
///
/// Used only when a session exists and profile fetch fails as a network error.
/// Never authorizes a guest and never invents a user id.
class LastVerifiedAuthProfileStore {
  LastVerifiedAuthProfileStore._();

  static UserProfile? _profile;

  static UserProfile? readIfMatches(String userId) {
    final profile = _profile;
    if (profile == null || profile.id != userId) return null;
    return profile;
  }

  static void remember(UserProfile profile) {
    _profile = profile;
  }

  static void forgetIfUser(String? userId) {
    if (userId == null || _profile?.id == userId) {
      _profile = null;
    }
  }

  static void clear() {
    _profile = null;
  }
}
