import 'dart:io';

import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring_persistence.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_compiler.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/session_builder/services/programme_session_draft_factory.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_protocol_row_store.dart';
import '../support/in_memory_session_block_repository.dart';
import '../support/programme_code_authoring_fixtures.dart';
import '../support/programme_session_authoring_test_support.dart'
    hide FakeProtocolBuilderService;

/// Shared canonical tagging spec for code vs visual builder equivalence.
const _canonicalPrimary = SessionIntent.upperBodyStrength;
const _canonicalSecondaries = [SessionIntent.upperBodyHypertrophy];
const _canonicalMinDuration = 35;
const _explicitBlockPolicy = BlockAdaptationPolicy(
  canRemove: false,
  canShorten: false,
  canReduceVolume: true,
  canReduceIntensity: true,
  canIncreaseRest: true,
  canSuperset: false,
  canReplaceExercises: true,
  canReplaceBlock: false,
);

ProtocolDraft buildTaggedSessionViaCode({
  required String protocolId,
  required String programmeVersionId,
}) {
  return fullyTaggedUpperBodyStrengthSession(
    protocolId: protocolId,
    programmeVersionId: programmeVersionId,
  );
}

ProtocolDraft buildTaggedSessionViaVisualBuilder({
  required String protocolId,
  required String programmeVersionId,
}) {
  final context = ProgrammeSessionAuthoringContext(
    programmeVersionId: programmeVersionId,
    weekLocalId: testWeekLocalId,
    dayLocalId: testDayLocalId,
    slotLocalId: testSlotLocalId,
    weekNumber: 2,
    dayLabel: 'Tuesday',
    slotDisplayLabel: 'Morning',
    authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
  );

  final blank =
      ProgrammeSessionDraftFactory.createBlankProgrammeSessionDraft(
        context,
      ).copyWith(
        protocolId: protocolId,
        name: 'Upper Body Strength',
        sessionFormat: 'structured_strength',
        programmeVersionId: programmeVersionId,
      );

  final editing = SessionBuilderEditingState(draft: blank);
  editing.setPrimarySessionIntent(_canonicalPrimary);
  editing.setSecondarySessionIntents(_canonicalSecondaries);
  editing.setMinimumViableDurationMin(_canonicalMinDuration);
  editing.durationMin = 60;

  editing.blocks = [
    block(type: SessionBlockType.warmUp, content: 'Row and shoulder prep'),
    block(
      type: SessionBlockType.strength,
      title: 'Main strength',
      blockPriority: BlockPriority.essential,
      adaptationPolicy: _explicitBlockPolicy,
      linkedExercises: [exerciseLink(exerciseId: 'BP-001', position: 1)],
    ),
    block(
      type: SessionBlockType.accessory,
      blockPriority: BlockPriority.secondary,
    ),
  ];

  return editing.buildDraft();
}

void expectEquivalentCanonicalPersistence(
  ProtocolDraft code,
  ProtocolDraft builder,
) {
  final codeMap = InMemoryProtocolRowStore().buildUpsertMap(
    code,
    published: false,
  );
  final builderMap = InMemoryProtocolRowStore().buildUpsertMap(
    builder,
    published: false,
  );

  expect(
    builderMap[SessionAdaptationMetadataKeys.primarySessionIntent],
    codeMap[SessionAdaptationMetadataKeys.primarySessionIntent],
  );
  expect(
    builderMap[SessionAdaptationMetadataKeys.secondarySessionIntents],
    codeMap[SessionAdaptationMetadataKeys.secondarySessionIntents],
  );
  expect(
    builderMap[SessionAdaptationMetadataKeys.minimumViableDurationMin],
    codeMap[SessionAdaptationMetadataKeys.minimumViableDurationMin],
  );

  expect(builder.primarySessionIntent, code.primarySessionIntent);
  expect(builder.secondarySessionIntents, code.secondarySessionIntents);
  expect(builder.minimumViableDurationMin, code.minimumViableDurationMin);

  expect(builder.blocks.length, code.blocks.length);
  for (var i = 0; i < code.blocks.length; i++) {
    final a = code.blocks[i];
    final b = builder.blocks[i];
    expect(b.blockPriority, a.blockPriority);
    expect(b.adaptationPolicy?.toJson(), a.adaptationPolicy?.toJson());
    final aRow = a.toRowMap(sessionId: code.protocolId);
    final bRow = b.toRowMap(sessionId: builder.protocolId);
    expect(
      bRow.containsKey(SessionBlockAdaptationMetadataKeys.blockPriority),
      aRow.containsKey(SessionBlockAdaptationMetadataKeys.blockPriority),
    );
    expect(
      bRow.containsKey(SessionBlockAdaptationMetadataKeys.adaptationPolicy),
      aRow.containsKey(SessionBlockAdaptationMetadataKeys.adaptationPolicy),
    );
    if (aRow.containsKey(SessionBlockAdaptationMetadataKeys.blockPriority)) {
      expect(
        bRow[SessionBlockAdaptationMetadataKeys.blockPriority],
        aRow[SessionBlockAdaptationMetadataKeys.blockPriority],
      );
    }
  }
}

