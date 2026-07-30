import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_constants.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_session_authoring_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_session_source_choice.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_edit_operations.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_session_authoring_coordinator.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/training_library/services/session_library_authoring_coordinator.dart';
import 'package:cohort_platform/features/training_library/models/session_library_authoring_result.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/training_content_classification.dart';
import 'package:cohort_platform/models/training_content_edit_policy.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

void main() {
  const policy = TrainingContentEditPolicy();

  ProtocolDraft cohortProtocol() {
    return ProtocolDraft(
      protocolId: 'RN-006',
      name: 'Classic Threshold',
      steps: const [
        ProtocolStepDraft(localId: 's1', stepOrder: 1, title: 'Warm-up'),
      ],
      contentKind: TrainingContentKind.cohortProtocol,
      authoringScope: TrainingAuthoringScope.cohortGlobal,
      endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      published: true,
    );
  }

  ProtocolDraft mySession({String ownerId = 'coach-1', bool published = true}) {
    return ProtocolDraft(
      protocolId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      name: 'My Upper Strength',
      steps: const [
        ProtocolStepDraft(localId: 's1', stepOrder: 1, title: 'Press'),
      ],
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      ownerId: ownerId,
      published: published,
    );
  }

  ProtocolDraft template({bool canonical = false}) {
    if (canonical) {
      return ProtocolDraft(
        protocolId: 'TMP-001',
        name: 'Full-Body Strength Template',
        steps: const [
          ProtocolStepDraft(localId: 's1', stepOrder: 1, title: 'Main'),
        ],
        contentKind: TrainingContentKind.sessionTemplate,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
        published: true,
      );
    }
    return ProtocolDraft(
      protocolId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      name: 'Strength Template',
      steps: const [
        ProtocolStepDraft(localId: 's1', stepOrder: 1, title: 'Main'),
      ],
      contentKind: TrainingContentKind.sessionTemplate,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      endorsementStatus: TrainingEndorsementStatus.unreviewed,
      ownerId: 'coach-1',
      published: true,
    );
  }

  ProgrammeSessionAuthoringContext authoringContext({
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

  group('ProgrammeSessionSourceChoice', () {
    test('exposes the four product choices', () {
      expect(
        ProgrammeSessionSourceChoice.values.map((e) => e.coachFacingLabel),
        [
          'Use Cohort Protocol',
          'Use My Session',
          'Build New Session',
          'Use Template',
        ],
      );
    });
  });

  group('TrainingContentEditPolicy', () {
    test('Cohort Protocols cannot be edited in place', () {
      expect(
        policy.canEditInPlace(cohortProtocol(), coachId: 'coach-1'),
        isFalse,
      );
      expect(policy.isReadOnlyCohortProtocol(cohortProtocol()), isTrue);
      expect(policy.requiresCoachOwnedCopy(cohortProtocol()), isTrue);
    });

    test('templates cannot be edited in place or live-attached', () {
      final draft = template();
      expect(policy.canEditInPlace(draft, coachId: 'coach-1'), isFalse);
      expect(
        policy.canAttachAsLiveReference(draft, coachId: 'coach-1'),
        isFalse,
      );
      expect(policy.canUseAsTemplateSource(draft), isTrue);
      expect(policy.isCanonicalTemplateSource(draft), isFalse);
      expect(policy.requiresCoachOwnedCopy(draft), isTrue);
      expect(
        policy.isCanonicalTemplateSource(template(canonical: true)),
        isTrue,
      );
    });

    test('My Sessions attach only for owning coach when published', () {
      final mine = mySession();
      expect(policy.canAttachAsLiveReference(mine, coachId: 'coach-1'), isTrue);
      expect(
        policy.canAttachAsLiveReference(mine, coachId: 'other-coach'),
        isFalse,
      );
      expect(
        policy.canAttachAsLiveReference(
          mySession(published: false),
          coachId: 'coach-1',
        ),
        isFalse,
      );
    });

    test('legacy unclassified content is not editable Cohort content', () {
      final legacy = ProtocolDraft(
        protocolId: 'legacy-1',
        name: 'Legacy',
        steps: const [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.coachPrivate,
        endorsementStatus: TrainingEndorsementStatus.unreviewed,
      );
      expect(TrainingContentClassification.isCohortProtocol(legacy), isFalse);
      expect(policy.canEditInPlace(legacy, coachId: 'coach-1'), isFalse);
      expect(
        policy.canAttachAsLiveReference(legacy, coachId: 'coach-1'),
        isFalse,
      );
    });
  });

  group('legacy metadata classification', () {
    test('null row fields never become cohort endorsed', () {
      final loaded = ProtocolDraft.applyTrainingContentMetadata(
        draft: ProtocolDraft(protocolId: 'x', name: 'X', steps: const []),
        row: const {},
      );
      expect(loaded.contentKind, isNot(TrainingContentKind.cohortProtocol));
      expect(
        loaded.endorsementStatus,
        isNot(TrainingEndorsementStatus.cohortEndorsed),
      );
      expect(TrainingContentClassification.isCohortProtocol(loaded), isFalse);
    });
  });

  group('template copy-on-use', () {
    test('clone preserves provenance and does not mutate source identity', () {
      final source = template();
      const cloneService = SessionCloneService();
      final copy = cloneService.cloneTemplateToSession(
        source: source,
        newContentId: 'local-copy-session-1',
        ownerId: 'coach-1',
        programmeVersionId: testProgrammeVersionId,
      );

      expect(copy.protocolId, isNot(source.protocolId));
      expect(copy.contentKind, TrainingContentKind.session);
      expect(copy.authoringScope, TrainingAuthoringScope.programmeOnly);
      expect(copy.sourceContentId, source.protocolId);
      expect(copy.sourceContentKind, TrainingContentKind.sessionTemplate);
      expect(source.contentKind, TrainingContentKind.sessionTemplate);
    });
  });

  group('ProgrammeSessionAuthoringCoordinator attach guards', () {
    test('select-and-attach is idempotent for repeated callbacks', () async {
      final session = mySession();
      final protocolService = FakeProtocolBuilderService()
        ..drafts[session.protocolId] = session;
      final port = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: port,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final first = await coordinator.attachExistingSession(
        context: authoringContext(),
        contentId: session.protocolId,
        displayTitle: session.name,
      );
      final second = await coordinator.attachExistingSession(
        context: authoringContext(),
        contentId: session.protocolId,
        displayTitle: session.name,
      );

      expect(first.isAttached, isTrue);
      expect(
        second.status,
        ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
      );
      expect(port.assignCallCount, 1);
    });

    test('templates cannot be live-attached via My Sessions path', () async {
      final tmpl = template();
      final protocolService = FakeProtocolBuilderService()
        ..drafts[tmpl.protocolId] = tmpl;
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final result = await coordinator.attachExistingSession(
        context: authoringContext(),
        contentId: tmpl.protocolId,
        displayTitle: tmpl.name,
      );

      expect(result.isAttached, isFalse);
      expect(result.coachMessage, contains('Use Template'));
    });

    test(
      'prepareDraftFromTemplate returns coach-owned programme session',
      () async {
        final tmpl = template(canonical: true);
        final protocolService = FakeProtocolBuilderService()
          ..drafts[tmpl.protocolId] = tmpl;
        final coordinator = ProgrammeSessionAuthoringCoordinator(
          protocolBuilderService: protocolService,
          assignmentPort: FakeProgrammeSessionAssignmentPort(
            document: buildProgrammeDocumentWithSlot(),
          ),
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('coach-1'),
        );

        final draft = await coordinator.prepareDraftFromTemplate(
          context: authoringContext(
            intent: ProgrammeSessionAuthoringIntent.fromTemplate,
          ),
          templateContentId: tmpl.protocolId,
        );

        expect(draft.contentKind, TrainingContentKind.session);
        expect(draft.authoringScope, TrainingAuthoringScope.programmeOnly);
        expect(draft.sourceContentKind, TrainingContentKind.sessionTemplate);
        expect(draft.ownerId, 'coach-1');
        expect(draft.protocolId, isNot(tmpl.protocolId));
      },
    );

    test(
      'prepareDraftFromTemplate rejects non-canonical template sources',
      () async {
        final tmpl = template();
        final protocolService = FakeProtocolBuilderService()
          ..drafts[tmpl.protocolId] = tmpl;
        final coordinator = ProgrammeSessionAuthoringCoordinator(
          protocolBuilderService: protocolService,
          assignmentPort: FakeProgrammeSessionAssignmentPort(
            document: buildProgrammeDocumentWithSlot(),
          ),
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('coach-1'),
        );

        expect(
          () => coordinator.prepareDraftFromTemplate(
            context: authoringContext(
              intent: ProgrammeSessionAuthoringIntent.fromTemplate,
            ),
            templateContentId: tmpl.protocolId,
          ),
          throwsA(isA<ProtocolBuilderException>()),
        );
      },
    );
  });

  group('Cohort customisation provenance', () {
    test('clone creates derivative without mutating source protocol id', () {
      final source = cohortProtocol();
      const cloneService = SessionCloneService();
      final copy = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: 'local-copy-session-9',
        ownerId: 'coach-1',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: testProgrammeVersionId,
      );

      expect(source.protocolId, 'RN-006');
      expect(copy.protocolId, isNot('RN-006'));
      expect(copy.sourceContentId, 'RN-006');
      expect(copy.sourceContentKind, TrainingContentKind.cohortProtocol);
      expect(copy.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(TrainingContentClassification.isCohortProtocol(copy), isFalse);
    });
  });

  group('duplicated week reference semantics', () {
    test('duplicate week reuses the same protocol_id reference', () {
      final document = buildProgrammeDocumentWithSlot();
      final withSession = const ProgrammeBuilderEditOperations().assignProtocol(
        document,
        weekLocalId: testWeekLocalId,
        dayLocalId: testDayLocalId,
        slotLocalId: testSlotLocalId,
        protocolId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        displayTitle: 'Shared Session',
      );
      final weekId = withSession.template.allWeeks.first.localId;
      final duplicated = const ProgrammeBuilderEditOperations().duplicateWeek(
        withSession,
        weekLocalId: weekId,
      );

      final originalProtocolId =
          withSession.template.allWeeks.first.days.first.slots.first.protocolId;
      final duplicatedProtocolId =
          duplicated.template.allWeeks.last.days.first.slots.first.protocolId;

      expect(originalProtocolId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      expect(duplicatedProtocolId, originalProtocolId);
      expect(
        ProgrammeBuilderConstants.isUnassignedProtocolId(duplicatedProtocolId),
        isFalse,
      );
    });
  });

  group('adversarial persistence and slot integrity', () {
    test(
      'cannot overwrite Cohort Protocol row with Session draft via save',
      () async {
        final cohort = cohortProtocol().copyWith(
          protocolId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        );
        final protocolService = FakeProtocolBuilderService()
          ..drafts[cohort.protocolId] = cohort;

        expect(
          () => protocolService.saveDraft(
            mySession().copyWith(protocolId: cohort.protocolId),
          ),
          throwsA(
            isA<ProtocolBuilderException>().having(
              (e) => e.message,
              'message',
              contains('cannot be overwritten'),
            ),
          ),
        );
      },
    );

    test('create Save & Attach always mints a new ID (no UUID keep)', () async {
      final forgedId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
      final protocolService = FakeProtocolBuilderService()
        ..drafts[forgedId] = cohortProtocol().copyWith(protocolId: forgedId);
      final port = FakeProgrammeSessionAssignmentPort(
        document: buildProgrammeDocumentWithSlot(),
      );
      final coordinator = ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: port,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final result = await coordinator.saveAndAttach(
        context: authoringContext(),
        draft: buildValidProgrammeSessionDraft(protocolId: forgedId),
      );

      expect(result.isAttached, isTrue);
      expect(result.contentId, testDurableSessionId);
      expect(
        protocolService.drafts[forgedId]?.contentKind,
        TrainingContentKind.cohortProtocol,
      );
      expect(
        protocolService.drafts[testDurableSessionId]?.contentKind,
        TrainingContentKind.session,
      );
    });

    test('assignProtocol with path does not fan out to colliding slot ids', () {
      final ops = const ProgrammeBuilderEditOperations();
      final document = ProgrammeBuilderDocument.clean(
        metadata: ProgrammeVersionDraftMetadata(
          versionId: testProgrammeVersionId,
          lineageId: 'lineage-1',
          lineageCode: 'COHORT-TEST',
          versionNumber: 1,
          name: 'Collision Test',
        ),
        template: ProgrammeTemplateDraft(
          weeks: [
            ProgrammeWeekDraft(
              localId: 'week-a',
              weekNumber: 1,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-a',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: const [
                    ProgrammeSessionSlotDraft(
                      localId: 'shared-slot',
                      sessionOrder: 1,
                      protocolId: '',
                    ),
                  ],
                ),
              ],
            ),
            ProgrammeWeekDraft(
              localId: 'week-b',
              weekNumber: 2,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-b',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: const [
                    ProgrammeSessionSlotDraft(
                      localId: 'shared-slot',
                      sessionOrder: 1,
                      protocolId: '',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final assigned = ops.assignProtocol(
        document,
        weekLocalId: 'week-b',
        dayLocalId: 'day-b',
        slotLocalId: 'shared-slot',
        protocolId: 'session-1',
        displayTitle: 'Only week B',
      );

      expect(
        assigned.template.allWeeks.first.days.first.slots.first.protocolId,
        isEmpty,
      );
      expect(
        assigned.template.allWeeks.last.days.first.slots.first.protocolId,
        'session-1',
      );
    });

    test(
      'stale missing slot after save reports attach failure not success',
      () async {
        final protocolService = FakeProtocolBuilderService();
        final port = FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
          slotExistsOverride:
              ({
                required String weekLocalId,
                required String dayLocalId,
                required String slotLocalId,
              }) {
                // Preflight passes once, then fails after save.
                return protocolService.saveCallCount == 0;
              },
        );
        final coordinator = ProgrammeSessionAuthoringCoordinator(
          protocolBuilderService: protocolService,
          assignmentPort: port,
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('coach-1'),
        );

        final result = await coordinator.saveAndAttach(
          context: authoringContext(),
          draft: buildValidProgrammeSessionDraft(),
        );

        expect(result.isAttached, isFalse);
        expect(
          result.status,
          ProgrammeSessionAuthoringStatus.sessionSavedAttachFailed,
        );
        expect(protocolService.saveCallCount, 1);
        expect(port.assignCallCount, 0);
      },
    );

    test('clone rejects identical source and target content ids', () {
      expect(
        () => const SessionCloneService().cloneCohortProtocolToSession(
          source: cohortProtocol(),
          newContentId: 'RN-006',
          ownerId: 'coach-1',
          destination: CohortProtocolCopyDestination.programmeOnly,
          programmeVersionId: testProgrammeVersionId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('another coach cannot edit My Session below the UI', () async {
      final session = mySession(ownerId: 'coach-1');
      final protocolService = FakeProtocolBuilderService()
        ..drafts[session.protocolId] = session;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-2'),
      );

      final result = await coordinator.updateSession(draft: session);

      expect(result.status, SessionLibraryAuthoringStatus.ownershipInvalid);
      expect(protocolService.librarySaveCallCount, 0);
    });

    test('unknown source_content_kind does not coerce to session', () {
      final loaded = ProtocolDraft.applyTrainingContentMetadata(
        draft: ProtocolDraft(protocolId: 'x', name: 'X', steps: const []),
        row: const {
          'content_kind': 'session',
          'authoring_scope': 'coach_private',
          'endorsement_status': 'coach_authored',
          'source_content_id': 'RN-006',
          'source_content_kind': 'not_a_real_kind',
        },
      );

      expect(loaded.sourceContentId, 'RN-006');
      expect(loaded.sourceContentKind, isNull);
    });

    test('assignProtocol rejects zero matches for stale path', () {
      final document = buildProgrammeDocumentWithSlot();
      expect(
        () => const ProgrammeBuilderEditOperations().assignProtocol(
          document,
          weekLocalId: 'missing-week',
          dayLocalId: testDayLocalId,
          slotLocalId: testSlotLocalId,
          protocolId: 'session-1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('updateSlotMetadata is path-scoped under colliding slot ids', () {
      final ops = const ProgrammeBuilderEditOperations();
      final document = ProgrammeBuilderDocument.clean(
        metadata: ProgrammeVersionDraftMetadata(
          versionId: testProgrammeVersionId,
          lineageId: 'lineage-1',
          lineageCode: 'COHORT-TEST',
          versionNumber: 1,
          name: 'Collision Metadata',
        ),
        template: ProgrammeTemplateDraft(
          weeks: [
            ProgrammeWeekDraft(
              localId: 'week-a',
              weekNumber: 1,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-a',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: const [
                    ProgrammeSessionSlotDraft(
                      localId: 'shared-slot',
                      sessionOrder: 1,
                      protocolId: 'a',
                    ),
                  ],
                ),
              ],
            ),
            ProgrammeWeekDraft(
              localId: 'week-b',
              weekNumber: 2,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-b',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: const [
                    ProgrammeSessionSlotDraft(
                      localId: 'shared-slot',
                      sessionOrder: 1,
                      protocolId: 'b',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final updated = ops.updateSlotMetadata(
        document,
        weekLocalId: 'week-a',
        dayLocalId: 'day-a',
        slotLocalId: 'shared-slot',
        displayTitle: 'Only A',
      );

      expect(
        updated.template.allWeeks.first.days.first.slots.first.displayTitle,
        'Only A',
      );
      expect(
        updated.template.allWeeks.last.days.first.slots.first.displayTitle,
        isNull,
      );
    });

    test(
      'save failure before attach leaves programme slot unchanged',
      () async {
        final protocolService = FakeProtocolBuilderService()..failSave = true;
        final port = FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        );
        final coordinator = ProgrammeSessionAuthoringCoordinator(
          protocolBuilderService: protocolService,
          assignmentPort: port,
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('coach-1'),
        );

        final result = await coordinator.saveAndAttach(
          context: authoringContext(),
          draft: buildValidProgrammeSessionDraft(),
        );

        expect(result.isAttached, isFalse);
        expect(
          result.status,
          ProgrammeSessionAuthoringStatus.sessionSaveFailed,
        );
        expect(port.assignCallCount, 0);
        expect(
          port
              .document!
              .template
              .allWeeks
              .first
              .days
              .first
              .slots
              .first
              .protocolId,
          isEmpty,
        );
      },
    );
  });
}
