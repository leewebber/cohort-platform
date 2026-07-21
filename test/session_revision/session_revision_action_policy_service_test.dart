import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_action_decision.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_action_vocabulary.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_action_policy_service.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_relationship_service.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_service.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/in_memory_session_revision_delete_store.dart';
import '../support/in_memory_session_revision_relationship_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemorySessionRevisionRelationshipStore relationshipStore;
  late FakeProtocolBuilderService builder;
  late SessionRevisionActionPolicyService policyService;
  late SessionRevisionService revisionService;
  late InMemorySessionRevisionDeleteStore deleteStore;

  const sessionLineageId = 'session-lineage-1';
  const draftProtocolId = 'coach-session-draft';
  const publishedProtocolId = 'coach-session-published';
  const archivedProtocolId = 'coach-session-archived';

  SessionRevisionActionPolicyService buildPolicyService({
    SessionRevisionRelationshipService? relationshipService,
  }) {
    return SessionRevisionActionPolicyService(
      lineageStore: lineageStore,
      protocolBuilderService: builder,
      relationshipService: relationshipService,
    );
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    relationshipStore = InMemorySessionRevisionRelationshipStore(
      programmeTables: programmeTables,
    );
    builder = FakeProtocolBuilderService();
    deleteStore = InMemorySessionRevisionDeleteStore();

    policyService = buildPolicyService(
      relationshipService: SessionRevisionRelationshipService(
        relationshipStore: relationshipStore,
        lineageStore: lineageStore,
      ),
    );

    revisionService = SessionRevisionService(
      lineageStore: lineageStore,
      protocolBuilderService: builder,
      actionPolicyService: policyService,
      deleteStore: deleteStore,
    );

    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: draftProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.draft,
      revisionNumber: 1,
    );
    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: publishedProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.published,
      revisionNumber: 1,
    );
    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: archivedProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.archived,
      revisionNumber: 1,
    );
  });

  group('edit policy', () {
    test('draft editable', () async {
      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.edit);

      expect(decision.allowed, isTrue);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.allowedDraftEdit);
    });

    test('published edit blocked with create revision recommendation', () async {
      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.edit,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.publishedRevisionImmutable);
      expect(decision.recommendedAlternative, contains('revision 2'));
      expect(decision.userMessage, contains('Published revisions cannot be edited'));
    });

    test('archived edit blocked', () async {
      final decision =
          await policyService.evaluate(archivedProtocolId, SessionRevisionAction.edit);

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.archivedRevisionImmutable);
    });

    test('protected cohort protocol published edit remains blocked', () async {
      const cohortProtocolId = 'BW-001';
      _seedRevision(
        lineageStore: lineageStore,
        builder: builder,
        protocolId: cohortProtocolId,
        lifecycle: SessionRevisionLifecycleStatus.published,
        contentKind: TrainingContentKind.cohortProtocol,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      );

      final decision =
          await policyService.evaluate(cohortProtocolId, SessionRevisionAction.edit);

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.publishedRevisionImmutable);
    });
  });

  group('create new revision policy', () {
    test('published allowed', () async {
      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.createNewRevision,
      );

      expect(decision.allowed, isTrue);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.createRevisionFromPublished);
    });

    test('archived allowed', () async {
      final decision = await policyService.evaluate(
        archivedProtocolId,
        SessionRevisionAction.createNewRevision,
      );

      expect(decision.allowed, isTrue);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.createRevisionFromArchived);
    });

    test('draft blocked', () async {
      final decision = await policyService.evaluate(
        draftProtocolId,
        SessionRevisionAction.createNewRevision,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.draftContinueEditing);
    });

    test('official canonical content blocked with copy alternative', () async {
      const cohortProtocolId = 'BW-001';
      _seedRevision(
        lineageStore: lineageStore,
        builder: builder,
        protocolId: cohortProtocolId,
        lifecycle: SessionRevisionLifecycleStatus.published,
        contentKind: TrainingContentKind.cohortProtocol,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      );

      final decision = await policyService.evaluate(
        cohortProtocolId,
        SessionRevisionAction.createNewRevision,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.canonicalContentProtected);
      expect(decision.recommendedAlternative, contains('Copy and customise'));
    });
  });

  group('publish policy', () {
    test('draft publish allowed subject to validation', () async {
      final decision = await policyService.evaluate(
        draftProtocolId,
        SessionRevisionAction.publish,
      );

      expect(decision.allowed, isTrue);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.publishAllowedSubjectToValidation);
    });

    test('published blocked', () async {
      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.publish,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.revisionAlreadyPublished);
    });

    test('archived blocked', () async {
      final decision = await policyService.evaluate(
        archivedProtocolId,
        SessionRevisionAction.publish,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.archivedRevisionCannotPublish);
    });

    test('missing revision fails safely', () async {
      final decision = await policyService.evaluate(
        'missing-protocol',
        SessionRevisionAction.publish,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.revisionNotFound);
    });
  });

  group('archive policy', () {
    test('published unused allowed', () async {
      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.archive,
      );

      expect(decision.allowed, isTrue);
      expect(decision.severity, SessionRevisionActionSeverity.info);
    });

    test('published with programme references allowed with warning', () async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );

      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.archive,
      );

      expect(decision.allowed, isTrue);
      expect(decision.severity, SessionRevisionActionSeverity.warning);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.referencedByProgrammeVersions));
    });

    test('published with active assignments allowed with warning', () async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: programmeTables.lineages.first,
      );

      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.archive,
      );

      expect(decision.allowed, isTrue);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.usedByActiveAssignments));
    });

    test('published with history allowed with warning', () async {
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: publishedProtocolId,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.archive,
      );

      expect(decision.allowed, isTrue);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.hasHistoricalPerformances));
    });

    test('already archived handled idempotently', () async {
      final decision = await policyService.evaluate(
        archivedProtocolId,
        SessionRevisionAction.archive,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.alreadyArchived);
    });

    test('draft blocked', () async {
      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.archive);

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.draftRevisionCannotArchive);
    });
  });

  group('delete policy', () {
    test('unused draft allowed', () async {
      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isTrue);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.unusedDraft);
    });

    test('draft used by programme version blocked', () async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isFalse);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.referencedByProgrammeVersions));
      expect(decision.userMessage, contains('programme version'));
    });

    test('active assignment dependency blocked', () async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: programmeTables.lineages.first,
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isFalse);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.usedByActiveAssignments));
    });

    test('historical-only usage blocked', () async {
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: draftProtocolId,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isFalse);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.hasHistoricalPerformances));
      expect(decision.recommendedAlternative, contains('Archive'));
    });

    test('published unused blocked', () async {
      final decision = await policyService.evaluate(
        publishedProtocolId,
        SessionRevisionAction.delete,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.publishedRevisionImmutable);
    });

    test('archived unused blocked', () async {
      final decision = await policyService.evaluate(
        archivedProtocolId,
        SessionRevisionAction.delete,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.archivedRevisionImmutable);
    });

    test('multiple blockers all represented', () async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: programmeTables.lineages.first,
      );
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: draftProtocolId,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isFalse);
      expect(decision.reasons, containsAll([
        SessionRevisionActionReasonCode.usedByActiveAssignments,
        SessionRevisionActionReasonCode.referencedByProgrammeVersions,
        SessionRevisionActionReasonCode.hasHistoricalPerformances,
      ]));
    });

    test('relationship lookup failure blocks delete', () async {
      final failingPolicy = buildPolicyService(
        relationshipService: SessionRevisionRelationshipService(
          relationshipStore: _ThrowingRelationshipStore(programmeTables),
          lineageStore: lineageStore,
        ),
      );

      final decision = await failingPolicy.evaluate(
        draftProtocolId,
        SessionRevisionAction.delete,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.relationshipLookupFailed);
    });

    test('missing revision blocks delete', () async {
      final decision = await policyService.evaluate(
        'missing-protocol',
        SessionRevisionAction.delete,
      );

      expect(decision.allowed, isFalse);
      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.revisionNotFound);
    });

    test('protected founder revision blocked', () async {
      _seedRevision(
        lineageStore: lineageStore,
        builder: builder,
        protocolId: FounderAcceptanceContent.protocolId,
        lifecycle: SessionRevisionLifecycleStatus.draft,
      );

      final decision = await policyService.evaluate(
        FounderAcceptanceContent.protocolId,
        SessionRevisionAction.delete,
      );

      expect(decision.allowed, isFalse);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.canonicalContentProtected));
    });

    test('archived programme version reference still blocks delete', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        lifecycleStatus: ProgrammeLifecycleStatus.archived,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: draftProtocolId,
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isFalse);
      expect(decision.reasons,
          contains(SessionRevisionActionReasonCode.referencedByProgrammeVersions));
    });

    test('different revision in same lineage does not block exact delete', () async {
      const siblingProtocolId = 'coach-session-published-rev-2';
      _seedRevision(
        lineageStore: lineageStore,
        builder: builder,
        protocolId: siblingProtocolId,
        lifecycle: SessionRevisionLifecycleStatus.published,
        revisionNumber: 2,
      );
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: siblingProtocolId,
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.allowed, isTrue);
    });
  });

  group('messages and summary', () {
    test('counts pluralise correctly and omit raw UUIDs', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final versionOne = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-1',
        versionNumber: 1,
      );
      final versionTwo = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-2',
        versionNumber: 2,
      );

      for (final version in [versionOne, versionTwo]) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          programmeTables,
          version: version,
          id: 'week-${version.id}',
        );
        final dayOne = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${version.id}-1',
          dayOrder: 1,
        );
        final dayTwo = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${version.id}-2',
          dayOrder: 2,
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: dayOne,
          protocolId: draftProtocolId,
          id: 'slot-${version.id}-1',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: dayTwo,
          protocolId: draftProtocolId,
          id: 'slot-${version.id}-2',
        );
      }

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.userMessage, contains('2 programme versions'));
      expect(decision.userMessage, contains('4 slots'));
      expect(decision.userMessage.toLowerCase(), isNot(contains('version-1')));
    });

    test('deterministic primary blocker prefers active assignments', () async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: programmeTables.lineages.first,
      );
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: draftProtocolId,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final decision =
          await policyService.evaluate(draftProtocolId, SessionRevisionAction.delete);

      expect(decision.primaryReasonCode,
          SessionRevisionActionReasonCode.usedByActiveAssignments);
    });

    test('evaluateAll returns one decision per action', () async {
      final summary = await policyService.evaluateAll(draftProtocolId);

      expect(summary.decisions.keys, SessionRevisionAction.values);
      expect(summary.decisionFor(SessionRevisionAction.edit).allowed, isTrue);
      expect(summary.decisionFor(SessionRevisionAction.delete).allowed, isTrue);
    });
  });

  group('execution guards', () {
    test('delete cannot bypass policy', () async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );

      expect(
        () => revisionService.deleteRevision(draftProtocolId),
        throwsA(isA<SessionRevisionPolicyException>()),
      );
      expect(deleteStore.deletedProtocolIds, isEmpty);
    });

    test('unused draft delete succeeds through service', () async {
      deleteStore.existingProtocolIds.add(draftProtocolId);

      await revisionService.deleteRevision(draftProtocolId);

      expect(deleteStore.deletedProtocolIds, [draftProtocolId]);
    });

    test('archive preserves referenced content and only updates lifecycle', () async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );

      final archived = await revisionService.archiveRevision(publishedProtocolId);

      expect(archived.lifecycleStatus, SessionRevisionLifecycleStatus.archived);
      expect(programmeTables.slots.first.protocolId, publishedProtocolId);
    });

    test('published revision still cannot be saved in place via builder guard',
        () async {
      final published = builder.draftsById[publishedProtocolId]!;
      builder.saveDraftCalls.clear();

      expect(
        () => builder.saveDraft(
          published.copyWith(name: 'Changed name'),
        ),
        throwsA(isA<ProtocolBuilderException>()),
      );
    });

    test('create new revision remains valid edit path for published revision',
        () async {
      final result = await revisionService.createNewSessionRevision(
        sourceProtocolId: publishedProtocolId,
      );

      expect(result.revisionNumber, 2);
      expect(result.draft.lifecycleStatus, SessionRevisionLifecycleStatus.draft);
    });
  });
}

