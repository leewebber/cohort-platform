import 'package:cohort_platform/features/founder_acceptance/founder_acceptance_content.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/data/repositories/exercise_repository.dart';
import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/athlete_exercise_label_resolver.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/session_builder/services/protocol_draft_block_resolver.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_session_block_repository.dart';

void main() {
  group('SessionExecutionExerciseSummary projection', () {
    test('preserves displayLabelOverride from link', () {
      const link = SessionBlockExerciseLink(
        localId: 'link-1',
        exerciseId: 'SQ-001',
        position: 1,
        displayLabelOverride: 'Back Squat',
      );

      final summary = SessionExecutionBlock.fromSessionBlock(
        SessionBlock(
          localId: 'block-1',
          blockType: SessionBlockType.strength,
          title: 'Strength',
          content: 'Squat work',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          linkedExercises: const [link],
        ),
        exercisesById: const {},
      ).linkedExercises.single;

      expect(summary.displayLabelOverride, 'Back Squat');
      expect(summary.displayName, 'Back Squat');
      expect(summary.athleteLabel, 'Back Squat');
    });

    test('override wins over ID-equal displayName', () {
      const summary = SessionExecutionExerciseSummary(
        exerciseId: 'SQ-001',
        displayName: 'SQ-001',
        displayLabelOverride: 'Back Squat',
      );

      expect(summary.athleteLabel, 'Back Squat');
    });

    test('usable displayName works without override', () {
      const summary = SessionExecutionExerciseSummary(
        exerciseId: 'SQ-001',
        displayName: 'Back Squat',
      );

      expect(summary.displayLabelOverride, isNull);
      expect(summary.athleteLabel, 'Back Squat');
    });

    test('live exercise name resolves when override and displayName missing', () {
      const summary = SessionExecutionExerciseSummary(
        exerciseId: 'SQ-001',
        displayName: 'SQ-001',
        exercise: Exercise(
          exerciseId: 'SQ-001',
          name: 'Back Squat',
          published: true,
        ),
      );

      expect(summary.athleteLabel, 'Back Squat');
    });

    test('missing name falls back to exerciseId', () {
      const summary = SessionExecutionExerciseSummary(
        exerciseId: 'UNKNOWN-001',
        displayName: 'UNKNOWN-001',
      );

      expect(summary.athleteLabel, 'UNKNOWN-001');
    });
  });

  group('Founder content persist reload integration', () {
    late InMemorySessionBlockRepository blockRepository;

    setUp(() {
      blockRepository = InMemorySessionBlockRepository();
    });

    Future<SessionExecutionPlan> loadFounderPlan() {
      final loader = SessionExecutionLoader(
        sessionBlockRepository: blockRepository,
        protocolRepository: _FixedProtocolRepository(
          Protocol(
            protocolId: FounderAcceptanceContent.protocolId,
            name: FounderAcceptanceContent.sessionTitle,
          ),
        ),
        exerciseRepository: _EmptyExerciseRepository(),
      );

      return loader
          .load(protocolId: FounderAcceptanceContent.protocolId)
          .then((result) => result.plan);
    }

    Future<void> persistFounderBlocks() async {
      const resolver = ProtocolDraftBlockResolver();
      final draft = FounderAcceptanceContent.protocolDraft(
        programmeVersionId: 'founder-version',
      );
      await blockRepository.replaceSessionBlocks(
        sessionId: draft.protocolId,
        blocks: resolver.resolveBlocks(draft),
      );
    }

    test('round-trip persists display_label_override rows', () async {
      await persistFounderBlocks();

      final rows = blockRepository.exerciseRowsForSession(
        FounderAcceptanceContent.protocolId,
      );
      expect(rows, hasLength(2));
      expect(rows[0]['display_label_override'], 'Back Squat');
      expect(rows[1]['display_label_override'], 'Bench Press');
      expect(rows[0]['exercise_id'], 'SQ-001');
      expect(rows[1]['exercise_id'], 'BP-001');
    });

    test('SessionExecutionLoader reload resolves athlete labels', () async {
      await persistFounderBlocks();

      final plan = await loadFounderPlan();
      final strength =
          plan.blocks.firstWhere((block) => block.title == 'Strength');

      expect(strength.linkedExercises[0].displayLabelOverride, 'Back Squat');
      expect(strength.linkedExercises[1].displayLabelOverride, 'Bench Press');
      expect(strength.linkedExercises[0].athleteLabel, 'Back Squat');
      expect(strength.linkedExercises[1].athleteLabel, 'Bench Press');
    });

    test('performance drafts store readable labels and overrides', () async {
      await persistFounderBlocks();
      final plan = await loadFounderPlan();

      final drafts =
          const PerformanceSnapshotBuilder().buildInitialBlockDrafts(plan);
      final strengthDraft = drafts.firstWhere(
        (draft) => draft.captureMode == BlockCaptureMode.strength,
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

    test('reinstall updates stale null override rows without duplicates',
        () async {
      await blockRepository.replaceSessionBlocks(
        sessionId: FounderAcceptanceContent.protocolId,
        blocks: [
          SessionBlock(
            localId: 'block-strength',
            blockType: SessionBlockType.strength,
            title: 'Strength',
            content: 'Back squat and bench press',
            workoutFormat: WorkoutFormat.none,
            position: 2,
            linkedExercises: const [
              SessionBlockExerciseLink(
                localId: 'stale-link-1',
                exerciseId: 'SQ-001',
                position: 1,
              ),
              SessionBlockExerciseLink(
                localId: 'stale-link-2',
                exerciseId: 'BP-001',
                position: 2,
              ),
            ],
          ),
        ],
      );

      expect(
        blockRepository.exerciseRowsForSession(
          FounderAcceptanceContent.protocolId,
        ).map((row) => row['display_label_override']),
        everyElement(isNull),
      );

      await persistFounderBlocks();

      final rows = blockRepository.exerciseRowsForSession(
        FounderAcceptanceContent.protocolId,
      );
      expect(rows, hasLength(2));
      expect(rows.map((row) => row['display_label_override']),
          ['Back Squat', 'Bench Press']);

      final plan = await loadFounderPlan();
      final strength =
          plan.blocks.firstWhere((block) => block.title == 'Strength');
      expect(strength.linkedExercises[0].athleteLabel, 'Back Squat');
      expect(strength.linkedExercises[1].athleteLabel, 'Bench Press');
    });

    test('historical snapshot label remains stable without live exercise lookup',
        () {
      const snapshot = ExercisePerformanceSnapshot(
        sourceExerciseId: 'SQ-001',
        displayName: 'Back Squat',
        labelOverride: 'Back Squat',
        position: 1,
      );

      expect(
        AthleteExerciseLabelResolver.fromSnapshot(
          snapshot,
          historical: true,
        ),
        'Back Squat',
      );
      expect(
        AthleteExerciseLabelResolver.fromSnapshot(
          snapshot,
          historical: true,
        ),
        isNot('Low Bar Back Squat'),
      );
    });
  });
}

class _EmptyExerciseRepository extends ExerciseRepository {
  @override
  Future<Exercise?> getExerciseById(String exerciseId) async => null;
}

class _FixedProtocolRepository extends ProtocolRepository {
  _FixedProtocolRepository(this._protocol);

  final Protocol _protocol;

  @override
  Future<Protocol?> getProtocolById(String protocolId) async {
    return protocolId == _protocol.protocolId ? _protocol : null;
  }
}
