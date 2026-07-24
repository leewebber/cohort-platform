/// Stable typed path to a node in a programme builder document.
sealed class ProgrammeBuilderPath {
  const ProgrammeBuilderPath();
}

class ProgrammeBuilderProgrammePath extends ProgrammeBuilderPath {
  const ProgrammeBuilderProgrammePath();
}

class ProgrammeBuilderWeekPath extends ProgrammeBuilderPath {
  const ProgrammeBuilderWeekPath({required this.weekLocalId});

  final String weekLocalId;
}

class ProgrammeBuilderDayPath extends ProgrammeBuilderPath {
  const ProgrammeBuilderDayPath({
    required this.weekLocalId,
    required this.dayLocalId,
  });

  final String weekLocalId;
  final String dayLocalId;
}

class ProgrammeBuilderSlotPath extends ProgrammeBuilderPath {
  const ProgrammeBuilderSlotPath({
    required this.weekLocalId,
    required this.dayLocalId,
    required this.slotLocalId,
  });

  final String weekLocalId;
  final String dayLocalId;
  final String slotLocalId;
}
