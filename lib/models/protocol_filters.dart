class ProtocolFilters {
  const ProtocolFilters({
    this.goal,
    this.equipment,
    this.capability,
    this.demand,
    this.recovery,
  });

  final String? goal;
  final String? equipment;
  final String? capability;
  final String? demand;
  final String? recovery;

  bool get hasActiveFilters {
    return goal != null ||
        equipment != null ||
        capability != null ||
        demand != null ||
        recovery != null;
  }

  ProtocolFilters copyWith({
    String? goal,
    String? equipment,
    String? capability,
    String? demand,
    String? recovery,
  }) {
    return ProtocolFilters(
      goal: goal ?? this.goal,
      equipment: equipment ?? this.equipment,
      capability: capability ?? this.capability,
      demand: demand ?? this.demand,
      recovery: recovery ?? this.recovery,
    );
  }

  ProtocolFilters clearGoal() {
    return ProtocolFilters(
      equipment: equipment,
      capability: capability,
      demand: demand,
      recovery: recovery,
    );
  }

  ProtocolFilters clearEquipment() {
    return ProtocolFilters(
      goal: goal,
      capability: capability,
      demand: demand,
      recovery: recovery,
    );
  }

  ProtocolFilters clearCapability() {
    return ProtocolFilters(
      goal: goal,
      equipment: equipment,
      demand: demand,
      recovery: recovery,
    );
  }

  ProtocolFilters clearDemand() {
    return ProtocolFilters(
      goal: goal,
      equipment: equipment,
      capability: capability,
      recovery: recovery,
    );
  }

  ProtocolFilters clearRecovery() {
    return ProtocolFilters(
      goal: goal,
      equipment: equipment,
      capability: capability,
      demand: demand,
    );
  }

  static const empty = ProtocolFilters();
}