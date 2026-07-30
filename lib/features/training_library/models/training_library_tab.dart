/// Top-level destinations inside Training Library.
enum TrainingLibraryTab { cohortProtocols, sessionLibrary, templates }

extension TrainingLibraryTabLabels on TrainingLibraryTab {
  String get title {
    return switch (this) {
      TrainingLibraryTab.cohortProtocols => 'Cohort Protocols',
      TrainingLibraryTab.sessionLibrary => 'My Sessions',
      TrainingLibraryTab.templates => 'Templates',
    };
  }
}
