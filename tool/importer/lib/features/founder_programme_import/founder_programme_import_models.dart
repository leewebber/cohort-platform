/// Parsed founder programme YAML (schema version 1).
class FounderProgrammeYamlDocument {
  const FounderProgrammeYamlDocument({
    required this.schemaVersion,
    required this.programme,
    required this.weeks,
  });

  final int schemaVersion;
  final FounderProgrammeYamlProgramme programme;
  final List<FounderProgrammeYamlWeek> weeks;
}

class FounderProgrammeYamlProgramme {
  const FounderProgrammeYamlProgramme({
    required this.importKey,
    required this.title,
    required this.code,
    this.description,
    this.objective,
    required this.durationWeeks,
    this.sessionsPerWeek,
  });

  final String importKey;
  final String title;
  final String code;
  final String? description;
  final String? objective;
  final int durationWeeks;
  final int? sessionsPerWeek;
}

class FounderProgrammeYamlWeek {
  const FounderProgrammeYamlWeek({
    required this.weekNumber,
    this.title,
    required this.days,
  });

  final int weekNumber;
  final String? title;
  final List<FounderProgrammeYamlDay> days;
}

class FounderProgrammeYamlDay {
  const FounderProgrammeYamlDay({
    required this.dayNumber,
    this.displayName,
    required this.isRestDay,
    this.coachNotes,
    required this.sessions,
  });

  final int dayNumber;
  final String? displayName;
  final bool isRestDay;
  final String? coachNotes;
  final List<FounderProgrammeYamlSession> sessions;
}

class FounderProgrammeYamlSession {
  const FounderProgrammeYamlSession({
    required this.title,
    required this.sessionType,
    this.estimatedDurationMinutes,
    this.coachNotes,
    required this.blocks,
  });

  final String title;
  final String sessionType;
  final int? estimatedDurationMinutes;
  final String? coachNotes;
  final List<FounderProgrammeYamlBlock> blocks;
}

class FounderProgrammeYamlBlock {
  const FounderProgrammeYamlBlock({
    required this.title,
    required this.blockType,
    required this.order,
    this.coachNotes,
    required this.exercises,
  });

  final String title;
  final String blockType;
  final int order;
  final String? coachNotes;
  final List<FounderProgrammeYamlExercise> exercises;
}

class FounderProgrammeYamlExercise {
  const FounderProgrammeYamlExercise({
    this.exerciseSlug,
    this.exerciseName,
    required this.order,
    this.prescription,
    this.notes,
  });

  final String? exerciseSlug;
  final String? exerciseName;
  final int order;
  final Map<String, dynamic>? prescription;
  final String? notes;
}
