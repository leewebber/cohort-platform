/// Read-only cursor suggestion after schedule resolution.
///
/// Does not mutate [ProgrammeAssignment] — applied later by progression logic.
class ProgrammeSuggestedCursor {
  const ProgrammeSuggestedCursor({
    required this.weekNumber,
    required this.dayKey,
    required this.slotOrder,
  });

  final int weekNumber;
  final String dayKey;
  final int slotOrder;

  @override
  String toString() {
    return 'week $weekNumber / $dayKey / slot $slotOrder';
  }
}
