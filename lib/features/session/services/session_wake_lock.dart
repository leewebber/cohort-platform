import 'package:flutter/services.dart';

/// Best-effort screen wake lock for active timers.
///
/// Uses a private platform channel. Unsupported hosts and tests no-op.
class SessionWakeLock {
  const SessionWakeLock._();

  static const _channel = MethodChannel('cohort.session/wake_lock');

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } catch (_) {}
  }
}
