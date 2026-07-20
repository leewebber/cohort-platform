import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_installer.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/services/athlete_exercise_label_resolver.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/session_builder/services/protocol_draft_block_resolver.dart';
import 'package:cohort_platform/features/session_builder/services/session_execution_plan_builder.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/data/repositories/exercise_repository.dart';
import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_session_block_repository.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/programme_session_authoring_test_support.dart';

void main() {
  group('FounderAcceptanceContent exercise labels', () {
    test('linked exercises carry canonical displayLabelOverride', () {
      final strength = FounderAcceptanceContent.sessionBlocks().firstWhere(
        (block) => block.title == 'Strength',
      );

      expect(strength.linkedExercises, hasLength(2));
      expect(
        strength.linkedExercises[0].displayLabelOverride,
        'Back Squat',
      );
      expect(
        strength.linkedExercises[1].displayLabelOverride,
        'Bench Press',
      );
    });

    test('execution plan resolves labels without exercise catalogue', () async {
      final blockRepository = InMemorySessionBlockRepository();
      final draft = FounderAcceptanceContent.protocolDraft(
        programmeVersionId: 'founder-version',
      );
      await blockRepository.replaceSessionBlocks(
        sessionId: draft.protocolId,
        blocks: const ProtocolDraftBlockResolver().resolveBlocks(draft),
      );

      final plan = await SessionExecutionLoader(
        sessionBlockRepository: blockRepository,
        protocolRepository: _FounderProtocolRepository(),
        exerciseRepository: _EmptyExerciseRepository(),
      ).load(protocolId: FounderAcceptanceContent.protocolId).then(
            (result) => result.plan,
          );

      final strength =
          plan.blocks.firstWhere((block) => block.title == 'Strength');
      expect(strength.linkedExercises[0].displayLabelOverride, 'Back Squat');
      expect(strength.linkedExercises[0].athleteLabel, 'Back Squat');
      expect(strength.linkedExercises[1].displayLabelOverride, 'Bench Press');
      expect(strength.linkedExercises[1].athleteLabel, 'Bench Press');
    });

    test('performance snapshots store human-readable exercise names', () async {
      final blockRepository = InMemorySessionBlockRepository();
      final draft = FounderAcceptanceContent.protocolDraft(
        programmeVersionId: 'founder-version',
      );
      await blockRepository.replaceSessionBlocks(
        sessionId: draft.protocolId,
        blocks: const ProtocolDraftBlockResolver().resolveBlocks(draft),
      );
      final plan = await SessionExecutionLoader(
        sessionBlockRepository: blockRepository,
        protocolRepository: _FounderProtocolRepository(),
        exerciseRepository: _EmptyExerciseRepository(),
      ).load(protocolId: FounderAcceptanceContent.protocolId).then(
            (result) => result.plan,
          );

      final drafts =
          const PerformanceSnapshotBuilder().buildInitialBlockDrafts(plan);
      final strengthDraft = drafts.firstWhere(
        (draft) => draft.blockSnapshot.title == 'Strength',
      );

      expect(
        strengthDraft.exerciseResults[0].exerciseSnapshot.displayName,
        'Back Squat',
      );
      expect(
        strengthDraft.exerciseResults[0].exerciseSnapshot.labelOverride,
        'Back Squat',
      );
      expect(
        strengthDraft.exerciseResults[1].exerciseSnapshot.displayName,
        'Bench Press',
      );
      expect(
        strengthDraft.exerciseResults[1].exerciseSnapshot.labelOverride,
        'Bench Press',
      );
    });

    test('ID fallback still works when no display name exists', () {
      expect(
        AthleteExerciseLabelResolver.fromExerciseLink(
          link: const SessionBlockExerciseLink(
            localId: 'link-unknown',
            exerciseId: 'UNKNOWN-001',
            position: 1,
          ),
        ),
        'UNKNOWN-001',
      );
    });
  });

  group('FounderAcceptanceInstaller exercise labels', () {
    late InMemoryProgrammeVersionStore versionStore;
    late FakeProtocolBuilderService protocolService;
    late FounderAcceptanceInstaller installer;

    setUp(() {
      versionStore = InMemoryProgrammeVersionStore(InMemoryProgrammeTables());
      protocolService = FakeProtocolBuilderService();
      installer = FounderAcceptanceInstaller(
        protocolBuilderService: protocolService,
        versionStore: versionStore,
      );
    });

    SessionExecutionPlan installedExecutionPlan() {
      final draft = protocolService.drafts[FounderAcceptanceContent.protocolId]!;
      return const SessionExecutionPlanBuilder().build(
        sessionId: draft.protocolId,
        sessionTitle: draft.name,
        blocks: draft.blocks,
      );
    }

    test('install persists displayLabelOverride on strength links', () async {
      await installer.install();

      final draft = protocolService.drafts[FounderAcceptanceContent.protocolId]!;
      final strength = draft.blocks.firstWhere((block) => block.title == 'Strength');

      expect(
        strength.linkedExercises.map((link) => link.displayLabelOverride),
        ['Back Squat', 'Bench Press'],
      );

      final plan = installedExecutionPlan();
      final strengthBlock =
          plan.blocks.firstWhere((block) => block.title == 'Strength');
      expect(strengthBlock.linkedExercises[0].athleteLabel, 'Back Squat');
      expect(strengthBlock.linkedExercises[1].athleteLabel, 'Bench Press');
    });

    test('reinstall keeps labels and does not duplicate content', () async {
      await installer.install();
      await installer.install();

      expect(protocolService.saveCallCount, 2);
      expect(
        protocolService.drafts[FounderAcceptanceContent.protocolId]!.blocks,
        hasLength(5),
      );

      final strength = installedExecutionPlan()
          .blocks
          .firstWhere((block) => block.title == 'Strength');
      expect(strength.linkedExercises, hasLength(2));
      expect(strength.linkedExercises[0].athleteLabel, 'Back Squat');
      expect(strength.linkedExercises[1].athleteLabel, 'Bench Press');
    });
  });

  group('Founder active session athlete labels', () {
    testWidgets('exercise list hides internal IDs', (tester) async {
      final blockRepository = InMemorySessionBlockRepository();
      final draft = FounderAcceptanceContent.protocolDraft(
        programmeVersionId: 'founder-version',
      );
      await blockRepository.replaceSessionBlocks(
        sessionId: draft.protocolId,
        blocks: const ProtocolDraftBlockResolver().resolveBlocks(draft),
      );
      final plan = await SessionExecutionLoader(
        sessionBlockRepository: blockRepository,
        protocolRepository: _FounderProtocolRepository(),
        exerciseRepository: _EmptyExerciseRepository(),
      ).load(protocolId: FounderAcceptanceContent.protocolId).then(
            (result) => result.plan,
          );

      final controller = SessionExecutionController(
        plan: plan,
        sessionKey: 'founder-labels:${plan.sessionId}:loader',
        memoryStore: AthleteSessionMemoryStore.instance,
      )..startSession();

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionScreen(
            controller: controller,
            performanceController:
                PerformanceCaptureController.initializeFromExecutionPlan(
              plan: plan,
              athleteId: 'founder-test-athlete',
              trainingSessionId: 9001,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next >'));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsWidgets);
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('SQ-001'), findsNothing);
      expect(find.text('BP-001'), findsNothing);
    });

    testWidgets('strength editor headings use display names', (tester) async {
      final blockRepository = InMemorySessionBlockRepository();
      final draft = FounderAcceptanceContent.protocolDraft(
        programmeVersionId: 'founder-version',
      );
      await blockRepository.replaceSessionBlocks(
        sessionId: draft.protocolId,
        blocks: const ProtocolDraftBlockResolver().resolveBlocks(draft),
      );
      final plan = await SessionExecutionLoader(
        sessionBlockRepository: blockRepository,
        protocolRepository: _FounderProtocolRepository(),
        exerciseRepository: _EmptyExerciseRepository(),
      ).load(protocolId: FounderAcceptanceContent.protocolId).then(
            (result) => result.plan,
          );

      final performanceController =
          PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan,
        athleteId: 'founder-test-athlete',
        trainingSessionId: 9001,
      );
      final strengthDraft = performanceController.draft.blockDrafts.firstWhere(
        (draft) => draft.captureMode == BlockCaptureMode.strength,
      );
      final strengthBlock =
          plan.blocks.firstWhere((block) => block.title == 'Strength');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockResultEditor(
              blockDraft: strengthDraft,
              linkedExercises: strengthBlock.linkedExercises,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, __, ___) {},
              onDuplicateSet: (_, __) {},
              onRemoveSet: (_, __) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('SQ-001'), findsNothing);
      expect(find.text('BP-001'), findsNothing);
    });
  });
}

class _EmptyExerciseRepository extends ExerciseRepository {
  @override
  Future<Exercise?> getExerciseById(String exerciseId) async => null;
}

class _FounderProtocolRepository extends ProtocolRepository {
  @override
  Future<Protocol?> getProtocolById(String protocolId) async {
    if (protocolId != FounderAcceptanceContent.protocolId) return null;
    return Protocol(
      protocolId: FounderAcceptanceContent.protocolId,
      name: FounderAcceptanceContent.sessionTitle,
    );
  }
}
