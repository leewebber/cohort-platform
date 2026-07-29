/// Programme goal reference for planning (ontology goal id).
class PlanningGoalContext {
  const PlanningGoalContext({required this.goalId, this.goalLabel});

  final String goalId;
  final String? goalLabel;

  @override
  bool operator ==(Object other) {
    return other is PlanningGoalContext &&
        other.goalId == goalId &&
        other.goalLabel == goalLabel;
  }

  @override
  int get hashCode => Object.hash(goalId, goalLabel);
}
