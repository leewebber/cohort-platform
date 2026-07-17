import 'package:cohort_platform/features/programme_builder/models/cohort_protocol_customisation_result.dart';
import 'package:cohort_platform/features/programme_builder/services/cohort_protocol_customisation_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_session_authoring_coordinator.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/training_library/services/session_library_authoring_coordinator.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';
import '../support/session_library_test_support.dart';

void main() {
  ProgrammeSessionAuthoringContext buildContext({
    ProgrammeSessionAuthoringIntent intent =
        ProgrammeSessionAuthoringIntent.copyCohortProtocol,
    String? sourceProtocolId,
  }) {
    return ProgrammeSessionAuthoringContext(
      programmeVersionId: testProgrammeVersionId,
      weekLocalId: testWeekLocalId,
      dayLocalId: testDayLocalId,
      slotLocalId: testSlotLocalId,
      weekNumber: 2,
      dayLabel: 'Tuesday',
      slotDisplayLabel: 'Morning',
      authoringIntent: intent,
      sourceProtocolId: sourceProtocolId,
    );
  }

  CohortProtocolCustomisationCoordinator buildCoordinator({
    required FakeProtocolBuilderService protocolService,
    required FakeProgrammeSessionAssignmentPort assignmentPort,
    String sessionId = testDurableSessionId,
  }) {
    return CohortProtocolCustomisationCoordinator(
      protocolBuilderService: protocolService,
      programmeSessionCoordinator: ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(sessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      ),
      librarySessionCoordinator: SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(sessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      ),
      sessionCloneService: const SessionCloneService(),
      coachIdentity: const FixedCoachIdentity('dev-coach'),
      assignmentPort: assignmentPort,
    );
  }

  group('CohortProtocolCustomisationCoordinator', () {
    test('prepareCopy clones eligible cohort protocol', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testCohortProtocolId] =
          buildEligibleCohortProtocolDraft();

      final coordinator = buildCoordinator(
        protocolService: protocolService,
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
      );

      final result = await coordinator.prepareCopy(
        sourceProtocolId: testCohortProtocolId,
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeContext: buildContext(),
      );

      expect(result.status, CohortProtocolCustomisationStatus.prepared);
      expect(result.copiedDraft, isNotNull);
      expect(result.copiedDraft!.contentKind, TrainingContentKind.session);
      expect(result.sourceContentId, testCohortProtocolId);
    });

    test('prepareCopy rejects ineligible session source', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts['bad-source'] = buildValidProgrammeSessionDraft(
        protocolId: 'bad-source',
      );

      final coordinator = buildCoordinator(
        protocolService: protocolService,
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
      );

      final result = await coordinator.prepareCopy(
        sourceProtocolId: 'bad-source',
        destination: CohortProtocolCopyDestination.programmeOnly,
      );

      expect(result.status, CohortProtocolCustomisationStatus.sourceNotEligible);
    });

    test('saveProgrammeCopy persists clone without mutating source', () async {
      final source = buildEligibleCohortProtocolDraft();
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testCohortProtocolId] = source;

      final document = buildProgrammeDocumentWithSlot();
      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: document,
      );
      final coordinator = buildCoordinator(
        protocolService: protocolService,
        assignmentPort: assignmentPort,
      );

      final prepared = await coordinator.prepareCopy(
        sourceProtocolId: testCohortProtocolId,
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeContext: buildContext(),
      );

      final edited = prepared.copiedDraft!.copyWith(
        name: 'Custom Threshold',
      );

      final saved = await coordinator.saveProgrammeCopy(
        context: buildContext(),
        draft: edited,
      );

      expect(saved.status, CohortProtocolCustomisationStatus.savedProgrammeOnly);
      expect(protocolService.saveCallCount, 1);
      expect(protocolService.drafts[testCohortProtocolId]!.name,
          'Threshold Intervals');
      expect(protocolService.drafts[testDurableSessionId]!.sourceContentId,
          testCohortProtocolId);
      expect(assignmentPort.lastAssignedContentId, testDurableSessionId);
    });

    test('saveLibraryCopy with attach partial failure retains library session',
        () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testCohortProtocolId] =
          buildEligibleCohortProtocolDraft();

      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
        failAttach: true,
      );
      final coordinator = buildCoordinator(
        protocolService: protocolService,
        assignmentPort: assignmentPort,
      );

      final prepared = await coordinator.prepareCopy(
        sourceProtocolId: testCohortProtocolId,
        destination: CohortProtocolCopyDestination.sessionLibrary,
        programmeContext: buildContext(),
      );

      final saved = await coordinator.saveLibraryCopy(
        context: buildContext(),
        draft: prepared.copiedDraft!,
      );

      expect(saved.status, CohortProtocolCustomisationStatus.savedAttachFailed);
      expect(protocolService.librarySaveCallCount, 1);
      expect(protocolService.libraryDrafts.containsKey(testDurableSessionId),
          isTrue);

      assignmentPort.failAttach = false;
      final retried = await coordinator.retryLibraryAttach(
        context: buildContext(),
        savedContentId: testDurableSessionId,
        displayTitle: prepared.copiedDraft!.name,
      );

      expect(retried.status,
          CohortProtocolCustomisationStatus.savedToLibraryAttached);
      expect(protocolService.librarySaveCallCount, 1);
    });

    test('save rejects draft that reuses source content id', () async {
      final source = buildEligibleCohortProtocolDraft();
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testCohortProtocolId] = source;

      final coordinator = buildCoordinator(
        protocolService: protocolService,
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
      );

      final invalidDraft = buildValidProgrammeSessionDraft(
        protocolId: testCohortProtocolId,
      ).copyWith(
        sourceContentId: testCohortProtocolId,
      );

      final saved = await coordinator.saveProgrammeCopy(
        context: buildContext(),
        draft: invalidDraft,
      );

      expect(saved.status, CohortProtocolCustomisationStatus.validationFailed);
      expect(protocolService.saveCallCount, 0);
    });
  });
}
