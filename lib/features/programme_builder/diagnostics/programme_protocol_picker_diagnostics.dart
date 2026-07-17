import 'package:flutter/foundation.dart';

/// Debug logging for Programme Editor protocol picker loads.
class ProgrammeProtocolPickerDiagnostics {
  ProgrammeProtocolPickerDiagnostics._();

  static void log(String message) {
    debugPrint('[ProgrammeProtocolPicker] $message');
  }

  static void logSkippedRow({
    required String protocolId,
    required String reason,
  }) {
    log('skipped row protocolId=$protocolId reason=$reason');
  }
}
