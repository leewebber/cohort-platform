import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/features/session/models/workout_session_launch_context.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/adaptation_application_test_support.dart';
import '../support/adaptation_planning_test_support.dart';

void main() {
  group('SessionExecutionController with WorkoutPlayer runtime', () {
    test('startSession activates player and marks in progress', () {
      final draft = buildTimedPlanningSession(protocolId: 'proto-player');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 65,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;

      final player = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
      ).player!;

      final plan = _planMatchingSnapshot(snapshot);
      final launchContext = WorkoutSessionLaunchContext(
        occurrence: _fakeOccurrence('occ-1', snapshot),
        executionSnapshot: snapshot,
        legacyProtocolId: 'proto-player',
        workoutPlayer: player,
      );

      final controller = SessionExecutionController(
        plan: plan,
        sessionKey: '99:proto-player',
        memoryStore: AthleteSessionMemoryStore.instance,
        workoutLaunchContext: launchContext,
      );

      controller.startSession();

      expect(controller.state.sessionStatus, SessionExecutionStatus.inProgress);
      expect(
        controller.workoutPlayer?.executionStatus,
        WorkoutPlayerExecutionStatus.active,
      );
    });

    test('markBlockComplete advances via WorkoutPlayer.nextBlock', () {
      final draft = buildTimedPlanningSession(protocolId: 'proto-player');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 65,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;

      final player = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
      ).player!;

      final plan = _planMatchingSnapshot(snapshot);
      final launchContext = WorkoutSessionLaunchContext(
        occurrence: _fakeOccurrence('occ-1', snapshot),
        executionSnapshot: snapshot,
        legacyProtocolId: 'proto-player',
        workoutPlayer: player,
      );

      final controller = SessionExecutionController(
        plan: plan,
        sessionKey: '100:proto-player',
        memoryStore: AthleteSessionMemoryStore.instance,
        workoutLaunchContext: launchContext,
      )..startSession();

      final firstId = plan.blocks.first.blockId;
      controller.markBlockComplete(firstId);

      expect(controller.state.completedBlockIds, contains(firstId));
      expect(controller.state.activeBlockIndex, greaterThan(0));
    });

    test('applyDomainCompletionProjection syncs finished player for UI', () {
      final draft = buildTimedPlanningSession(protocolId: 'proto-player');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 65,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;

      final player = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
      ).player!;

      final plan = _planMatchingSnapshot(snapshot);
      final launchContext = WorkoutSessionLaunchContext(
        occurrence: _fakeOccurrence('occ-1', snapshot),
        executionSnapshot: snapshot,
        legacyProtocolId: 'proto-player',
        workoutPlayer: player,
      );

      final controller = SessionExecutionController(
        plan: plan,
        sessionKey: '101:proto-player',
        memoryStore: AthleteSessionMemoryStore.instance,
        workoutLaunchContext: launchContext,
      )..startSession();

      final finishedAt = DateTime.utc(2026, 2, 1, 12);
      controller.applyDomainCompletionProjection(finishedAt: finishedAt);

      expect(controller.state.sessionStatus, SessionExecutionStatus.completed);
      expect(
        controller.workoutPlayer?.executionStatus,
        WorkoutPlayerExecutionStatus.completed,
      );
      expect(controller.workoutPlayer?.finishedAt, finishedAt);
    });
  });
}

SessionExecutionPlan _planMatchingSnapshot(
  AdaptedSessionExecutionSnapshot snapshot,
) {
  final blocks = snapshot.retainedBlocks
      .map(
        (block) => SessionExecutionBlock(
          blockId: block.sourceBlockLocalId,
          title: block.blockTypeDbValue,
          blockType: SessionBlockType.strength,
          content: 'Block',
          workoutFormat: WorkoutFormat.none,
          position: block.sourcePosition,
          linkedExercises: block.exercises
              .map(
                (e) => SessionExecutionExerciseSummary(
                  exerciseId: e.exerciseId,
                  displayName: e.exerciseId,
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);

  return SessionExecutionPlan(
    sessionId: snapshot.sourceProtocolId,
    sessionTitle: 'Test',
    blocks: blocks,
  );
}

SessionOccurrence _fakeOccurrence(
  String id,
  AdaptedSessionExecutionSnapshot snapshot,
) {
  final date = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 1, 1));
  return SessionOccurrence(
    occurrenceId: id,
    sourceSessionId: snapshot.sourceProtocolId,
    originalPlannedDate: date,
    plannedDate: date,
    currentDate: date,
    lifecycleState: SessionOccurrenceLifecycleState.inProgress,
    completionStatus: SessionOccurrenceCompletionStatus.pending,
    rescheduleHistory: const [],
    auditTrail: const [],
    executionSnapshot: snapshot,
  );
}
