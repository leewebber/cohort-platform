import 'package:flutter/foundation.dart';

/// Debug-only diagnostics for Training Library flows.
class TrainingLibraryDiagnostics {
  TrainingLibraryDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[TrainingLibrary] $message');
    }
  }
}

class SessionLibraryDiagnostics {
  SessionLibraryDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[SessionLibrary] $message');
    }
  }
}
