import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

import '../models/active_session_state.dart';
import '../models/session_execution_plan.dart';
import '../models/session_execution_status.dart';
import '../models/workout_session_launch_context.dart';
import '../adapters/workout_player_active_session_projection.dart';

/// Legacy M7 session UI adapter over [WorkoutPlayer] when [WorkoutSessionLaunchContext] is present.
///
/// Without launch context, behaviour is unchanged (plan-owned [ActiveSessionState]).
class SessionExecutionController {
  SessionExecutionController({
    required SessionExecutionPlan plan,
    required String sessionKey,
    AthleteSessionMemoryStore? memoryStore,
    ActiveSessionState? restoredState,
    WorkoutSessionLaunchContext? workoutLaunchContext,
  }) : _memoryStore = memoryStore ?? AthleteSessionMemoryStore.instance,
       _plan = plan,
       _sessionKey = sessionKey,
       _workoutLaunchContext = workoutLaunchContext {
    if (workoutLaunchContext != null) {
      _runtime = WorkoutPlayerSessionRuntime(
        plan: plan,
        player: workoutLaunchContext.workoutPlayer,
        completedBlockIds: restoredState?.completedBlockIds,
        expandedBlockIds: restoredState?.expandedBlockIds,
      );
      if (restoredState != null) {
        _runtime!.syncPlayerToBlockIndex(restoredState.activeBlockIndex);
      }
      _legacyState = _runtime!.project(sessionKey);
    } else {
      _runtime = null;
      _legacyState =
          restoredState ??
          _memoryStore.read(sessionKey) ??
          ActiveSessionState.initial(sessionKey: sessionKey, plan: plan);
    }
  }

  final WorkoutSessionLaunchContext? _workoutLaunchContext;
  final SessionExecutionPlan _plan;
  final String _sessionKey;
  final AthleteSessionMemoryStore _memoryStore;
  WorkoutPlayerSessionRuntime? _runtime;
  late ActiveSessionState _legacyState;

  WorkoutSessionLaunchContext? get workoutLaunchContext =>
      _workoutLaunchContext;

  /// Canonical runtime when launched from [WorkoutSessionLaunchContext].
  WorkoutPlayer? get workoutPlayer => _runtime?.player;

  ActiveSessionState get state {
    if (_runtime != null) {
      return _runtime!.project(_sessionKey);
    }
    return _legacyState;
  }

  void _persist() {
    _memoryStore.write(state);
  }

  void startSession() {
    if (_runtime != null) {
      final activated = _runtime!.player.activate(recordedAt: DateTime.now());
      if (_runtime!.applyTransition(activated)) {
        final activeId = state.activeBlock?.blockId;
        if (activeId != null) {
          _runtime!.expandedBlockIds.add(activeId);
        }
      }
      _persist();
      return;
    }

    _legacyState = _legacyState.copyWith(
      sessionStatus: SessionExecutionStatus.inProgress,
      startedAt: DateTime.now(),
      expandedBlockIds: {
        if (_legacyState.activeBlock?.blockId != null)
          _legacyState.activeBlock!.blockId,
      },
    );
    _persist();
  }

  void goToBlock(int index) {
    if (_runtime != null) {
      if (index < 0 || index >= _plan.blocks.length) return;
      _runtime!.syncPlayerToBlockIndex(index);
      _runtime!.expandedBlockIds.add(_plan.blocks[index].blockId);
      _persist();
      return;
    }

    if (index < 0 || index >= _legacyState.plan.blocks.length) return;
    final blockId = _legacyState.plan.blocks[index].blockId;
    _legacyState = _legacyState.copyWith(
      activeBlockIndex: index,
      expandedBlockIds: {blockId},
      sessionStatus: SessionExecutionStatus.inProgress,
    );
    _persist();
  }

  void goToNextBlock() {
    if (_runtime != null) {
      final moved = _runtime!.player.nextBlock();
      if (_runtime!.applyTransition(moved)) {
        final activeId = state.activeBlock?.blockId;
        if (activeId != null) {
          _runtime!.expandedBlockIds.add(activeId);
        }
      }
      _persist();
      return;
    }
    goToBlock(_legacyState.activeBlockIndex + 1);
  }

  void goToPreviousBlock() {
    goToBlock(state.activeBlockIndex - 1);
  }

  void toggleBlockExpanded(String blockId) {
    if (_runtime != null) {
      final expanded = _runtime!.expandedBlockIds;
      if (expanded.contains(blockId)) {
        expanded.remove(blockId);
      } else {
        expanded.add(blockId);
      }
      _persist();
      return;
    }

    final expanded = Set<String>.from(_legacyState.expandedBlockIds);
    if (expanded.contains(blockId)) {
      expanded.remove(blockId);
    } else {
      expanded.add(blockId);
    }
    _legacyState = _legacyState.copyWith(expandedBlockIds: expanded);
    _persist();
  }

