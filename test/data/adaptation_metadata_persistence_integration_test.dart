import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_compiler.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_clone.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_protocol_row_store.dart';
import '../support/in_memory_session_block_repository.dart';
import '../support/programme_session_authoring_test_support.dart';

void main() {
  group('A. Session adaptation metadata persistence', () {
    late InMemoryProtocolRowStore store;

    setUp(() {
      store = InMemoryProtocolRowStore();
    });

    test('create → persist → read → update → reload', () {
      const protocolId = 'sess-adapt-1';
      final created = ProtocolDraft(
        protocolId: protocolId,
        name: 'Lower Strength',
        sessionFormat: 'structured_strength',
        steps: const [],
        primarySessionIntent: SessionIntent.lowerBodyStrength,
        secondarySessionIntents: const [SessionIntent.prehabilitation],
        minimumViableDurationMin: 25,
      );

      store.upsertFromDraft(created);
      final upsertMap = store.buildUpsertMap(created, published: false);
      expect(
        upsertMap[SessionAdaptationMetadataKeys.primarySessionIntent],
        'lower_body_strength',
      );
      expect(
        upsertMap[SessionAdaptationMetadataKeys.secondarySessionIntents],
        ['prehabilitation'],
      );
      expect(
        upsertMap[SessionAdaptationMetadataKeys.minimumViableDurationMin],
        25,
      );

      final read = store.loadProtocol(protocolId);
      expect(read.primarySessionIntent, SessionIntent.lowerBodyStrength);
      expect(read.secondarySessionIntents, [SessionIntent.prehabilitation]);
      expect(read.minimumViableDurationMin, 25);

      final updated = created.copyWith(
        primarySessionIntent: SessionIntent.fullBodyStrength,
        minimumViableDurationMin: 30,
        clearSecondarySessionIntents: true,
      );
      store.upsertFromDraft(updated);

      final reloaded = store.loadDraft(protocolId: protocolId);
      expect(reloaded.primarySessionIntent, SessionIntent.fullBodyStrength);
      expect(reloaded.secondarySessionIntents, isEmpty);
      expect(reloaded.minimumViableDurationMin, 30);
    });
  });

  group('B. Block adaptation metadata persistence', () {
    test('create → persist → read → update → reload', () async {
      final repository = InMemorySessionBlockRepository();
      const sessionId = 'sess-blocks-1';

      final created = SessionBlock(
        localId: 'block-1',
        blockType: SessionBlockType.strength,
        title: 'Main',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        blockPriority: BlockPriority.essential,
        adaptationPolicy: explicitBlockPolicy,
      );

      await repository.replaceSessionBlocks(
        sessionId: sessionId,
        blocks: [created],
      );

      final read = await repository.getSessionBlocks(sessionId);
      expect(read, hasLength(1));
      expect(read.first.blockPriority, BlockPriority.essential);
      expect(read.first.adaptationPolicy?.toJson(), explicitBlockPolicy.toJson());
      expect(read.first.effectiveBlockPriority, BlockPriority.essential);

      final defaultOnly = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 2,
      );
      expect(defaultOnly.blockPriority, isNull);

      await repository.replaceSessionBlocks(
        sessionId: sessionId,
        blocks: [
          read.first.copyWith(
            blockPriority: BlockPriority.secondary,
            clearAdaptationPolicy: true,
          ),
          defaultOnly.copyWith(position: 2),
        ],
      );

      final reloaded = await repository.getSessionBlocks(sessionId);
      expect(reloaded.first.blockPriority, BlockPriority.secondary);
      expect(reloaded.first.adaptationPolicy, isNull);
      expect(reloaded.last.blockPriority, isNull);
      expect(reloaded.last.effectiveBlockPriority, BlockPriority.primary);
    });

    test('derived defaults are not written to row maps', () {
      final block = SessionBlock.create(
        blockType: SessionBlockType.strength,
        position: 1,
      );
      final row = block.toRowMap(sessionId: 'sess-1');
      expect(
        row.containsKey(SessionBlockAdaptationMetadataKeys.blockPriority),
        isFalse,
      );
      expect(
        row.containsKey(SessionBlockAdaptationMetadataKeys.adaptationPolicy),
        isFalse,
      );

      final explicit = block.copyWith(blockPriority: BlockPriority.optional);
      final explicitRow = explicit.toRowMap(sessionId: 'sess-1');
      expect(
        explicitRow[SessionBlockAdaptationMetadataKeys.blockPriority],
        'optional',
      );
    });
  });

  group('C. Programme duplication preserves referenced session metadata', () {
    test('duplicate programme keeps protocol_id; metadata resolves from store',
        () async {
      const sourceVersionId = '44444444-4444-4444-4444-444444444444';
      const protocolId = testCohortProtocolId;
      const coachId = 'dev-coach';

      final protocolStore = InMemoryProtocolRowStore()
        ..upsertFromDraft(
          cohortProtocolWithAdaptationMetadata(protocolId: protocolId),
          published: true,
        );

      final tables = InMemoryProgrammeTables();
      final versionStore = InMemoryProgrammeVersionStore(tables);
      final assignmentStore = InMemoryProgrammeAssignmentStore(tables);
      final service = ProgrammeBuilderServiceImpl(
        versionStore: versionStore,
        assignmentStore: assignmentStore,
        validationService: ProgrammeBuilderValidationServiceImpl(),
        compiler: const ProgrammeBuilderCompiler(),
      );

      tables.lineages.add(
        ProgrammeLineage(id: 'lineage-src', code: 'COHORT-DUP-SRC'),
      );
      tables.versions.add(
        ProgrammeVersion(
          id: sourceVersionId,
          lineageId: 'lineage-src',
          versionNumber: 1,
          lifecycleStatus: ProgrammeLifecycleStatus.published,
          libraryScope: ProgrammeLibraryScope.coachPrivate,
          ownerType: ProgrammeOwnerType.coach,
          ownerId: coachId,
          name: 'Source',
        ),
      );

      final sourceDocument = ProgrammeBuilderDocument.clean(
        metadata: ProgrammeVersionDraftMetadata(
          versionId: sourceVersionId,
          lineageId: 'lineage-src',
          lineageCode: 'COHORT-DUP-SRC',
          versionNumber: 1,
          name: 'Source Programme',
        ),
        template: ProgrammeTemplateDraft(
          weeks: [
            ProgrammeWeekDraft(
              localId: 'week-1',
              weekNumber: 1,
              days: [
                ProgrammeDayDraft(
                  localId: 'day-1',
                  dayKey: 'day_1',
                  dayOrder: 1,
                  slots: [
                    ProgrammeSessionSlotDraft(
                      localId: 'slot-1',
                      sessionOrder: 1,
                      protocolId: protocolId,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      await versionStore.saveTemplateTree(
        version: tables.versions.first,
        tree: const ProgrammeBuilderCompiler().toTemplateTree(sourceDocument),
      );

      final duplicateResult = await service.duplicateProgramme(
        sourceVersionId: sourceVersionId,
        coachId: coachId,
        newLineageCode: 'COHORT-DUP-TARGET',
        newProgrammeName: 'Duplicate Target',
      );

      expect(
        duplicateResult.status,
        ProgrammeBuilderOperationStatus.duplicated,
      );
      final dupDocument = duplicateResult.document!;
      final dupProtocolId = dupDocument.template.allWeeks.first.days.first.slots
          .first.protocolId;
      expect(dupProtocolId, protocolId);

      final resolved = protocolStore.loadProtocol(protocolId);
      expect(resolved.primarySessionIntent, SessionIntent.threshold);
      expect(resolved.minimumViableDurationMin, 30);
    });
  });

  group('D. Session and template duplication preserves metadata', () {
    const cloneService = SessionCloneService();
    const revisionClone = SessionRevisionClone();

    test('cohort protocol copy duplicates session adaptation metadata', () {
      final source = buildEligibleCohortProtocolDraft().copyWith(
        primarySessionIntent: SessionIntent.vo2Max,
        secondarySessionIntents: const [SessionIntent.runningEconomy],
        minimumViableDurationMin: 20,
        blocks: [
          SessionBlock(
            localId: 'block-src',
            blockType: SessionBlockType.conditioning,
            title: 'Engine',
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            blockPriority: BlockPriority.primary,
            adaptationPolicy: explicitBlockPolicy,
          ),
        ],
      );

      final clone = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: SessionCloneService.newLocalCloneDraftId(),
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.sessionLibrary,
      );

      expect(clone.primarySessionIntent, SessionIntent.vo2Max);
      expect(clone.secondarySessionIntents, [SessionIntent.runningEconomy]);
      expect(clone.minimumViableDurationMin, 20);
      expect(clone.blocks.first.blockPriority, BlockPriority.primary);
      expect(
        clone.blocks.first.adaptationPolicy?.toJson(),
        explicitBlockPolicy.toJson(),
      );
    });

    test('new session revision copy preserves session adaptation metadata', () {
      final source = buildEligibleCohortProtocolDraft().copyWith(
        sessionLineageId: 'lineage-session-1',
        revisionNumber: 2,
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
        primarySessionIntent: SessionIntent.longRun,
        minimumViableDurationMin: 40,
      );

      final revisionDraft = revisionClone.cloneNewRevisionDraft(
        source: source,
        newProtocolId: 'sess-rev-3',
        sessionLineageId: 'lineage-session-1',
        revisionNumber: 3,
      );

      expect(revisionDraft.primarySessionIntent, SessionIntent.longRun);
      expect(revisionDraft.minimumViableDurationMin, 40);
    });
  });

  group('E. Protocol copy preserves canonical session metadata', () {
    test('clone maps dbValue strings suitable for performance_protocols row', () {
      final source = cohortProtocolWithAdaptationMetadata(
        protocolId: testCohortProtocolId,
      );
      const cloneService = SessionCloneService();
      final copied = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: 'local-copy-session-meta',
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: testProgrammeVersionId,
      );

      final row = copied.toProtocolMap();
      expect(row[SessionAdaptationMetadataKeys.primarySessionIntent], 'threshold');
      expect(
        row[SessionAdaptationMetadataKeys.secondarySessionIntents],
        ['aerobic_base'],
      );
      expect(row[SessionAdaptationMetadataKeys.minimumViableDurationMin], 30);
    });
  });

  group('F. Legacy records without metadata still load', () {
    test('protocol row without adaptation keys', () {
      final protocol = Protocol.fromMap({
        'protocol_id': 'legacy-proto',
        'name': 'Legacy',
        'duration_min': 45,
      });

      expect(protocol.primarySessionIntent, isNull);
      expect(protocol.secondarySessionIntents, isEmpty);
      expect(protocol.minimumViableDurationMin, isNull);
    });

    test('block row without adaptation keys', () async {
      final repository = InMemorySessionBlockRepository();
      await repository.replaceSessionBlocks(
        sessionId: 'legacy-session',
        blocks: [
          SessionBlock(
            localId: 'b1',
            blockType: SessionBlockType.accessory,
            title: 'Accessory',
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: 1,
          ),
        ],
      );

      final blocks = await repository.getSessionBlocks('legacy-session');
      expect(blocks.first.blockPriority, isNull);
      expect(blocks.first.adaptationPolicy, isNull);
      expect(blocks.first.effectiveBlockPriority, isNotNull);
    });
  });

  group('G. Unknown enum values do not crash programme resolution', () {
    test('invalid session intent on one slot does not block others', () {
      final store = InMemoryProtocolRowStore()
        ..upsertFromDraft(
          cohortProtocolWithAdaptationMetadata(protocolId: 'good-proto'),
        );

      store.rowsByProtocolId['bad-proto'] = {
        'protocol_id': 'bad-proto',
        'name': 'Bad metadata',
        SessionAdaptationMetadataKeys.primarySessionIntent: 'not_real_intent',
        SessionAdaptationMetadataKeys.secondarySessionIntents: [
          'lower_body_strength',
          'unknown_intent',
        ],
      };

      final protocols = loadProgrammeProtocolsSafely(
        store,
        const ['bad-proto', 'good-proto'],
      );

      expect(protocols, hasLength(2));
      final bad = protocols.firstWhere((p) => p.protocolId == 'bad-proto');
      final good = protocols.firstWhere((p) => p.protocolId == 'good-proto');

      expect(bad.primarySessionIntent, isNull);
      expect(bad.secondarySessionIntents, [SessionIntent.lowerBodyStrength]);
      expect(good.primarySessionIntent, SessionIntent.threshold);
    });
  });
}
