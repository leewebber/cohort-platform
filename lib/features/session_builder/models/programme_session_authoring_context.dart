import '../../../models/programme_day_draft.dart';
import '../../../models/programme_session_slot_draft.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/programme_week_draft.dart';
import 'session_builder_host_mode.dart';

/// Programme slot context for embedded Session Builder (M2 navigation only).
class ProgrammeSessionAuthoringContext {
  const ProgrammeSessionAuthoringContext({
    required this.programmeVersionId,
    required this.weekLocalId,
    required this.dayLocalId,
    required this.slotLocalId,
    required this.weekNumber,
    required this.dayLabel,
    required this.slotDisplayLabel,
    required this.authoringIntent,
    this.existingContentId,
    this.sourceProtocolId,
    this.programmeLocationLabel,
  });

  final String programmeVersionId;
  final String weekLocalId;
  final String dayLocalId;
  final String slotLocalId;
  final int weekNumber;
  final String dayLabel;
  final String slotDisplayLabel;
  final String? existingContentId;

  /// When copying from an assigned Cohort Protocol, the official source ID
  /// expected on the slot at save time (M5 conflict detection).
  final String? sourceProtocolId;
  final ProgrammeSessionAuthoringIntent authoringIntent;
  final String? programmeLocationLabel;

  /// Builds context from programme editor tree nodes.
  factory ProgrammeSessionAuthoringContext.fromEditorNodes({
    required String programmeVersionId,
    required ProgrammeWeekDraft week,
    required ProgrammeDayDraft day,
    required ProgrammeSessionSlotDraft slot,
    required     ProgrammeSessionAuthoringIntent authoringIntent,
    String? existingContentId,
    String? sourceProtocolId,
  }) {
    final dayLabel = _resolveDayLabel(day);
    final slotLabel = _resolveSlotLabel(slot, dayLabel);
    final locationLabel =
        'Week ${week.weekNumber} · $dayLabel · $slotLabel';

    return ProgrammeSessionAuthoringContext(
      programmeVersionId: programmeVersionId,
      weekLocalId: week.localId,
      dayLocalId: day.localId,
      slotLocalId: slot.localId,
      weekNumber: week.weekNumber,
      dayLabel: dayLabel,
      slotDisplayLabel: slotLabel,
      existingContentId: existingContentId,
      sourceProtocolId: sourceProtocolId,
      authoringIntent: authoringIntent,
      programmeLocationLabel: locationLabel,
    );
  }

  static String _resolveDayLabel(ProgrammeDayDraft day) {
    final title = day.title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }

    return 'Day ${day.dayOrder}';
  }

  static String _resolveSlotLabel(
    ProgrammeSessionSlotDraft slot,
    String dayLabel,
  ) {
    final displayTitle = slot.displayTitle?.trim();
    if (displayTitle != null && displayTitle.isNotEmpty) {
      return displayTitle;
    }

    final timeLabel = switch (slot.timeOfDay) {
      ProgrammeSessionTimeOfDay.morning => 'Morning',
      ProgrammeSessionTimeOfDay.afternoon => 'Afternoon',
      ProgrammeSessionTimeOfDay.evening => 'Evening',
      ProgrammeSessionTimeOfDay.any => '$dayLabel Session',
    };

    return timeLabel;
  }
}
