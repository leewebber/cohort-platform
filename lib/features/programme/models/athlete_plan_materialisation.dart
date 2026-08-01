import '../../../models/programme_assignment.dart';
import 'athlete_catalogue_enrolment.dart';

/// Result of Sprint 1.4A Start Programme materialisation.
enum AthletePlanMaterialisationStatus {
  materialised,
  alreadyMaterialised,
  authorizationFailure,
  validationFailure,
  conflict,
  legacyPlanConflict,
  failed,
}

/// Authoritative materialisation RPC / client result.
class AthletePlanMaterialisationResult {
  const AthletePlanMaterialisationResult({
    required this.status,
    this.enrolmentId,
    this.programmeVersionId,
    this.lineageCode,
    this.materialisedAt,
    this.materialisationSource,
    this.materialisedPackageContentHash,
    this.materialisedPackageSchemaVersion,
    this.startedAt,
    this.timezone,
    this.currentWeek,
    this.currentDayKey,
    this.currentSlotOrder,
    this.athleteId,
    this.code,
    this.message,
  });

  final AthletePlanMaterialisationStatus status;
  final String? enrolmentId;
  final String? programmeVersionId;
  final String? lineageCode;
  final DateTime? materialisedAt;
  final String? materialisationSource;
  final String? materialisedPackageContentHash;
  final String? materialisedPackageSchemaVersion;
  final DateTime? startedAt;
  final String? timezone;
  final int? currentWeek;
  final String? currentDayKey;
  final int? currentSlotOrder;
  final String? athleteId;
  final String? code;
  final String? message;

  bool get isSuccess =>
      status == AthletePlanMaterialisationStatus.materialised ||
      status == AthletePlanMaterialisationStatus.alreadyMaterialised;

  bool get isIdempotentAlreadyMaterialised =>
      status == AthletePlanMaterialisationStatus.alreadyMaterialised;

  factory AthletePlanMaterialisationResult.fromRpcMap(
    Map<String, dynamic> map,
  ) {
    final statusRaw = map['status']?.toString() ?? 'failed';
    final code = map['code']?.toString();
    final status = _statusFromRpc(statusRaw, code);
    return AthletePlanMaterialisationResult(
      status: status,
      enrolmentId: _trim(map['enrolment_id']),
      programmeVersionId: _trim(map['programme_version_id']),
      lineageCode: _trim(map['lineage_code']),
      materialisedAt: _parseDateTime(map['materialised_at']),
      materialisationSource: _trim(map['materialisation_source']),
      materialisedPackageContentHash: _trim(
        map['materialised_package_content_hash'],
      ),
      materialisedPackageSchemaVersion: _trim(
        map['materialised_package_schema_version'],
      ),
      startedAt: _parseDateTime(map['started_at']),
      timezone: _trim(map['timezone']),
      currentWeek: _nullableInt(map['current_week_number']),
      currentDayKey: _trim(map['current_day_key']),
      currentSlotOrder: _nullableInt(map['current_slot_order']),
      athleteId: _trim(map['athlete_id']),
      code: code,
      message: map['message']?.toString() ?? _defaultMessage(status, code),
    );
  }

  /// Builds a typed handoff from a successful materialisation (exact version).
  AthletePlanMaterialisationHandoff? toHandoff() {
    final athlete = athleteId?.trim() ?? '';
    final version = programmeVersionId?.trim() ?? '';
    final enrolment = enrolmentId?.trim() ?? '';
    if (athlete.isEmpty || version.isEmpty || enrolment.isEmpty) return null;
    return AthletePlanMaterialisationHandoff(
      athleteId: athlete,
      programmeVersionId: version,
      enrolmentId: enrolment,
      lineageCode: lineageCode,
      enrolmentSource: EnrolmentSource.unspecified,
    );
  }

  static AthletePlanMaterialisationStatus _statusFromRpc(
    String status,
    String? code,
  ) {
    switch (status) {
      case 'materialised':
        return AthletePlanMaterialisationStatus.materialised;
      case 'already_materialised':
        return AthletePlanMaterialisationStatus.alreadyMaterialised;
      case 'authorization_failure':
        return AthletePlanMaterialisationStatus.authorizationFailure;
      case 'validation_failure':
        return AthletePlanMaterialisationStatus.validationFailure;
      case 'conflict':
        return AthletePlanMaterialisationStatus.conflict;
      default:
        return AthletePlanMaterialisationStatus.failed;
    }
  }

  static String? _defaultMessage(
    AthletePlanMaterialisationStatus status,
    String? code,
  ) {
    if (status == AthletePlanMaterialisationStatus.materialised) return null;
    if (status == AthletePlanMaterialisationStatus.alreadyMaterialised) {
      return 'This programme is already started.';
    }
    switch (code) {
      case 'not_authenticated':
        return 'Sign in to start your programme.';
      case 'assignment_not_found':
        return 'That programme enrolment could not be found.';
      case 'inactive_enrolment':
        return 'This programme enrolment is no longer active.';
      case 'active_materialised_programme_exists':
        return 'You already have an active started programme.';
      case 'version_not_found':
      case 'version_not_immutable':
      case 'version_not_catalogue_eligible':
        return 'This programme is not available to start.';
      case 'invalid_package_integrity':
        return 'This programme package could not be verified.';
      case 'empty_programme_structure':
      case 'unresolvable_first_slot':
        return 'This programme is not ready to start yet.';
      case 'timezone_unavailable':
        return 'A valid timezone is required to start today.';
      default:
        return 'The programme could not be started. Please try again.';
    }
  }

  static String? _trim(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

/// Client-side legacy Plan Library conflict (not database-enforced).
class LegacyActivePlanConflictException implements Exception {
  const LegacyActivePlanConflictException();

  @override
  String toString() =>
      'An existing Plan Library plan is active on this device. '
      'Switching programmes is not available yet.';
}

/// Maps an assignment into materialisation view-state helpers.
extension ProgrammeAssignmentMaterialisationX on ProgrammeAssignment {
  bool get canStartProgramme => isEnrolledOnly;
}
