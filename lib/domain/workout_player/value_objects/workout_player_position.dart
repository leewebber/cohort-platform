/// Pointer into an [AdaptedSessionExecutionSnapshot] navigable sequence.
///
/// The finest navigable unit in M6 is an exercise slot within a retained block.
/// [stepIndex] is the zero-based ordinal across all retained-block exercises in
/// workout order (block [sourcePosition], then exercise list order).
class WorkoutPlayerPosition {
  const WorkoutPlayerPosition({
    required this.sourceBlockLocalId,
    required this.exerciseLinkLocalId,
    required this.stepIndex,
  });

  final String sourceBlockLocalId;
  final String exerciseLinkLocalId;
  final int stepIndex;

  @override
  bool operator ==(Object other) {
    return other is WorkoutPlayerPosition &&
        other.sourceBlockLocalId == sourceBlockLocalId &&
        other.exerciseLinkLocalId == exerciseLinkLocalId &&
        other.stepIndex == stepIndex;
  }

  @override
  int get hashCode =>
      Object.hash(sourceBlockLocalId, exerciseLinkLocalId, stepIndex);
}
