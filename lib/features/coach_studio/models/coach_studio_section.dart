/// Coach Studio landing sections.
enum CoachStudioSection {
  programmes,
  trainingLibrary,
  exercises,
  athletes,
  settings,
}

extension CoachStudioSectionLabels on CoachStudioSection {
  String get title {
    return switch (this) {
      CoachStudioSection.programmes => 'Programmes',
      CoachStudioSection.trainingLibrary => 'Training Library',
      CoachStudioSection.exercises => 'Exercises',
      CoachStudioSection.athletes => 'Athletes',
      CoachStudioSection.settings => 'Settings',
    };
  }

  String get subtitle {
    return switch (this) {
      CoachStudioSection.programmes =>
        'Multi-week curricula, drafts, and publishing.',
      CoachStudioSection.trainingLibrary =>
        'Cohort Protocols, Session Library, and reusable workouts.',
      CoachStudioSection.exercises => 'Movement library and coaching knowledge.',
      CoachStudioSection.athletes => 'Roster, assignments, and athlete context.',
      CoachStudioSection.settings => 'Studio preferences and administration.',
    };
  }

  bool get isAvailableInV01 {
    return this == CoachStudioSection.programmes ||
        this == CoachStudioSection.trainingLibrary ||
        this == CoachStudioSection.athletes;
  }
}
