import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_store_exception.dart';
import '../models/programme_builder_operation_result.dart';

/// Debug logging for New Programme creation flows.
///
/// Diagnostics only — does not change business outcomes.
class ProgrammeCreateDiagnostics {
  ProgrammeCreateDiagnostics._();

  static void log(String message) {
    debugPrint('[ProgrammeCreate] $message');
  }

  static void logException(
    Object error, {
    StackTrace? stackTrace,
    String? stage,
  }) {
    if (stage != null) {
      log('exception stage=$stage error=$error');
    } else {
      log('exception=$error');
    }
    if (stackTrace != null) {
      debugPrint('[ProgrammeCreate] stackTrace=$stackTrace');
    }
  }

  static void logOperationResult(ProgrammeBuilderOperationResult result) {
    log('result status=${result.status.name}');
    if (result.warnings.isNotEmpty) {
      log('warnings=${result.warnings.join(' | ')}');
    }
    if (result.validation != null) {
      log(
        'validation blocking=${result.validation!.blockingIssueCount} '
        'warnings=${result.validation!.warningCount}',
      );
    }
  }

  static List<String> warningsFromStoreException(ProgrammeStoreException error) {
    return [
      if (error.operation != null) 'operation=${error.operation}',
      if (error.tableName != null) 'table=${error.tableName}',
      if (error.code != null) 'code=${error.code}',
      'message=${error.message}',
      if (error.details != null) 'details=${error.details}',
      if (error.hint != null) 'hint=${error.hint}',
      if (error.conflictTarget != null) 'onConflict=${error.conflictTarget}',
    ];
  }

  static String debugDetailFromStoreException(ProgrammeStoreException error) {
    return warningsFromStoreException(error).join('\n');
  }

  static String debugDetailFromOperationResult(
    ProgrammeBuilderOperationResult result,
  ) {
    if (result.warnings.isEmpty) {
      return 'status=${result.status.name}';
    }
    return 'status=${result.status.name}\n${result.warnings.join('\n')}';
  }
}
