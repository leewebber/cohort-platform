/// Relative importance of a block within a session when adapting under constraints.
enum BlockPriority { essential, primary, secondary, optional, disposable }

extension BlockPriorityDb on BlockPriority {
  String get dbValue => name;

  static BlockPriority? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final priority in BlockPriority.values) {
      if (priority.dbValue == normalized) return priority;
    }
    return null;
  }
}
