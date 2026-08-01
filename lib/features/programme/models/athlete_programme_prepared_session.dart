import '../../plans/models/programmed_session_key.dart';
import '../../session/models/prepared_execution_package.dart';
import 'programme_execution_context.dart';

/// Result of Sprint 1.4B deterministic programme session preparation.
enum AthleteProgrammePrepareStatus {
  prepared,
  restored,
  reconstructed,
  notMaterialised,
  inactive,
  versionMismatch,
  hashMismatch,
  invalidCursor,
  unresolvableSlot,
  failure,
}

class AthleteProgrammePrepareResult {
  const AthleteProgrammePrepareResult({
    required this.status,
    this.package,
    this.executionContext,
    this.programmedSessionKey,
    this.code,
    this.message,
  });

  final AthleteProgrammePrepareStatus status;
  final PreparedExecutionPackage? package;
  final ProgrammeExecutionContext? executionContext;
  final ProgrammedSessionKey? programmedSessionKey;
  final String? code;
  final String? message;

  bool get isReady =>
      package != null &&
      (status == AthleteProgrammePrepareStatus.prepared ||
          status == AthleteProgrammePrepareStatus.restored ||
          status == AthleteProgrammePrepareStatus.reconstructed);

  bool get isRecoverableFailure =>
      status == AthleteProgrammePrepareStatus.failure ||
      status == AthleteProgrammePrepareStatus.versionMismatch ||
      status == AthleteProgrammePrepareStatus.hashMismatch ||
      status == AthleteProgrammePrepareStatus.invalidCursor ||
      status == AthleteProgrammePrepareStatus.unresolvableSlot;
}
