/// Sprint 1.3 catalogue enrolment result — exact-version programme access.
///
/// Not a payment, purchase, subscription, or individual ownership record.
/// Future commercial entitlement (directional: recurring subscription) may
/// authorise calling enrolment; it does not change which exact version is pinned.
enum AthleteCatalogueEnrolmentStatus {
  enrolled,
  alreadyEnrolled,
  conflict,
  authorizationFailure,
  validationFailure,
  failed,
}

/// How enrolment was authorised (non-commercial test path for Sprint 1.3).
enum EnrolmentSource {
  nonCommercialTest,
  coachAssigned,
  dualRoleSelf,
  unspecified,
}

extension EnrolmentSourceDb on EnrolmentSource {
  String? get dbValue {
    switch (this) {
      case EnrolmentSource.nonCommercialTest:
        return 'non_commercial_test';
      case EnrolmentSource.coachAssigned:
        return 'coach_assigned';
      case EnrolmentSource.dualRoleSelf:
        return 'dual_role_self';
      case EnrolmentSource.unspecified:
        return null;
    }
  }

  static EnrolmentSource fromDb(String? raw) {
    switch (raw?.trim()) {
      case 'non_commercial_test':
        return EnrolmentSource.nonCommercialTest;
      case 'coach_assigned':
        return EnrolmentSource.coachAssigned;
      case 'dual_role_self':
        return EnrolmentSource.dualRoleSelf;
      default:
        return EnrolmentSource.unspecified;
    }
  }
}

class AthleteCatalogueEnrolmentResult {
  const AthleteCatalogueEnrolmentResult({
    required this.status,
    this.enrolmentId,
    this.programmeVersionId,
    this.lineageCode,
    this.enrolmentSource = EnrolmentSource.unspecified,
    this.athleteId,
    this.replacedEnrolmentId,
    this.code,
    this.message,
  });

  final AthleteCatalogueEnrolmentStatus status;
  final String? enrolmentId;

  /// Exact immutable `programme_versions.id` — never "latest".
  final String? programmeVersionId;
  final String? lineageCode;
  final EnrolmentSource enrolmentSource;
  final String? athleteId;
  final String? replacedEnrolmentId;
  final String? code;
  final String? message;

  bool get isSuccess =>
      status == AthleteCatalogueEnrolmentStatus.enrolled ||
      status == AthleteCatalogueEnrolmentStatus.alreadyEnrolled;

  bool get isIdempotentAlreadyEnrolled =>
      status == AthleteCatalogueEnrolmentStatus.alreadyEnrolled;

  factory AthleteCatalogueEnrolmentResult.fromRpcMap(Map<String, dynamic> map) {
    final statusRaw = map['status']?.toString().trim() ?? '';
    final code = map['code']?.toString().trim();
    switch (statusRaw) {
      case 'enrolled':
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.enrolled,
          enrolmentId: _trim(map['enrolment_id']),
          programmeVersionId: _trim(map['programme_version_id']),
          lineageCode: _trim(map['lineage_code']),
          enrolmentSource: EnrolmentSourceDb.fromDb(
            map['enrolment_source']?.toString(),
          ),
          athleteId: _trim(map['athlete_id']),
          replacedEnrolmentId: _trim(map['replaced_enrolment_id']),
        );
      case 'already_enrolled':
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.alreadyEnrolled,
          enrolmentId: _trim(map['enrolment_id']),
          programmeVersionId: _trim(map['programme_version_id']),
          lineageCode: _trim(map['lineage_code']),
          enrolmentSource: EnrolmentSourceDb.fromDb(
            map['enrolment_source']?.toString(),
          ),
          athleteId: _trim(map['athlete_id']),
          message: 'You are already enrolled in this programme.',
        );
      case 'conflict':
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.conflict,
          enrolmentId: _trim(map['enrolment_id']),
          programmeVersionId: _trim(map['programme_version_id']),
          code: code,
          message:
              'You already have an active programme. Confirm to switch, or keep your current enrolment.',
        );
      case 'authorization_failure':
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.authorizationFailure,
          code: code,
          message: _authorizationMessage(code),
        );
      case 'validation_failure':
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.validationFailure,
          code: code,
          message: _validationMessage(code),
        );
      default:
        return AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.failed,
          code: code ?? statusRaw,
          message: 'Enrolment could not be completed. Please try again.',
        );
    }
  }

  static String? _trim(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _authorizationMessage(String? code) {
    switch (code) {
      case 'not_authenticated':
        return 'Sign in to enrol in a programme.';
      case 'athlete_role_required':
        return 'An athlete account is required to enrol.';
      case 'version_not_catalogue_eligible':
        return 'That programme is not available in the catalogue.';
      case 'catalogue_enrolment_not_authorised':
        return 'Programme enrolment is not available for this account.';
      default:
        return 'You do not have access to enrol in that programme.';
    }
  }

  static String _validationMessage(String? code) {
    switch (code) {
      case 'version_not_found':
        return 'That programme could not be found.';
      case 'empty_programme_structure':
        return 'That programme is not ready to start yet.';
      case 'invalid_args':
        return 'Choose a programme to enrol.';
      default:
        return 'Enrolment could not be validated. Please try again.';
    }
  }
}

/// Stable handoff payload for a later athlete-plan materialisation sprint.
///
/// Enrolment pins [programmeVersionId] exactly. Materialisation must not
/// resolve "latest" lineage version. Commercial entitlement is out of band.
class AthletePlanMaterialisationHandoff {
  const AthletePlanMaterialisationHandoff({
    required this.athleteId,
    required this.programmeVersionId,
    required this.enrolmentId,
    this.lineageCode,
    this.enrolmentSource = EnrolmentSource.unspecified,
  });

  final String athleteId;
  final String programmeVersionId;
  final String enrolmentId;
  final String? lineageCode;
  final EnrolmentSource enrolmentSource;

  Map<String, Object?> toMap() => {
    'athlete_id': athleteId,
    'programme_version_id': programmeVersionId,
    'enrolment_id': enrolmentId,
    if (lineageCode != null) 'lineage_code': lineageCode,
    'enrolment_source': enrolmentSource.dbValue,
    'binds_exact_version': true,
    'commercial_entitlement': null,
  };

  factory AthletePlanMaterialisationHandoff.fromEnrolmentResult(
    AthleteCatalogueEnrolmentResult result,
  ) {
    final athleteId = result.athleteId?.trim() ?? '';
    final versionId = result.programmeVersionId?.trim() ?? '';
    final enrolmentId = result.enrolmentId?.trim() ?? '';
    if (athleteId.isEmpty || versionId.isEmpty || enrolmentId.isEmpty) {
      throw ArgumentError(
        'Enrolment result missing athlete, version, or enrolment id for handoff',
      );
    }
    return AthletePlanMaterialisationHandoff(
      athleteId: athleteId,
      programmeVersionId: versionId,
      enrolmentId: enrolmentId,
      lineageCode: result.lineageCode,
      enrolmentSource: result.enrolmentSource,
    );
  }
}
