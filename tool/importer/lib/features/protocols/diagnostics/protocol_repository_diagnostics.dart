import 'package:founder_importer/runtime/debug_flags.dart';
import 'package:founder_importer/runtime/importer_log.dart';
class ProtocolRepositoryDiagnostics {
  ProtocolRepositoryDiagnostics._();

  static void log(String message) {
    if (kDebugMode) {
      importerLog('[ProtocolRepository] $message');
    }
  }
}