class _ThrowingRelationshipStore extends InMemorySessionRevisionRelationshipStore {
  _ThrowingRelationshipStore(InMemoryProgrammeTables tables)
      : super(programmeTables: tables);

  @override
  Future<List<SessionRevisionProgrammeReference>> listProgrammeSlotReferences(
    String protocolId,
  ) {
    throw Exception('lookup failed');
  }
}

void _seedRevision({
  required InMemorySessionLineageStore lineageStore,
  required FakeProtocolBuilderService builder,
  required String protocolId,
  required SessionRevisionLifecycleStatus lifecycle,
  int revisionNumber = 1,
  String sessionLineageId = 'session-lineage-1',
  TrainingContentKind contentKind = TrainingContentKind.session,
  TrainingAuthoringScope authoringScope = TrainingAuthoringScope.coachPrivate,
  TrainingEndorsementStatus endorsementStatus =
      TrainingEndorsementStatus.coachAuthored,
}) {
  SessionRevisionUsageTestFixtures.seedRevisionMetadata(
    lineageStore,
    protocolId: protocolId,
    sessionLineageId: sessionLineageId,
    revisionNumber: revisionNumber,
    lifecycleStatus: lifecycle,
  );

  builder.seed(
    ProtocolDraft(
      protocolId: protocolId,
      name: 'Coach Session',
      steps: const [],
      lifecycleStatus: lifecycle,
      revisionNumber: revisionNumber,
      sessionLineageId: sessionLineageId,
      published: lifecycle == SessionRevisionLifecycleStatus.published,
      contentKind: contentKind,
      authoringScope: authoringScope,
      endorsementStatus: endorsementStatus,
      ownerId: 'coach-1',
    ),
  );
}

ProgrammeVersion _attachProtocolToProgramme({
  required InMemoryProgrammeTables programmeTables,
  required String protocolId,
}) {
  final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
  final version = SessionRevisionUsageTestFixtures.seedVersion(
    programmeTables,
    lineage: lineage,
  );
  final week = SessionRevisionUsageTestFixtures.seedWeek(
    programmeTables,
    version: version,
  );
  final day = SessionRevisionUsageTestFixtures.seedDay(
    programmeTables,
    week: week,
  );
  SessionRevisionUsageTestFixtures.seedSlot(
    programmeTables,
    day: day,
    protocolId: protocolId,
  );
  return version;
}
