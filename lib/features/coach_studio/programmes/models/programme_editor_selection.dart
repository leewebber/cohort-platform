import '../../../programme_builder/models/programme_builder_path.dart';

/// Current editor selection for week/day/slot navigation.
class ProgrammeEditorSelection {
  const ProgrammeEditorSelection({
    this.weekLocalId,
    this.dayLocalId,
    this.slotLocalId,
  });

  final String? weekLocalId;
  final String? dayLocalId;
  final String? slotLocalId;

  ProgrammeEditorSelection copyWith({
    String? weekLocalId,
    String? dayLocalId,
    String? slotLocalId,
    bool clearDay = false,
    bool clearSlot = false,
  }) {
    return ProgrammeEditorSelection(
      weekLocalId: weekLocalId ?? this.weekLocalId,
      dayLocalId: clearDay ? null : (dayLocalId ?? this.dayLocalId),
      slotLocalId: clearSlot ? null : (slotLocalId ?? this.slotLocalId),
    );
  }

  ProgrammeBuilderPath? toPath() {
    if (weekLocalId == null) return null;
    if (slotLocalId != null && dayLocalId != null) {
      return ProgrammeBuilderSlotPath(
        weekLocalId: weekLocalId!,
        dayLocalId: dayLocalId!,
        slotLocalId: slotLocalId!,
      );
    }
    if (dayLocalId != null) {
      return ProgrammeBuilderDayPath(
        weekLocalId: weekLocalId!,
        dayLocalId: dayLocalId!,
      );
    }
    return ProgrammeBuilderWeekPath(weekLocalId: weekLocalId!);
  }
}
