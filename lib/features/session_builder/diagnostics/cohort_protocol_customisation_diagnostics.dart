import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for Cohort Protocol copy-and-customise (M5).
class CohortProtocolCustomisationDiagnostics {
  CohortProtocolCustomisationDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[CohortProtocolCustomisation] $message');
    }
  }
}
