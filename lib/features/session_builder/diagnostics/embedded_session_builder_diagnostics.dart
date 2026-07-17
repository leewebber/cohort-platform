import 'package:flutter/foundation.dart';

/// Debug logging for embedded Session Builder navigation (M2).
class EmbeddedSessionBuilderDiagnostics {
  EmbeddedSessionBuilderDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[EmbeddedSessionBuilder] $message');
    }
  }
}