  void markBlockComplete(String blockId) {
    if (_runtime != null) {
      _runtime!.completedBlockIds.add(blockId);
      final moved = _runtime!.player.nextBlock();
      if (_runtime!.applyTransition(moved)) {
        final activeId = state.activeBlock?.blockId;
        if (activeId != null) {
          _runtime!.expandedBlockIds
            ..remove(blockId)
            ..add(activeId);
        }
      } else {
        _runtime!.expandedBlockIds.add(blockId);
      }
      _persist();
      return;
    }

    final completed = Set<String>.from(_legacyState.completedBlockIds)
      ..add(blockId);
    final nextIndex = _firstIncompleteIndexLegacy(completed);
    _legacyState = _legacyState.copyWith(
      completedBlockIds: completed,
      activeBlockIndex: nextIndex ?? _legacyState.activeBlockIndex,
      expandedBlockIds: nextIndex == null
          ? _legacyState.expandedBlockIds
          : {_legacyState.plan.blocks[nextIndex].blockId},
    );
    _persist();
  }

  void reopenBlock(String blockId) {
    if (_runtime != null) {
      _runtime!.completedBlockIds.remove(blockId);
      final index = _runtime!.blockIndexFor(blockId);
      if (index >= 0) {
        _runtime!.syncPlayerToBlockIndex(index);
        _runtime!.expandedBlockIds.add(blockId);
      }
      _persist();
      return;
    }

    final completed = Set<String>.from(_legacyState.completedBlockIds)
      ..remove(blockId);
    final index = _legacyState.plan.blocks.indexWhere(
      (b) => b.blockId == blockId,
    );
    _legacyState = _legacyState.copyWith(
      completedBlockIds: completed,
      activeBlockIndex: index >= 0 ? index : _legacyState.activeBlockIndex,
      expandedBlockIds: {..._legacyState.expandedBlockIds, blockId},
    );
    _persist();
  }

  void completeSession({bool allowIncomplete = false}) {
    if (!allowIncomplete && state.incompleteCount > 0) {
      return;
    }

    if (_runtime != null) {
      final finished = _runtime!.player.completeWorkout(
        recordedAt: DateTime.now(),
      );
      _runtime!.applyTransition(finished);
      _persist();
      return;
    }

    _legacyState = _legacyState.copyWith(
      sessionStatus: SessionExecutionStatus.completed,
      endedAt: DateTime.now(),
    );
    _persist();
  }

  /// Projects domain completion onto M7 session state without re-running orchestration.
  ///
  /// Call after [AthleteWorkoutOrchestrator.completeTodayWorkout] succeeds; the player
  /// in memory is still active until this syncs the finished player for UI.
  void applyDomainCompletionProjection({required DateTime finishedAt}) {
    if (_runtime == null) return;

    final finished = _runtime!.player.finishWorkout(recordedAt: finishedAt);
    _runtime!.applyTransition(finished);

    for (final block in _plan.blocks) {
      if (block.hasAthleteVisibleContent) {
        _runtime!.completedBlockIds.add(block.blockId);
      }
    }
    _persist();
  }

  void abandonSession() {
    if (_runtime != null) {
      final abandoned = _runtime!.player.abandon(recordedAt: DateTime.now());
      _runtime!.applyTransition(abandoned);
      _persist();
      return;
    }

    _legacyState = _legacyState.copyWith(
      sessionStatus: SessionExecutionStatus.abandoned,
      endedAt: DateTime.now(),
    );
    _persist();
  }

  int? _firstIncompleteIndexLegacy(Set<String> completed) {
    for (var i = 0; i < _legacyState.plan.blocks.length; i++) {
      final block = _legacyState.plan.blocks[i];
      if (!block.hasAthleteVisibleContent) continue;
      if (!completed.contains(block.blockId)) return i;
    }
    return null;
  }
}

class AthleteSessionMemoryStore {
  AthleteSessionMemoryStore._();

  static final AthleteSessionMemoryStore instance =
      AthleteSessionMemoryStore._();

  final Map<String, ActiveSessionState> _sessions = {};

  static String sessionKey({
    required String protocolId,
    int? trainingSessionId,
  }) {
    return '${trainingSessionId ?? 'preview'}:$protocolId';
  }

  ActiveSessionState? read(String sessionKey) => _sessions[sessionKey];

  void write(ActiveSessionState state) {
    _sessions[state.sessionKey] = state;
  }

  void clear(String sessionKey) {
    _sessions.remove(sessionKey);
  }

  void clearAll() {
    _sessions.clear();
  }

  int clearForProtocol(String protocolId) {
    final suffix = ':$protocolId';
    final keys = _sessions.keys
        .where((key) => key.endsWith(suffix))
        .toList(growable: false);
    for (final key in keys) {
      _sessions.remove(key);
    }
    return keys.length;
  }
}
