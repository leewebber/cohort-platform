import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

import '../models/active_session_state.dart';
import '../models/session_execution_plan.dart';
import '../models/session_execution_status.dart';

/// Projects [WorkoutPlayer] runtime into legacy [ActiveSessionState] for M7 UI.
class WorkoutPlayerActiveSessionProjection {
  const WorkoutPlayerActiveSessionProjection._();

  static ActiveSessionState project({
    required String sessionKey,
    required SessionExecutionPlan plan,
    required WorkoutPlayer player,
    required Set<String> completedBlockIds,
    required Set<String> expandedBlockIds,
  }) {
    final activeBlockIndex = _activeBlockIndex(plan: plan, player: player);
    final blockStates = <BlockExecutionState>[];
    for (var i = 0; i < plan.blocks.length; i++) {
      final block = plan.blocks[i];
      blockStates.add(
        BlockExecutionState(
          blockId: block.blockId,
          status: _blockStatus(
            blockId: block.blockId,
            blockIndex: i,
            activeBlockIndex: activeBlockIndex,
            completedBlockIds: completedBlockIds,
          ),
        ),
      );
    }

    return ActiveSessionState(
      sessionKey: sessionKey,
      plan: plan,
      blockStates: blockStates,
      activeBlockIndex: activeBlockIndex,
      completedBlockIds: Set<String>.from(completedBlockIds),
      expandedBlockIds: () {
        final expanded = Set<String>.from(expandedBlockIds);
        if (player.executionStatus.allowsNavigation) {
          expanded.add(plan.blocks[activeBlockIndex].blockId);
        }
        return expanded;
      }(),
      sessionStatus: _sessionStatus(player),
      startedAt: player.startedAt,
      endedAt: player.finishedAt,
    );
  }

  static int _activeBlockIndex({
    required SessionExecutionPlan plan,
    required WorkoutPlayer player,
  }) {
    final localId = player.currentPosition.sourceBlockLocalId;
    final index = plan.blocks.indexWhere((block) => block.blockId == localId);
    if (index >= 0) return index;

    for (var i = 0; i < plan.blocks.length; i++) {
      if (plan.blocks[i].hasAthleteVisibleContent) return i;
    }
    return 0;
  }

  static BlockExecutionStatus _blockStatus({
    required String blockId,
    required int blockIndex,
    required int activeBlockIndex,
    required Set<String> completedBlockIds,
  }) {
    if (completedBlockIds.contains(blockId)) {
      return BlockExecutionStatus.complete;
    }
    if (blockIndex == activeBlockIndex) {
      return BlockExecutionStatus.active;
    }
    return BlockExecutionStatus.notStarted;
  }

  static SessionExecutionStatus _sessionStatus(WorkoutPlayer player) {
    return switch (player.executionStatus) {
      WorkoutPlayerExecutionStatus.ready => SessionExecutionStatus.notStarted,
      WorkoutPlayerExecutionStatus.active ||
      WorkoutPlayerExecutionStatus.paused => SessionExecutionStatus.inProgress,
      WorkoutPlayerExecutionStatus.completed =>
        SessionExecutionStatus.completed,
      WorkoutPlayerExecutionStatus.abandoned =>
        SessionExecutionStatus.abandoned,
    };
  }
}

/// Mutable overlay + player reference for a single active session.
class WorkoutPlayerSessionRuntime {
  WorkoutPlayerSessionRuntime({
    required this.plan,
    required WorkoutPlayer player,
    Set<String>? completedBlockIds,
    Set<String>? expandedBlockIds,
  }) : _player = player,
       completedBlockIds = Set<String>.from(completedBlockIds ?? {}),
       expandedBlockIds = Set<String>.from(expandedBlockIds ?? {});

  final SessionExecutionPlan plan;
  WorkoutPlayer _player;
  final Set<String> completedBlockIds;
  final Set<String> expandedBlockIds;

  WorkoutPlayer get player => _player;

  void replacePlayer(WorkoutPlayer player) {
    _player = player;
  }

  ActiveSessionState project(String sessionKey) {
    return WorkoutPlayerActiveSessionProjection.project(
      sessionKey: sessionKey,
      plan: plan,
      player: _player,
      completedBlockIds: completedBlockIds,
      expandedBlockIds: expandedBlockIds,
    );
  }

  bool applyTransition(WorkoutPlayerTransitionResult result) {
    if (!result.isSuccess || result.player == null) return false;
    _player = result.player!;
    return true;
  }

  int blockIndexFor(String blockId) {
    return plan.blocks.indexWhere((block) => block.blockId == blockId);
  }

  void syncPlayerToBlockIndex(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= plan.blocks.length) return;
    final blockId = plan.blocks[blockIndex].blockId;
    final stepIndex = WorkoutPlayerNavigation.indexOfBlock(
      snapshot: _player.executionSnapshot,
      sourceBlockLocalId: blockId,
    );
    if (stepIndex == null) return;
    applyTransition(_player.goToStepIndex(stepIndex));
  }
}
