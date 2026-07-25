import 'package:flutter/foundation.dart';

import '../errors/user_facing_error_messages.dart';

/// Athlete-facing error copy with full technical logging in debug builds.
class AthleteSafeErrorPresenter {
  AthleteSafeErrorPresenter._();

  static String message(
    Object error, {
    String? fallback,
    String? logTag,
  }) {
    _logTechnical(error, logTag: logTag);
    return UserFacingErrorMessages.from(error, fallback: fallback);
  }

  static void _logTechnical(Object error, {String? logTag}) {
    final prefix = logTag == null ? '[AthleteSafeError]' : '[AthleteSafeError $logTag]';
    debugPrint('$prefix $error');
    if (error is Error) {
      debugPrint('$prefix stack=${error.stackTrace}');
    }
  }
}
