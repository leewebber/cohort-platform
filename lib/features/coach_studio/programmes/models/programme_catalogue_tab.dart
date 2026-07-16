/// Programme Catalogue tabs.
enum ProgrammeCatalogueTab {
  drafts,
  published,
  cohortGlobal,
  archived,
}

extension ProgrammeCatalogueTabLabels on ProgrammeCatalogueTab {
  String get label {
    return switch (this) {
      ProgrammeCatalogueTab.drafts => 'Drafts',
      ProgrammeCatalogueTab.published => 'Published',
      ProgrammeCatalogueTab.cohortGlobal => 'Cohort Global',
      ProgrammeCatalogueTab.archived => 'Archived',
    };
  }

  String get eyebrowLabel {
    return switch (this) {
      ProgrammeCatalogueTab.drafts => 'DRAFT',
      ProgrammeCatalogueTab.published => 'PUBLISHED',
      ProgrammeCatalogueTab.cohortGlobal => 'GLOBAL',
      ProgrammeCatalogueTab.archived => 'ARCHIVED',
    };
  }
}