Future<ProtocolDraft> persistAndReload({
  required ProtocolDraft draft,
  required InMemoryProtocolRowStore protocolStore,
  required InMemorySessionBlockRepository blockRepo,
}) async {
  protocolStore.upsertFromDraft(draft);
  await blockRepo.replaceSessionBlocks(
    sessionId: draft.protocolId,
    blocks: draft.blocks,
  );
  return protocolStore.loadDraft(
    protocolId: draft.protocolId,
    blocks: await blockRepo.getSessionBlocks(draft.protocolId),
  );
}

void main() {
  group(
    'Milestone 2A Task 3 — code vs visual builder canonical equivalence',
    () {
      test('A/B same metadata produces equivalent persisted maps', () {
        const protocolId = 'm2a-equiv-1';
        final code = buildTaggedSessionViaCode(
          protocolId: protocolId,
          programmeVersionId: testProgrammeVersionId,
        );
        final visual = buildTaggedSessionViaVisualBuilder(
          protocolId: protocolId,
          programmeVersionId: testProgrammeVersionId,
        );

        expectEquivalentCanonicalPersistence(code, visual);
      });
    },
  );

  group(
    'Path A — code create → persist → reload → builder edit → duplicate',
    () {
      test('full code path with programme duplicate', () async {
        final protocolStore = InMemoryProtocolRowStore();
        final blockRepo = InMemorySessionBlockRepository();
        final builder = FakeProtocolBuilderService();
        final persistence = ProgrammeCodeAuthoringPersistence(builder);

        const protocolId = 'm2a-code-path-1';
        final created = buildTaggedSessionViaCode(
          protocolId: protocolId,
          programmeVersionId: testProgrammeVersionId,
        );

        await persistence.saveProgrammeSession(created);
        expect(builder.draftsById[protocolId], isNotNull);

        protocolStore.upsertFromDraft(created);
        await blockRepo.replaceSessionBlocks(
          sessionId: protocolId,
          blocks: created.blocks,
        );

        var reloaded = await persistAndReload(
          draft: created,
          protocolStore: protocolStore,
          blockRepo: blockRepo,
        );
        expect(reloaded.primarySessionIntent, _canonicalPrimary);

        final editing = SessionBuilderEditingState(draft: reloaded);
        editing.setPrimarySessionIntent(SessionIntent.pushStrength);
        editing.setMinimumViableDurationMin(40);
        final edited = editing.buildDraft();
        protocolStore.upsertFromDraft(edited);
        await blockRepo.replaceSessionBlocks(
          sessionId: protocolId,
          blocks: edited.blocks,
        );
        reloaded = protocolStore.loadDraft(
          protocolId: protocolId,
          blocks: await blockRepo.getSessionBlocks(protocolId),
        );
        expect(reloaded.primarySessionIntent, SessionIntent.pushStrength);
        expect(reloaded.minimumViableDurationMin, 40);

        const sourceVersionId = '44444444-4444-4444-4444-444444444444';
        protocolStore.upsertFromDraft(reloaded, published: false);

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
          ProgrammeLineage(id: 'lineage-m2a', code: 'M2A-CODE'),
        );
        tables.versions.add(
          ProgrammeVersion(
            id: sourceVersionId,
            lineageId: 'lineage-m2a',
            versionNumber: 1,
            lifecycleStatus: ProgrammeLifecycleStatus.published,
            libraryScope: ProgrammeLibraryScope.coachPrivate,
            ownerType: ProgrammeOwnerType.coach,
            ownerId: 'dev-coach',
            name: 'Source',
          ),
        );

        final sourceDocument = ProgrammeBuilderDocument.clean(
          metadata: ProgrammeVersionDraftMetadata(
            versionId: sourceVersionId,
            lineageId: 'lineage-m2a',
            lineageCode: 'M2A-CODE',
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
          coachId: 'dev-coach',
          newLineageCode: 'M2A-CODE-DUP',
          newProgrammeName: 'Duplicate',
        );

        expect(
          duplicateResult.status,
          ProgrammeBuilderOperationStatus.duplicated,
        );
        final dupProtocolId = duplicateResult
            .document!
            .template
            .allWeeks
            .first
            .days
            .first
            .slots
            .first
            .protocolId;
        expect(dupProtocolId, protocolId);

        final dupReload = protocolStore.loadDraft(
          protocolId: dupProtocolId,
          blocks: await blockRepo.getSessionBlocks(dupProtocolId),
        );
        expect(dupReload.primarySessionIntent, SessionIntent.pushStrength);
      });
    },
  );

  group('Path B — builder create → persist → clone → attach', () {
    test(
      'visual builder draft through persist, clone, and slot reference',
      () async {
        final protocolStore = InMemoryProtocolRowStore();
        final blockRepo = InMemorySessionBlockRepository();
        const cloneService = SessionCloneService();

        const protocolId = 'm2a-builder-path-1';
        final created = buildTaggedSessionViaVisualBuilder(
          protocolId: protocolId,
          programmeVersionId: testProgrammeVersionId,
        );

        final reloaded = await persistAndReload(
          draft: created,
          protocolStore: protocolStore,
          blockRepo: blockRepo,
        );
        expect(reloaded.primarySessionIntent, _canonicalPrimary);

        final cloned = cloneService.cloneCohortProtocolToSession(
          source: reloaded.copyWith(
            contentKind: TrainingContentKind.cohortProtocol,
            authoringScope: TrainingAuthoringScope.cohortGlobal,
            endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
            published: true,
          ),
          newContentId: 'm2a-cloned-library-1',
          ownerId: 'dev-coach',
          destination: CohortProtocolCopyDestination.sessionLibrary,
        );

        expect(cloned.primarySessionIntent, _canonicalPrimary);
        expect(cloned.minimumViableDurationMin, _canonicalMinDuration);
        expect(cloned.blocks[1].blockPriority, BlockPriority.essential);

        protocolStore.upsertFromDraft(cloned);
        await blockRepo.replaceSessionBlocks(
          sessionId: cloned.protocolId,
          blocks: cloned.blocks,
        );

        const targetProgrammeVersionId = '55555555-5555-5555-5555-555555555555';
        final attachedSlot = ProgrammeSessionSlotDraft(
          localId: 'slot-target',
          sessionOrder: 1,
          protocolId: cloned.protocolId,
          displayTitle: cloned.name,
        );
        expect(attachedSlot.protocolId, cloned.protocolId);

        final attachedReload = protocolStore.loadDraft(
          protocolId: cloned.protocolId,
          blocks: await blockRepo.getSessionBlocks(cloned.protocolId),
        );
        expect(attachedReload.primarySessionIntent, _canonicalPrimary);
        expect(targetProgrammeVersionId, isNotEmpty);
      },
    );
  });

  group('Backward compatibility and safe failure modes', () {
    test('legacy untagged programme session row loads', () {
      final store = InMemoryProtocolRowStore()
        ..rowsByProtocolId['legacy-prog-sess'] = {
          'protocol_id': 'legacy-prog-sess',
          'name': 'Legacy',
          'primary_capability': 'Strength',
          'duration_min': 45,
        };

      final draft = store.loadDraft(protocolId: 'legacy-prog-sess');
      expect(draft.primaryCapability, 'Strength');
      expect(draft.primarySessionIntent, isNull);
    });

    test('legacy protocol Protocol.fromMap loads without adaptation keys', () {
      final protocol = Protocol.fromMap({
        'protocol_id': 'legacy-proto',
        'name': 'Legacy',
        'primary_capability': 'Threshold',
      });
      expect(protocol.primarySessionIntent, isNull);
      expect(protocol.goal, 'Threshold');
    });

    test('derived block defaults are not persisted', () {
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
      expect(block.effectiveBlockPriority, isNotNull);
    });

    test('explicit overrides persist in row maps', () {
      final block =
          SessionBlock.create(
            blockType: SessionBlockType.strength,
            position: 1,
          ).copyWith(
            blockPriority: BlockPriority.essential,
            adaptationPolicy: _explicitBlockPolicy,
          );
      final row = block.toRowMap(sessionId: 'sess-1');
      expect(
        row[SessionBlockAdaptationMetadataKeys.blockPriority],
        'essential',
      );
      expect(row[SessionBlockAdaptationMetadataKeys.adaptationPolicy], isMap);
    });

    test('unknown session intent values fail safely on load', () {
      final store = InMemoryProtocolRowStore()
        ..rowsByProtocolId['bad-intent'] = {
          'protocol_id': 'bad-intent',
          'name': 'Bad',
          SessionAdaptationMetadataKeys.primarySessionIntent: 'not_real',
          SessionAdaptationMetadataKeys.secondarySessionIntents: [
            'upper_body_strength',
            'bogus',
          ],
        };

      final draft = store.loadDraft(protocolId: 'bad-intent');
      expect(draft.primarySessionIntent, isNull);
      expect(draft.secondarySessionIntents, [SessionIntent.upperBodyStrength]);
    });
  });

  group('Athlete home and adaptation engine scope guard', () {
    test(
      'home_screen.dart has no M2A authoring or protocol recommendation hooks',
      () {
        final source = File(
          'lib/features/home/home_screen.dart',
        ).readAsStringSync();
        expect(
          source.contains('AdaptationMetadataCompletenessScreen'),
          isFalse,
        );
        expect(source.contains('primarySessionIntent'), isFalse);
        expect(source.contains('recommendProtocol'), isFalse);
        expect(source.contains('ProtocolRecommendation'), isFalse);
      },
    );

    test('adaptation_candidate_filter is not imported by home_screen', () {
      final source = File(
        'lib/features/home/home_screen.dart',
      ).readAsStringSync();
      expect(source.contains('adaptation_candidate_filter'), isFalse);
    });
  });
}
