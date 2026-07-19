import '../models/session_execution_plan.dart';
import 'session_execution_status.dart';

class BlockExecutionState {
  const BlockExecutionState({
    required this.blockId,
    required this.status,
  });

  final String blockId;
  final BlockExecutionStatus status;

  BlockExecutionState copyWith({BlockExecutionStatus? status}) {
    return BlockExecutionState(
      blockId: blockId,
      status: status ?? this.status,
    );
  }
}

class ActiveSessionState {
  const ActiveSessionState({
    required this.sessionKey,
    required this.plan,
    required this.blockStates,
    required this.activeBlockIndex,
    required this.completedBlockIds,
    required this.expandedBlockIds,
    required this.sessionStatus,
    this.startedAt,
    this.endedAt,
  });

  final String sessionKey;
  final SessionExecutionPlan plan;
  final List<BlockExecutionState> blockStates;
  final int activeBlockIndex;
  final Set<String> completedBlockIds;
  final Set<String> expandedBlockIds;
  final SessionExecutionStatus sessionStatus;
  final DateTime? startedAt;
  final DateTime? endedAt;

  SessionExecutionBlock? get activeBlock {
    if (activeBlockIndex < 0 || activeBlockIndex >= plan.blocks.length) {
      return null;
    }
    return plan.blocks[activeBlockIndex];
  }

  int get completedCount => completedBlockIds.length;
  int get totalBlocks => plan.blocks.length;
  int get incompleteCount => totalBlocks - completedCount;

  bool isBlockComplete(String blockId) => completedBlockIds.contains(blockId);

  bool isBlockExpanded(String blockId) => expandedBlockIds.contains(blockId);

  BlockExecutionStatus statusFor(String blockId) {
    final index = plan.blocks.indexWhere((block) => block.blockId == blockId);
    if (index == activeBlockIndex) return BlockExecutionStatus.active;
    if (completedBlockIds.contains(blockId)) return BlockExecutionStatus.complete;
    return BlockExecutionStatus.notStarted;
  }

  ActiveSessionState copyWith({
    List<BlockExecutionState>? blockStates,
    int? activeBlockIndex,
    Set<String>? completedBlockIds,
    Set<String>? expandedBlockIds,
    SessionExecutionStatus? sessionStatus,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return ActiveSessionState(
      sessionKey: sessionKey,
      plan: plan,
      blockStates: blockStates ?? this.blockStates,
      activeBlockIndex: activeBlockIndex ?? this.activeBlockIndex,
      completedBlockIds: completedBlockIds ?? this.completedBlockIds,
      expandedBlockIds: expandedBlockIds ?? this.expandedBlockIds,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  factory ActiveSessionState.initial({
    required String sessionKey,
    required SessionExecutionPlan plan,
  }) {
    final blockStates = [
      for (final block in plan.blocks)
        BlockExecutionState(
          blockId: block.blockId,
          status: BlockExecutionStatus.notStarted,
        ),
    ];

    final firstIncomplete = plan.blocks.indexWhere(
      (block) => block.hasAthleteVisibleContent,
    );

    return ActiveSessionState(
      sessionKey: sessionKey,
      plan: plan,
      blockStates: blockStates,
      activeBlockIndex: firstIncomplete >= 0 ? firstIncomplete : 0,
      completedBlockIds: {},
      expandedBlockIds: firstIncomplete >= 0
          ? {plan.blocks[firstIncomplete].blockId}
          : {},
      sessionStatus: SessionExecutionStatus.notStarted,
    );
  }
}
