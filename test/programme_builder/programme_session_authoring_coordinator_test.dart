import 'package:cohort_platform/features/programme_builder/models/programme_session_authoring_result.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_session_authoring_coordinator.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';
import '../support/session_library_test_support.dart';

void main() {
  ProgrammeSessionAuthoringContext buildContext({
    ProgrammeSessionAuthoringIntent intent =
        ProgrammeSessionAuthoringIntent.createBlank,
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
    );
  }

  group('ProgrammeSessionAuthoringCoordinator', () {
    test('saveAndAttach persists local draft with durable ID and attaches once',
        () async {
      final document = buildProgrammeDocumentWithSlot();
      final protocolService = FakeProtocolBuilderService();
      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: document,
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final draft = buildValidProgrammeSessionDraft();
      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: draft,
      );

      expect(result.isAttached, isTrue);
      expect(result.contentId, testDurableSessionId);
      expect(protocolService.saveCallCount, 1);
      expect(assignmentPort.assignCallCount, 1);
      expect(assignmentPort.lastAssignedContentId, testDurableSessionId);
      expect(assignmentPort.lastAssignedDisplayTitle, 'Morning Strength');

      final saved = protocolService.drafts[testDurableSessionId];
      expect(saved, isNotNull);
      expect(saved!.contentKind, TrainingContentKind.session);
      expect(saved.authoringScope, TrainingAuthoringScope.programmeOnly);
      expect(saved.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(saved.published, isFalse);
      expect(saved.programmeVersionId, testProgrammeVersionId);
      expect(saved.ownerId, 'dev-coach');

      final updatedSlot = result.updatedDocument!.template.weeks.first.days
          .first.slots.first;
      expect(updatedSlot.protocolId, testDurableSessionId);
      expect(updatedSlot.displayTitle, 'Morning Strength');
      expect(result.updatedDocument!.hasUnsavedChanges, isTrue);
    });

    test('validation rejects blank title', () async {
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: FakeProtocolBuilderService(),
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final draft = buildValidProgrammeSessionDraft(name: '   ');
      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: draft,
      );

      expect(result.status, ProgrammeSessionAuthoringStatus.validationFailed);
    });

    test('validation rejects cohort protocol draft', () async {
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: FakeProtocolBuilderService(),
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final draft = buildValidProgrammeSessionDraft().copyWith(
        contentKind: TrainingContentKind.cohortProtocol,
      );
      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: draft,
      );

      expect(result.status, ProgrammeSessionAuthoringStatus.validationFailed);
    });

    test('validation rejects missing programme version', () async {
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: FakeProtocolBuilderService(),
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.saveAndAttach(
        context: buildContext().copyWith(programmeVersionId: '  '),
        draft: buildValidProgrammeSessionDraft(),
      );

      expect(result.status, ProgrammeSessionAuthoringStatus.validationFailed);
    });

    test('validation rejects missing slot', () async {
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: FakeProtocolBuilderService(),
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
          slotExistsOverride: ({required weekLocalId, required dayLocalId, required slotLocalId}) =>
              false,
        ),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: buildValidProgrammeSessionDraft(),
      );

      expect(result.status, ProgrammeSessionAuthoringStatus.slotNotFound);
    });

    test('save failure does not attempt attach', () async {
      final protocolService = FakeProtocolBuilderService()..failSave = true;
      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: buildValidProgrammeSessionDraft(),
      );

      expect(result.status, ProgrammeSessionAuthoringStatus.sessionSaveFailed);
      expect(assignmentPort.assignCallCount, 0);
      expect(result.coachMessage, 'Session could not be saved.');
    });

    test('partial attach failure retains saved content id', () async {
      final protocolService = FakeProtocolBuilderService();
      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
        failAttach: true,
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.saveAndAttach(
        context: buildContext(),
        draft: buildValidProgrammeSessionDraft(),
      );

      expect(result.status,
          ProgrammeSessionAuthoringStatus.sessionSavedAttachFailed);
      expect(result.partialState?.savedContentId, testDurableSessionId);
      expect(protocolService.saveCallCount, 1);
      expect(assignmentPort.assignCallCount, 1);
    });

    test('retry attach does not call save again', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testDurableSessionId] =
          buildValidProgrammeSessionDraft(
        protocolId: testDurableSessionId,
      );

      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.retryAttach(
        context: buildContext(),
        savedContentId: testDurableSessionId,
        displayTitle: 'Morning Strength',
      );

      expect(result.isAttached, isTrue);
      expect(protocolService.saveCallCount, 0);
      expect(assignmentPort.assignCallCount, 1);
    });

    test('attachExistingSession attaches without saving', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.libraryDrafts[testDurableSessionId] =
          buildValidLibrarySessionDraft(
        protocolId: testDurableSessionId,
        name: 'Library Session',
      );

      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.attachExistingSession(
        context: buildContext(),
        contentId: testDurableSessionId,
        displayTitle: 'Library Session',
      );

      expect(result.isAttached, isTrue);
      expect(protocolService.saveCallCount, 0);
      expect(protocolService.librarySaveCallCount, 0);
      expect(assignmentPort.assignCallCount, 1);
      expect(assignmentPort.lastAssignedContentId, testDurableSessionId);
    });

    test('edit preserves durable ID and updates existing session', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.drafts[testDurableSessionId] =
          buildValidProgrammeSessionDraft(
        protocolId: testDurableSessionId,
        name: 'Original',
      );

      final assignmentPort = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: assignmentPort,
        idGenerator: FixedSessionIdGenerator('should-not-be-used'),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final edited = buildValidProgrammeSessionDraft(
        protocolId: testDurableSessionId,
        name: 'Updated Session',
      );

      final result = await coordinator.saveAndAttach(
        context: buildContext(
          intent: ProgrammeSessionAuthoringIntent.editCoachSession,
        ),
        draft: edited,
      );

      expect(result.isAttached, isTrue);
      expect(protocolService.saveCallCount, 1);
      expect(protocolService.drafts.length, 1);
      expect(protocolService.drafts[testDurableSessionId]!.name,
          'Updated Session');
      expect(assignmentPort.lastAssignedDisplayTitle, 'Updated Session');
    });
  });
}

extension on ProgrammeSessionAuthoringContext {
  ProgrammeSessionAuthoringContext copyWith({
    String? programmeVersionId,
  }) {
    return ProgrammeSessionAuthoringContext(
      programmeVersionId: programmeVersionId ?? this.programmeVersionId,
      weekLocalId: weekLocalId,
      dayLocalId: dayLocalId,
      slotLocalId: slotLocalId,
      weekNumber: weekNumber,
      dayLabel: dayLabel,
      slotDisplayLabel: slotDisplayLabel,
      authoringIntent: authoringIntent,
      existingContentId: existingContentId,
      programmeLocationLabel: programmeLocationLabel,
    );
  }
}
