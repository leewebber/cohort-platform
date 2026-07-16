/// Client-side sort modes for Programme Catalogue lists.
enum ProgrammeCatalogueSortMode {
  lastEdited,
  nameAZ,
  versionNewest,
}

extension ProgrammeCatalogueSortModeLabels on ProgrammeCatalogueSortMode {
  String get label {
    return switch (this) {
      ProgrammeCatalogueSortMode.lastEdited => 'Last edited',
      ProgrammeCatalogueSortMode.nameAZ => 'Name A–Z',
      ProgrammeCatalogueSortMode.versionNewest => 'Version newest',
    };
  }
}
