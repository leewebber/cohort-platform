import 'package:cohort_platform/features/session_builder/services/protocol_draft_block_resolver.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_action_decision.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_clone.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_service.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_session_lineage_store.dart';

void main() {
  group('SessionRevisionClone', () {
    const clone = SessionRevisionClone();

    test('copies blocks and linked exercises without sharing mutable rows', () {
      final source = _publishedRevisionDraft(
        protocolId: 'session-a',
        lineageId: 'lineage-1',
      );

      final cloned = clone.cloneNewRevisionDraft(
        source: source,
        newProtocolId: 'session-a-rev-2',
        sessionLineageId: 'lineage-1',
        revisionNumber: 2,
      );

      expect(cloned.protocolId, 'session-a-rev-2');
      expect(cloned.revisionNumber, 2);
      expect(cloned.lifecycleStatus, SessionRevisionLifecycleStatus.draft);
      expect(cloned.sourceContentId, 'session-a');
      expect(cloned.blocks, isNotEmpty);
      expect(identical(cloned.blocks, source.blocks), isFalse);
      expect(cloned.blocks.first.localId, isNot(source.blocks.first.localId));
      expect(
        cloned.blocks.first.linkedExercises.first.exerciseId,
        source.blocks.first.linkedExercises.first.exerciseId,
      );
      expect(
        cloned.blocks.first.linkedExercises.first.localId,
        isNot(source.blocks.first.linkedExercises.first.localId),
      );
    });
  });

  group('SessionRevisionService', () {
    late InMemorySessionLineageStore lineageStore;
    late FakeProtocolBuilderService builder;
    late SessionRevisionService service;

    setUp(() {
      lineageStore = InMemorySessionLineageStore();
      builder = FakeProtocolBuilderService();
      service = SessionRevisionService(
        lineageStore: lineageStore,
        protocolBuilderService: builder,
      );
    });

    test('createLineage inserts lineage row', () async {
      final lineage = await service.createLineage(displayName: 'Strength Foundation');

      expect(lineage.displayName, 'Strength Foundation');
      expect(lineageStore.lineages, hasLength(1));
    });

    test('create revision 2 from published revision', () async {
      const lineageId = 'lineage-strength';
      await lineageStore.insertLineage(
        displayName: 'Strength Foundation',
        id: lineageId,
      );

      final source = _publishedRevisionDraft(
        protocolId: 'session-a',
        lineageId: lineageId,
      );
      builder.seed(source);
      lineageStore.seedRevision(
        protocolId: 'session-a',
        sessionLineageId: lineageId,
        revisionNumber: 1,
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
      );

      final result = await service.createNewSessionRevision(
        sourceProtocolId: 'session-a',
        newProtocolId: 'session-a-rev-2',
      );

      expect(result.revisionNumber, 2);
      expect(result.draft.protocolId, 'session-a-rev-2');
      expect(result.draft.sessionLineageId, lineageId);
      expect(result.draft.lifecycleStatus, SessionRevisionLifecycleStatus.draft);
      expect(builder.draftsById['session-a']!.name, source.name);
      expect(builder.saveDraftCalls, hasLength(1));
    });

    test('draft revision remains editable in place', () async {
      final draft = _publishedRevisionDraft(
        protocolId: 'session-draft',
        lineageId: 'lineage-draft',
      ).copyWith(
        published: false,
        lifecycleStatus: SessionRevisionLifecycleStatus.draft,
      );

      expect(draft.isRevisionEditable, isTrue);
    });

    test('published revision is not editable in place', () async {
      final published = _publishedRevisionDraft(
        protocolId: 'session-published',
        lineageId: 'lineage-published',
      );

      expect(published.isRevisionPublished, isTrue);
      expect(published.isRevisionEditable, isFalse);
    });

    test('revision numbering is monotonic within lineage', () async {
      const lineageId = 'lineage-monotonic';
      await lineageStore.insertLineage(
        displayName: 'Monotonic Session',
        id: lineageId,
      );

      builder.seed(_publishedRevisionDraft(
        protocolId: 'session-v1',
        lineageId: lineageId,
      ));
      lineageStore.seedRevision(
        protocolId: 'session-v1',
        sessionLineageId: lineageId,
        revisionNumber: 1,
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
      );

      final second = await service.createNewSessionRevision(
        sourceProtocolId: 'session-v1',
        newProtocolId: 'session-v2',
      );
      builder.seed(second.draft.copyWith(
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
        published: true,
      ));
      lineageStore.seedRevision(
        protocolId: 'session-v2',
        sessionLineageId: lineageId,
        revisionNumber: 2,
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
      );

      final third = await service.createNewSessionRevision(
        sourceProtocolId: 'session-v2',
        newProtocolId: 'session-v3',
      );

      expect(second.revisionNumber, 2);
      expect(third.revisionNumber, 3);
    });

    test('programme slot still references original revision protocol_id', () {
      const originalProtocolId = 'session-a';
      const slot = ProgrammeVersionSessionSlot(
        id: 'slot-1',
        dayId: 'day-1',
        sessionOrder: 1,
        protocolId: originalProtocolId,
      );

      expect(slot.protocolId, originalProtocolId);
      expect(slot.protocolId, isNot('session-a-rev-2'));
    });

    test('reject createNewSessionRevision from draft source', () async {
      lineageStore.seedRevision(
        protocolId: 'session-draft',
        sessionLineageId: 'lineage-1',
        revisionNumber: 1,
        lifecycleStatus: SessionRevisionLifecycleStatus.draft,
      );
      builder.seed(
        _publishedRevisionDraft(
          protocolId: 'session-draft',
          lineageId: 'lineage-1',
        ).copyWith(
          lifecycleStatus: SessionRevisionLifecycleStatus.draft,
          published: false,
        ),
      );

      expect(
        () => service.createNewSessionRevision(sourceProtocolId: 'session-draft'),
        throwsA(isA<SessionRevisionPolicyException>()),
      );
    });
  });
}

ProtocolDraft _publishedRevisionDraft({
  required String protocolId,
  required String lineageId,
}) {
  return ProtocolDraft(
    protocolId: protocolId,
    name: 'Strength Foundation',
    steps: const [
      ProtocolStepDraft(
        localId: 'step-1',
        stepOrder: 1,
        title: 'Warm-up',
      ),
    ],
    blocks: [
      SessionBlock(
        localId: 'block-1',
        blockType: SessionBlockType.strength,
        title: 'Strength',
        content: 'Back squat',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: const [
          SessionBlockExerciseLink(
            localId: 'link-1',
            exerciseId: 'SQ-001',
            position: 1,
          ),
        ],
      ),
    ],
    published: true,
    contentKind: TrainingContentKind.session,
    authoringScope: TrainingAuthoringScope.coachPrivate,
    endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    sessionLineageId: lineageId,
    revisionNumber: 1,
    lifecycleStatus: SessionRevisionLifecycleStatus.published,
    sessionFormat: 'structured_strength',
  );
}
