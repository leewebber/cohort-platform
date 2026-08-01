import '../models/programme_template.dart';
import '../../../models/programme_version_session_slot.dart';

/// Authored cursor position inside an exact programme package.
class AuthoredProgrammeCursor {
  const AuthoredProgrammeCursor({
    required this.weekNumber,
    required this.dayKey,
    required this.slotOrder,
  });

  final int weekNumber;
  final String dayKey;
  final int slotOrder;
}

/// Immediate next authored executable slot derived from package structure.
class AuthoredProgrammeNextSlot {
  const AuthoredProgrammeNextSlot({
    required this.weekNumber,
    required this.dayKey,
    required this.slotOrder,
    required this.protocolId,
    required this.sessionSlotId,
  });

  final int weekNumber;
  final String dayKey;
  final int slotOrder;
  final String protocolId;
  final String sessionSlotId;
}

/// Pure package-authored cursor traversal for Sprint 1.5A.
///
/// Order: next slot in current day → first executable slot in next authored
/// day → first executable slot in next authored week. Never sorts day keys
/// lexicographically, never uses calendar dates, never falls back to latest.
class AthleteProgrammeAuthoredCursorTraversal {
  const AthleteProgrammeAuthoredCursorTraversal();

  /// Returns the immediate next executable slot, or null when terminal.
  AuthoredProgrammeNextSlot? nextExecutableSlot({
    required ProgrammeTemplateTree tree,
    required AuthoredProgrammeCursor current,
  }) {
    final ordered = _executableSlots(tree);
    if (ordered.isEmpty) return null;

    final currentIndex = ordered.indexWhere(
      (slot) =>
          slot.weekNumber == current.weekNumber &&
          slot.dayKey == current.dayKey &&
          slot.slotOrder == current.slotOrder,
    );
    if (currentIndex < 0) {
      throw StateError(
        'invalid_current_cursor: '
        'w${current.weekNumber}/${current.dayKey}/s${current.slotOrder}',
      );
    }
    if (currentIndex + 1 >= ordered.length) return null;
    return ordered[currentIndex + 1];
  }

  List<AuthoredProgrammeNextSlot> _executableSlots(ProgrammeTemplateTree tree) {
    final out = <AuthoredProgrammeNextSlot>[];
    final weeks = List<ProgrammeTemplateWeekNode>.from(tree.weekNodes)
      ..sort(
        (left, right) => left.week.weekNumber.compareTo(right.week.weekNumber),
      );
    for (final week in weeks) {
      for (final day in week.sortedDays) {
        if (day.day.isRestDay) continue;
        for (final ProgrammeVersionSessionSlot slot in day.sortedSlots) {
          final protocolId = slot.protocolId.trim();
          if (protocolId.isEmpty) continue;
          out.add(
            AuthoredProgrammeNextSlot(
              weekNumber: week.week.weekNumber,
              dayKey: day.day.dayKey,
              slotOrder: slot.sessionOrder,
              protocolId: protocolId,
              sessionSlotId: slot.id,
            ),
          );
        }
      }
    }
    return out;
  }
}
