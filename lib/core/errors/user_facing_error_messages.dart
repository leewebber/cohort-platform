import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps technical failures to concise user-facing copy.
class UserFacingErrorMessages {
  const UserFacingErrorMessages._();

  static String from(Object error, {String? fallback}) {
    if (error is AuthException) {
      return _authMessage(error.message);
    }

    final message = error.toString();

    if (_looksLikePermissionDenied(message)) {
      return 'You do not have permission to perform this action.';
    }

    if (_looksLikeNetwork(message)) {
      return 'Could not reach Cohort. Check your connection and try again.';
    }

    if (_looksLikeInvite(message)) {
      return 'This invitation is invalid or has expired.';
    }

    if (_looksLikeAssignment(message)) {
      return 'This programme could not be assigned.';
    }

    if (_looksLikeTodaySession(message)) {
      return 'Could not load today\'s training.';
    }

    if (_looksLikeSessionSave(message)) {
      return 'Your session could not be saved. Your progress has not been advanced.';
    }

    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String sessionSaveFailure(Object error) {
    return from(
      error,
      fallback:
          'Your session could not be saved. Your progress has not been advanced.',
    );
  }

  static String sessionProgressionWarning() {
    return 'Session saved, but programme progress could not be updated. '
        'Try refreshing Home.';
  }

  static String missingSupabaseConfiguration() {
    return 'Supabase is not configured. Copy .env.example to .env and add '
        'your project URL and anon key, then restart the app.';
  }

  static String _authMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirm your email before signing in.';
    }
    return message;
  }

  static bool _looksLikePermissionDenied(String message) {
    return message.contains('42501') ||
        message.toLowerCase().contains('permission denied') ||
        message.toLowerCase().contains('row-level security');
  }

  static bool _looksLikeNetwork(String message) {
    final lower = message.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection refused') ||
        lower.contains('timed out');
  }

  static bool _looksLikeInvite(String message) {
    final lower = message.toLowerCase();
    return lower.contains('invite') ||
        lower.contains('invitation') ||
        lower.contains('expired') ||
        lower.contains('invalid invite');
  }

  static bool _looksLikeAssignment(String message) {
    final lower = message.toLowerCase();
    return lower.contains('assignprogramme') ||
        lower.contains('programme assignment') ||
        lower.contains('alreadyactiveconflict');
  }

  static bool _looksLikeTodaySession(String message) {
    final lower = message.toLowerCase();
    return lower.contains('programmescheduleexception') ||
        lower.contains('today session') ||
        lower.contains('could not load today');
  }

  static bool _looksLikeSessionSave(String message) {
    final lower = message.toLowerCase();
    return lower.contains('performancerecordstoreexception') ||
        lower.contains('complete record') ||
        lower.contains('performance record');
  }
}
