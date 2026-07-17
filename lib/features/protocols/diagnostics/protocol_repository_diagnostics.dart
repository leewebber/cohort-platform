import 'package:flutter/foundation.dart';

/// Debug logging for protocol repository catalogue queries.
class ProtocolRepositoryDiagnostics {
  ProtocolRepositoryDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[ProtocolRepository] $message');
    }
  }
}
