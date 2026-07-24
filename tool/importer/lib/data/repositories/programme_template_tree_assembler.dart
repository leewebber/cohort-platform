import 'package:founder_importer/features/programme/models/programme_template.dart';
import 'package:founder_importer/models/programme_version.dart';
import 'package:founder_importer/models/programme_version_day.dart';
import 'package:founder_importer/models/programme_version_phase.dart';
import 'package:founder_importer/models/programme_version_session_slot.dart';
import 'package:founder_importer/models/programme_version_week.dart';

/// Deterministic assembly of a programme version tree from flat rows.
///
/// Fetch/persist only — no business rules.
class ProgrammeTemplateTreeAssembler {
  const ProgrammeTemplateTreeAssembler();

  ProgrammeTemplateTree assemble({
    required ProgrammeVersion version,
    required List<ProgrammeVersionPhase> phases,
    required List<ProgrammeVersionWeek> weeks,
    required List<ProgrammeVersionDay> days,
    required List<ProgrammeVersionSessionSlot> slots,
  }) {
    final sortedPhases = List<ProgrammeVersionPhase>.from(phases)
      ..sort((left, right) => left.phaseOrder.compareTo(right.phaseOrder));

    final sortedWeeks = List<ProgrammeVersionWeek>.from(weeks)
      ..sort((left, right) => left.weekNumber.compareTo(right.weekNumber));

    final daysByWeekId = <String, List<ProgrammeVersionDay>>{};
    for (final day in days) {
      daysByWeekId.putIfAbsent(day.weekId, () => []).add(day);
    }

    final slotsByDayId = <String, List<ProgrammeVersionSessionSlot>>{};
    for (final slot in slots) {
      slotsByDayId.putIfAbsent(slot.dayId, () => []).add(slot);
    }

    final weekNodes = sortedWeeks.map((week) {
      final weekDays = List<ProgrammeVersionDay>.from(
        daysByWeekId[week.id] ?? const [],
      )..sort((left, right) => left.dayOrder.compareTo(right.dayOrder));

      final dayNodes = weekDays.map((day) {
        final daySlots = List<ProgrammeVersionSessionSlot>.from(
          slotsByDayId[day.id] ?? const [],
        )..sort(
            (left, right) => left.sessionOrder.compareTo(right.sessionOrder),
          );

        return ProgrammeTemplateDayNode(day: day, slots: daySlots);
      }).toList();

      return ProgrammeTemplateWeekNode(week: week, days: dayNodes);
    }).toList();

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(
        version: version,
        phases: sortedPhases,
        weeks: sortedWeeks,
      ),
      weekNodes: weekNodes,
    );
  }
}
