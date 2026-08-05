import 'journey_d_protocol_publication.dart';
import 'journey_d_rebind_pipeline.dart';
import 'journey_d_session_lineage_rebinder.dart';
import 'journey_d_write_accounting.dart';

/// Exact fixture-collision preflight (marker / identity / lineage).
abstract class JourneyDLivePreflight {
  /// Returns applied when unique and absent; failed/unknown otherwise.
  Future<JourneyDLiveStageOutcome> checkUnique({
    required String marker,
    required String lineageCode,
  });
}

/// Synthetic athlete identity + profile creation (Auth Admin + profiles).
abstract class JourneyDLiveAthleteFactory {
  Future<JourneyDLiveAthleteResult> create({
    required String marker,
    required String email,
    required String displayName,
  });
}

class JourneyDLiveAthleteResult {
  const JourneyDLiveAthleteResult({
    required this.state,
    this.userIdRedacted,
    this.accessTokenPresent = false,
    this.detail = '',
    this.privateUserId,
    this.privatePassword,
    this.privateEmail,
    this.writeAccounting = JourneyDWriteAccounting.none,
  });

  final JourneyDPublicationStageState state;
  final String? userIdRedacted;
  final bool accessTokenPresent;
  final String detail;

  /// In-process handoff only — never serialize to result JSON / evidence.
  final String? privateUserId;
  final String? privatePassword;
  final String? privateEmail;
  final JourneyDWriteAccounting writeAccounting;

  bool get isApplied => state == JourneyDPublicationStageState.applied;
}

/// Import / publish / approve programme package RPCs.
abstract class JourneyDLiveProgrammeLifecycle {
  Future<JourneyDLiveStageOutcome> importValidatedPackage({
    required Map<String, Object?> payload,
    required String importedBy,
  });

  Future<JourneyDLiveStageOutcome> publishAndApprove({
    required String versionId,
    required String actor,
  });
}

/// Catalogue enrolment for the synthetic athlete.
abstract class JourneyDLiveEnrolment {
  Future<JourneyDLiveEnrolResult> enrol({required String programmeVersionId});
}

class JourneyDLiveEnrolResult {
  const JourneyDLiveEnrolResult({
    required this.state,
    this.assignmentId,
    this.assignmentIdRedacted,
    this.detail = '',
  });

  final JourneyDPublicationStageState state;

  /// Opaque assignment id for the next stage (tests may use synthetic values).
  final String? assignmentId;
  final String? assignmentIdRedacted;
  final String detail;

  bool get isApplied => state == JourneyDPublicationStageState.applied;
}

/// Schedule materialisation for the enrolment.
abstract class JourneyDLiveMaterialisation {
  Future<JourneyDLiveStageOutcome> materialise({
    required String programmeAssignmentId,
  });
}

/// Generic stage outcome for non-publication stages.
class JourneyDLiveStageOutcome {
  const JourneyDLiveStageOutcome({
    required this.state,
    this.detail = '',
    this.versionId,
    this.versionIdRedacted,
    this.hostedWrite = false,
  });

  final JourneyDPublicationStageState state;
  final String detail;
  final String? versionId;
  final String? versionIdRedacted;
  final bool hostedWrite;

  bool get isApplied => state == JourneyDPublicationStageState.applied;

  static JourneyDLiveStageOutcome applied({
    String detail = '',
    String? versionId,
    String? versionIdRedacted,
    bool hostedWrite = true,
  }) => JourneyDLiveStageOutcome(
    state: JourneyDPublicationStageState.applied,
    detail: detail,
    versionId: versionId,
    versionIdRedacted: versionIdRedacted,
    hostedWrite: hostedWrite,
  );

  static JourneyDLiveStageOutcome failed(String detail) =>
      JourneyDLiveStageOutcome(
        state: JourneyDPublicationStageState.failed,
        detail: detail,
      );

  static JourneyDLiveStageOutcome timedOut(String detail) =>
      JourneyDLiveStageOutcome(
        state: JourneyDPublicationStageState.timedOut,
        detail: detail,
      );

  static JourneyDLiveStageOutcome unknown(String detail) =>
      JourneyDLiveStageOutcome(
        state: JourneyDPublicationStageState.unknown,
        detail: detail,
      );
}

/// Re-export pipeline types used by the live creator.
typedef JourneyDLiveRebindResult = JourneyDRebindPipelineResult;
typedef JourneyDLiveReboundPackage = JourneyDReboundPackageResult;
