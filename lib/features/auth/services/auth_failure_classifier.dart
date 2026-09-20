import 'dart:io';

import '../models/production_auth_phase.dart';

class AuthFailureClassifier {
  const AuthFailureClassifier();

  AuthIdentityFailure classify(Object error) {
    if (error is SocketException) {
      return AuthIdentityFailure.network;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('clientexception') ||
        text.contains('connection closed') ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return AuthIdentityFailure.network;
    }
    if (text.contains('invalid refresh token') ||
        text.contains('refresh token not found') ||
        text.contains('user not found') ||
        text.contains('user banned') ||
        text.contains('invalid jwt') ||
        text.contains('jwt expired') ||
        text.contains('session not found')) {
      return AuthIdentityFailure.invalid;
    }
    return AuthIdentityFailure.unknown;
  }
}
