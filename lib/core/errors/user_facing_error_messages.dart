import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/authenticated_identity.dart';

/// Maps technical failures to concise user-facing copy.
class UserFacingErrorMessages {
  const UserFacingErrorMessages._();

  static const String timeout =
      'This is taking longer than expected. Please try again.';
  static const String offline =
      'You appear to be offline. Please check your connection.';
  static const String saveFailure =
      'We couldn\'t save that yet. Please try again.';
  static const String genericFailure =
      'Something went wrong. Please try again.';

  static String from(Object error, {String? fallback}) {
    if (error is AuthenticatedIdentityException) {
      return error.userMessage;
    }

    if (error is AuthException) {
      return _authMessage(error.message);
    }

    if (error is PostgrestException) {
      return _postgrestMessage(error);
    }

    final message = error.toString();

    if (_looksLikeStatementTimeout(message, code: _extractCode(message))) {
      return timeout;
    }

    if (_looksLikeCoachStudioAccess(message)) {
      return coachAccessRequired();
    }

    if (_looksLikeAthleteAccess(message)) {
      return athleteAccessRequired();
    }

    if (_looksLikeProgrammeAccess(message)) {
      return programmeAccessDenied();
    }

    if (_looksLikeProgrammeEdit(message)) {
      return programmeEditDenied();
    }

    if (_looksLikeProgrammeAssign(message)) {
      return programmeAssignDenied();
    }

    if (_looksLikePermissionDenied(message)) {
      return 'You do not have permission to perform this action.';
    }

    if (_looksLikeNetwork(message)) {
      return offline;
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
      return saveFailure;
    }

    if (_looksLikeRawBackendException(message)) {
      return fallback ?? genericFailure;
    }

    return fallback ?? genericFailure;
  }

  static String _postgrestMessage(PostgrestException error) {
    debugPrint(
      '[UserFacingErrorMessages] PostgrestException '
      'code=${error.code} message=${error.message} details=${error.details}',
    );

    final code = error.code?.trim();
    if (code == '57014' ||
        _looksLikeStatementTimeout(error.message, code: code)) {
      return timeout;
    }

    if (_looksLikePermissionDenied(error.message)) {
      return 'You do not have permission to perform this action.';
    }

    if (_looksLikeNetwork(error.message)) {
      return offline;
    }

    return genericFailure;
  }

  static String? _extractCode(String message) {
    final match = RegExp(
      r'code:\s*(\w+)',
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1);
  }

  static bool _looksLikeStatementTimeout(String message, {String? code}) {
    if (code == '57014') return true;
    final lower = message.toLowerCase();
    return lower.contains('57014') ||
        lower.contains('statement timeout') ||
        lower.contains('canceling statement due to statement timeout');
  }

  static bool _looksLikeRawBackendException(String message) {
    final lower = message.toLowerCase();
    return lower.contains('postgrestexception') ||
        lower.contains('programmestoreexception') ||
        lower.contains('clientexception') ||
        lower.contains('authretryablefetchexception');
  }

  static String sessionSaveFailure(Object error) {
    return from(error, fallback: saveFailure);
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

  static String missingRoles() {
    return 'Your account roles could not be loaded. Please sign in again.';
  }

  static String coachAccessRequired() {
    return 'Coach access is required to open Coach Studio.';
  }

  static String athleteAccessRequired() {
    return 'Athlete access is required to start training.';
  }

  static String programmeAccessDenied() {
    return 'You do not have access to this programme.';
  }

  static String programmeEditDenied() {
    return 'You do not have permission to edit this programme.';
  }

  static String programmeAssignDenied() {
    return 'This programme can no longer be assigned.';
  }

  static bool _looksLikeCoachStudioAccess(String message) {
    final lower = message.toLowerCase();
    return lower.contains('coach access is required');
  }

  static bool _looksLikeAthleteAccess(String message) {
    final lower = message.toLowerCase();
    return lower.contains('athlete access is required');
  }

  static bool _looksLikeProgrammeAccess(String message) {
    final lower = message.toLowerCase();
    return lower.contains('programme access') ||
        lower.contains('not have access to this programme');
  }

  static bool _looksLikeProgrammeEdit(String message) {
    final lower = message.toLowerCase();
    return lower.contains('edit this programme') ||
        lower.contains('owner_id mismatch');
  }

  static bool _looksLikeProgrammeAssign(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no longer be assigned') ||
        lower.contains('cannot assign');
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
