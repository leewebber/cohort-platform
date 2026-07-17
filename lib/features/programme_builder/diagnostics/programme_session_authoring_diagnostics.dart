import 'package:flutter/foundation.dart';

/// Debug logging for programme Session Save & Attach (M3).
class ProgrammeSessionAuthoringDiagnostics {
  ProgrammeSessionAuthoringDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[ProgrammeSessionAuthoring] $message');
    }
  }
}
