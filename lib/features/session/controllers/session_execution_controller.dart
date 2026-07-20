import '../models/active_session_state.dart';
import '../models/session_execution_plan.dart';
import '../models/session_execution_status.dart';

class AthleteSessionMemoryStore {
  AthleteSessionMemoryStore._();

  static final AthleteSessionMemoryStore instance = AthleteSessionMemoryStore._();

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

  /// Clears in-memory session execution state for a protocol (developer reset).
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

class SessionExecutionController {
  SessionExecutionController({
    required SessionExecutionPlan plan,
    required String sessionKey,
    AthleteSessionMemoryStore? memoryStore,
    ActiveSessionState? restoredState,
  })  : _memoryStore = memoryStore ?? AthleteSessionMemoryStore.instance,
        _state = restoredState ??
            AthleteSessionMemoryStore.instance.read(sessionKey) ??
            ActiveSessionState.initial(
              sessionKey: sessionKey,
              plan: plan,
            );

  final AthleteSessionMemoryStore _memoryStore;
  ActiveSessionState _state;

  ActiveSessionState get state => _state;

  void _persist() => _memoryStore.write(_state);

  void startSession() {
    _state = _state.copyWith(
      sessionStatus: SessionExecutionStatus.inProgress,
      startedAt: DateTime.now(),
      expandedBlockIds: {
        if (_state.activeBlock?.blockId != null) _state.activeBlock!.blockId,
      },
    );
    _persist();
  }

  void goToBlock(int index) {
    if (index < 0 || index >= _state.plan.blocks.length) return;
    final blockId = _state.plan.blocks[index].blockId;
    _state = _state.copyWith(
      activeBlockIndex: index,
      expandedBlockIds: {blockId},
      sessionStatus: SessionExecutionStatus.inProgress,
    );
    _persist();
  }

  void goToNextBlock() {
    goToBlock(_state.activeBlockIndex + 1);
  }

  void goToPreviousBlock() {
    goToBlock(_state.activeBlockIndex - 1);
  }

  void toggleBlockExpanded(String blockId) {
    final expanded = Set<String>.from(_state.expandedBlockIds);
    if (expanded.contains(blockId)) {
      expanded.remove(blockId);
    } else {
      expanded.add(blockId);
    }
    _state = _state.copyWith(expandedBlockIds: expanded);
    _persist();
  }

  void markBlockComplete(String blockId) {
    final completed = Set<String>.from(_state.completedBlockIds)..add(blockId);
    final nextIndex = _firstIncompleteIndex(completed);
    _state = _state.copyWith(
      completedBlockIds: completed,
      activeBlockIndex: nextIndex ?? _state.activeBlockIndex,
      expandedBlockIds: nextIndex == null
          ? _state.expandedBlockIds
          : {_state.plan.blocks[nextIndex].blockId},
    );
    _persist();
  }

  void reopenBlock(String blockId) {
    final completed = Set<String>.from(_state.completedBlockIds)..remove(blockId);
    final index = _state.plan.blocks.indexWhere((b) => b.blockId == blockId);
    _state = _state.copyWith(
      completedBlockIds: completed,
      activeBlockIndex: index >= 0 ? index : _state.activeBlockIndex,
      expandedBlockIds: {..._state.expandedBlockIds, blockId},
    );
    _persist();
  }

  void completeSession({bool allowIncomplete = false}) {
    if (!allowIncomplete && _state.incompleteCount > 0) {
      return;
    }
    _state = _state.copyWith(
      sessionStatus: SessionExecutionStatus.completed,
      endedAt: DateTime.now(),
    );
    _persist();
  }

  void abandonSession() {
    _state = _state.copyWith(
      sessionStatus: SessionExecutionStatus.abandoned,
      endedAt: DateTime.now(),
    );
    _persist();
  }

  int? _firstIncompleteIndex(Set<String> completed) {
    for (var i = 0; i < _state.plan.blocks.length; i++) {
      final block = _state.plan.blocks[i];
      if (!block.hasAthleteVisibleContent) continue;
      if (!completed.contains(block.blockId)) return i;
    }
    return null;
  }
}
