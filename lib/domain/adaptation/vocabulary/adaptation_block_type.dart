/// Semantic session block type for adaptation policy (mirrors M6 block taxonomy).
enum AdaptationBlockType {
  warmUp,
  strength,
  skill,
  accessory,
  conditioning,
  core,
  coolDown,
  custom,
}

extension AdaptationBlockTypePlanning on AdaptationBlockType {
  /// Matches [PlannedBlockAdaptationInput.blockTypeDbValue] from authoring
  /// (`SessionBlockType.name`, e.g. `warmUp`, `strength`).
  static AdaptationBlockType fromPlanningDbValue(String dbValue) {
    return AdaptationBlockType.values.firstWhere(
      (type) => type.name == dbValue,
      orElse: () => AdaptationBlockType.custom,
    );
  }
}
