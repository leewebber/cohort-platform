import '../../../models/programme_vocabulary.dart';

/// Athlete-facing session preview card fields for Programme Builder.
///
/// Mirrors Home Today card precedence without importing Home widgets.
/// See `44_Programme_Builder.md` §10.
class ProgrammeBuilderAthleteSessionPreview {
  const ProgrammeBuilderAthleteSessionPreview({
    required this.title,
    required this.subtitle,
    required this.weekLabel,
    required this.status,
    required this.protocolId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
  });

  final String title;
  final String subtitle;
  final String weekLabel;
  final String status;
  final String protocolId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
}

/// Structural slot preview row.
class ProgrammeBuilderPreviewSlot {
  const ProgrammeBuilderPreviewSlot({
    required this.slotLocalId,
    required this.sessionOrder,
    required this.protocolId,
    this.protocolName,
    this.displayTitle,
    this.isOptional = false,
    this.completionExpectation =
        ProgrammeSessionCompletionExpectation.required,
    this.athletePreview,
  });

  final String slotLocalId;
  final int sessionOrder;
  final String protocolId;
  final String? protocolName;
  final String? displayTitle;
  final bool isOptional;
  final ProgrammeSessionCompletionExpectation completionExpectation;
  final ProgrammeBuilderAthleteSessionPreview? athletePreview;
}

/// Structural day preview row.
class ProgrammeBuilderPreviewDay {
  const ProgrammeBuilderPreviewDay({
    required this.dayLocalId,
    required this.dayKey,
    required this.dayOrder,
    this.title,
    this.dayType = ProgrammeDayType.training,
    this.slots = const [],
    this.isRestDay = false,
  });

  final String dayLocalId;
  final String dayKey;
  final int dayOrder;
  final String? title;
  final ProgrammeDayType dayType;
  final List<ProgrammeBuilderPreviewSlot> slots;
  final bool isRestDay;
}

/// Structural week preview row.
class ProgrammeBuilderPreviewWeek {
  const ProgrammeBuilderPreviewWeek({
    required this.weekLocalId,
    required this.weekNumber,
    this.title,
    this.days = const [],
  });

  final String weekLocalId;
  final int weekNumber;
  final String? title;
  final List<ProgrammeBuilderPreviewDay> days;
}

/// Combined structural and athlete-facing programme preview.
class ProgrammeBuilderPreview {
  const ProgrammeBuilderPreview({
    required this.programmeName,
    required this.lineageCode,
    required this.versionNumber,
    required this.weeks,
    this.initialAthletePreview,
  });

  final String programmeName;
  final String lineageCode;
  final int versionNumber;
  final List<ProgrammeBuilderPreviewWeek> weeks;
  final ProgrammeBuilderAthleteSessionPreview? initialAthletePreview;
}
