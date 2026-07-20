import '../../models/block_performance_capture_mode.dart';
import '../../models/protocol_draft.dart';
import '../../models/session_block.dart';
import '../../models/session_block_exercise_link.dart';
import '../../models/session_block_type.dart';
import '../../models/timer_configuration.dart';
import '../../models/training_content_vocabulary.dart';
import '../../models/workout_format.dart';
import '../session/models/session_execution_plan.dart';
import '../session/services/athlete_exercise_label_resolver.dart';

/// Canonical founder acceptance session and programme content (M8.1.1).
///
/// Single source of truth consumed by automated tests and developer install tooling.
class FounderAcceptanceContent {
  FounderAcceptanceContent._();

  static const protocolId = 'm8-modern-capture-test';
  static const sessionTitle = 'M8 Modern Capture Test';
  static const programmeLineageCode = 'FOUNDER-ACCEPTANCE-PROGRAMME';
  static const programmeSlug = 'founder-acceptance-programme';
  static const programmeName = 'Founder Acceptance Programme';
  static const programmeDescription =
      'Developer-only programme for repeatable founder acceptance testing.';

  /// Stable founder-owned exercise labels keyed by canonical exercise ID.
  static const exerciseDisplayNames = {
    'SQ-001': 'Back Squat',
    'BP-001': 'Bench Press',
  };

  static String exerciseDisplayName(String exerciseId) {
    return exerciseDisplayNames[exerciseId] ?? exerciseId;
  }

  static SessionBlockExerciseLink linkedExercise({
    required String localId,
    required String exerciseId,
    required int position,
  }) {
    return SessionBlockExerciseLink(
      localId: localId,
      exerciseId: exerciseId,
      position: position,
      displayLabelOverride: exerciseDisplayNames[exerciseId],
    );
  }

  static List<SessionBlock> sessionBlocks({bool singleBlock = false}) {
    final blocks = _allBlocks();
    if (singleBlock) {
      return [blocks.first];
    }
    return blocks;
  }

  static ProtocolDraft protocolDraft({required String programmeVersionId}) {
    return ProtocolDraft(
      protocolId: protocolId,
      name: sessionTitle,
      sessionFormat: 'structured_strength',
      steps: const [],
      blocks: sessionBlocks(),
      published: false,
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: programmeVersionId,
      ownerId: 'dev-coach',
      durationMin: 75,
      purpose: 'Founder acceptance capture-mode regression session.',
    );
  }

  static SessionExecutionPlan executionPlan({bool singleBlock = false}) {
    return SessionExecutionPlan(
      sessionId: protocolId,
      sessionTitle: sessionTitle,
      blocks: sessionBlocks(singleBlock: singleBlock)
          .map(executionBlockFrom)
          .toList(growable: false),
    );
  }

  static SessionExecutionBlock executionBlockFrom(SessionBlock block) {
    return SessionExecutionBlock(
      blockId: block.localId,
      title: block.title,
      blockType: block.blockType,
      content: block.content,
      workoutFormat: block.workoutFormat,
      position: block.position,
      timerConfiguration: block.timerConfiguration,
      timerSummary: block.timerConfiguration == null ||
              block.workoutFormat == WorkoutFormat.none
          ? null
          : block.timerConfiguration!.summaryForFormat(block.workoutFormat),
      linkedExercises: block.linkedExercises
          .map(
            (link) => SessionExecutionExerciseSummary(
              exerciseId: link.exerciseId,
              displayName: AthleteExerciseLabelResolver.fromExerciseLink(
                link: link,
              ),
              displayLabelOverride: link.displayLabelOverride,
            ),
          )
          .toList(growable: false),
      performanceCaptureMode: block.performanceCaptureMode,
    );
  }

  static List<SessionBlock> _allBlocks() {
    return [
      SessionBlock(
        localId: 'block-warmup',
        blockType: SessionBlockType.warmUp,
        title: 'Warm-up',
        content: 'Easy row and mobility',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
      ),
      SessionBlock(
        localId: 'block-strength',
        blockType: SessionBlockType.strength,
        title: 'Strength',
        content: 'Back squat and bench press',
        workoutFormat: WorkoutFormat.none,
        position: 2,
        performanceCaptureMode: BlockPerformanceCaptureMode.strength,
        linkedExercises: [
          linkedExercise(
            localId: 'link-squat',
            exerciseId: 'SQ-001',
            position: 1,
          ),
          linkedExercise(
            localId: 'link-bench',
            exerciseId: 'BP-001',
            position: 2,
          ),
        ],
      ),
      SessionBlock(
        localId: 'block-run',
        blockType: SessionBlockType.conditioning,
        title: 'Threshold Run',
        content: '30 min threshold pace',
        workoutFormat: WorkoutFormat.none,
        position: 3,
        performanceCaptureMode: BlockPerformanceCaptureMode.endurance,
      ),
      SessionBlock(
        localId: 'block-amrap',
        blockType: SessionBlockType.conditioning,
        title: 'AMRAP',
        content: '12 min AMRAP burpees',
        workoutFormat: WorkoutFormat.amrap,
        position: 4,
        timerConfiguration: const TimerConfiguration(durationSeconds: 720),
        performanceCaptureMode: BlockPerformanceCaptureMode.amrap,
      ),
      SessionBlock(
        localId: 'block-cooldown',
        blockType: SessionBlockType.coolDown,
        title: 'Cool-down',
        content: 'Easy spin',
        workoutFormat: WorkoutFormat.none,
        position: 5,
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
      ),
    ];
  }
}
