import 'package:founder_importer/models/programme_version.dart';
import 'package:founder_importer/models/programme_version_day.dart';
import 'package:founder_importer/models/programme_version_phase.dart';
import 'package:founder_importer/models/programme_version_session_slot.dart';
import 'package:founder_importer/models/programme_version_week.dart';

/// Compiled in-memory tree for a pinned programme version.
///
/// Built by [ProgrammeVersionStore.loadTemplate].
/// See `43_Programme_Engine_Service_Contracts.md` §4.1.
class ProgrammeTemplate {
  const ProgrammeTemplate({
    required this.version,
    this.phases = const [],
    this.weeks = const [],
  });

  final ProgrammeVersion version;
  final List<ProgrammeVersionPhase> phases;
  final List<ProgrammeVersionWeek> weeks;

  List<ProgrammeVersionWeek> get sortedWeeks {
    final copy = List<ProgrammeVersionWeek>.from(weeks);
    copy.sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    return copy;
  }

  ProgrammeVersionWeek? weekForNumber(int weekNumber) {
    for (final week in weeks) {
      if (week.weekNumber == weekNumber) return week;
    }

    return null;
  }
}

/// A week node with nested days and slots for schedule resolution.
class ProgrammeTemplateWeekNode {
  const ProgrammeTemplateWeekNode({
    required this.week,
    required this.days,
  });

  final ProgrammeVersionWeek week;
  final List<ProgrammeTemplateDayNode> days;

  List<ProgrammeTemplateDayNode> get sortedDays {
    final copy = List<ProgrammeTemplateDayNode>.from(days);
    copy.sort((left, right) => left.day.dayOrder.compareTo(right.day.dayOrder));
    return copy;
  }
}

/// A day node with ordered session slots.
class ProgrammeTemplateDayNode {
  const ProgrammeTemplateDayNode({
    required this.day,
    required this.slots,
  });

  final ProgrammeVersionDay day;
  final List<ProgrammeVersionSessionSlot> slots;

  List<ProgrammeVersionSessionSlot> get sortedSlots {
    final copy = List<ProgrammeVersionSessionSlot>.from(slots);
    copy.sort(
      (left, right) => left.sessionOrder.compareTo(right.sessionOrder),
    );
    return copy;
  }
}

/// Fully nested template for resolver services.
class ProgrammeTemplateTree {
  const ProgrammeTemplateTree({
    required this.template,
    required this.weekNodes,
  });

  final ProgrammeTemplate template;
  final List<ProgrammeTemplateWeekNode> weekNodes;

  ProgrammeTemplateWeekNode? weekNodeForNumber(int weekNumber) {
    for (final node in weekNodes) {
      if (node.week.weekNumber == weekNumber) return node;
    }

    return null;
  }
}
