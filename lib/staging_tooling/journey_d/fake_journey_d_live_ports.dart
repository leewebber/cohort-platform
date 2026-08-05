import 'journey_d_live_ports.dart';
import 'journey_d_protocol_publication.dart';
import 'journey_d_write_accounting.dart';

/// Synthetic test doubles for [JourneyDLiveFixtureCreator]. Never hosted.
class FakeJourneyDLivePreflight implements JourneyDLivePreflight {
  FakeJourneyDLivePreflight({JourneyDLiveStageOutcome? outcome})
    : outcome =
          outcome ??
          JourneyDLiveStageOutcome.applied(
            detail: 'UNIQUE_synthetic',
            hostedWrite: false,
          );

  JourneyDLiveStageOutcome outcome;
  int calls = 0;

  @override
  Future<JourneyDLiveStageOutcome> checkUnique({
    required String marker,
    required String lineageCode,
  }) async {
    calls += 1;
    return outcome;
  }
}

class FakeJourneyDLiveAthleteFactory implements JourneyDLiveAthleteFactory {
  FakeJourneyDLiveAthleteFactory({JourneyDLiveAthleteResult? result})
    : result = result;

  JourneyDLiveAthleteResult? result;
  int calls = 0;

  @override
  Future<JourneyDLiveAthleteResult> create({
    required String marker,
    required String email,
    required String displayName,
  }) async {
    calls += 1;
    return result ??
        JourneyDLiveAthleteResult(
          state: JourneyDPublicationStageState.applied,
          userIdRedacted: 'a1111111…',
          accessTokenPresent: true,
          detail: 'synthetic_athlete',
          privateUserId: 'a1111111-1111-4111-8111-111111111111',
          privatePassword: 'FakeJdCredential!aA1-$marker',
          privateEmail: email,
          writeAccounting: const JourneyDWriteAccounting(
            invocationAttempted: true,
            requestDispatched: true,
            responseReceived: true,
            mutationConfirmed: true,
            objectObservedPostAttempt: false,
          ),
        );
  }
}

class FakeJourneyDLiveProgrammeLifecycle
    implements JourneyDLiveProgrammeLifecycle {
  FakeJourneyDLiveProgrammeLifecycle({
    JourneyDLiveStageOutcome? importOutcome,
    JourneyDLiveStageOutcome? publishApproveOutcome,
  }) : importOutcome =
           importOutcome ??
           JourneyDLiveStageOutcome.applied(
             detail: 'synthetic_import',
             versionId: 'c3333333-3333-4333-8333-333333333333',
             versionIdRedacted: 'c3333333…',
           ),
       publishApproveOutcome =
           publishApproveOutcome ??
           JourneyDLiveStageOutcome.applied(
             detail: 'synthetic_publish_approve',
           );

  JourneyDLiveStageOutcome importOutcome;
  JourneyDLiveStageOutcome publishApproveOutcome;
  int importCalls = 0;
  int publishApproveCalls = 0;
  Map<String, Object?>? lastImportPayload;

  @override
  Future<JourneyDLiveStageOutcome> importValidatedPackage({
    required Map<String, Object?> payload,
    required String importedBy,
  }) async {
    importCalls += 1;
    lastImportPayload = payload;
    final blob = payload.toString();
    if (blob.contains('SL-S17-JD-ADAPT-')) {
      return JourneyDLiveStageOutcome.failed(
        'symbolic_lineage_reached_import_payload',
      );
    }
    return importOutcome;
  }

  @override
  Future<JourneyDLiveStageOutcome> publishAndApprove({
    required String versionId,
    required String actor,
  }) async {
    publishApproveCalls += 1;
    return publishApproveOutcome;
  }
}

class FakeJourneyDLiveEnrolment implements JourneyDLiveEnrolment {
  FakeJourneyDLiveEnrolment({JourneyDLiveEnrolResult? result})
    : result =
          result ??
          const JourneyDLiveEnrolResult(
            state: JourneyDPublicationStageState.applied,
            assignmentId: 'd4444444-4444-4444-8444-444444444444',
            assignmentIdRedacted: 'd4444444…',
            detail: 'synthetic_enrol',
          );

  JourneyDLiveEnrolResult result;
  int calls = 0;

  @override
  Future<JourneyDLiveEnrolResult> enrol({
    required String programmeVersionId,
  }) async {
    calls += 1;
    return result;
  }
}

class FakeJourneyDLiveMaterialisation implements JourneyDLiveMaterialisation {
  FakeJourneyDLiveMaterialisation({JourneyDLiveStageOutcome? outcome})
    : outcome =
          outcome ??
          JourneyDLiveStageOutcome.applied(detail: 'synthetic_materialise');

  JourneyDLiveStageOutcome outcome;
  int calls = 0;
  String? lastAssignmentId;

  @override
  Future<JourneyDLiveStageOutcome> materialise({
    required String programmeAssignmentId,
  }) async {
    calls += 1;
    lastAssignmentId = programmeAssignmentId;
    return outcome;
  }
}
