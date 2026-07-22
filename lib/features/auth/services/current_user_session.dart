import '../../../core/services/user_session_cache.dart';
import '../models/user_profile.dart';

/// Active authenticated session used by athlete and coach workflows.
class CurrentUserSession {
  CurrentUserSession._({
    required this.userId,
    required this.profile,
  });

  static CurrentUserSession? _instance;

  final String userId;
  final UserProfile profile;

  static CurrentUserSession? get maybeInstance => _instance;

  static CurrentUserSession get requireInstance {
    final session = _instance;
    if (session == null) {
      throw StateError('No authenticated user session is active.');
    }
    return session;
  }

  /// Canonical athlete identifier for programme and performance data.
  String get athleteId => userId;

  /// Coach identifier when the user has coach role; null otherwise.
  String? get coachId => profile.isCoach ? userId : null;

  bool get isCoach => profile.isCoach;
  bool get isAthlete => profile.isAthlete;

  static void bind(UserProfile profile) {
    if (_instance?.userId != profile.id) {
      UserSessionCache.clearAll();
    }
    _instance = CurrentUserSession._(
      userId: profile.id,
      profile: profile,
    );
  }

  static void clear() {
    _instance = null;
  }
}
