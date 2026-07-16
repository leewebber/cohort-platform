import '../models/programme_catalog_entry.dart';
import '../../../models/programme_vocabulary.dart';

/// Maps catalogue rows to coach-facing owner labels.
String programmeCatalogOwnerDisplayLabel({
  required ProgrammeCatalogEntry entry,
  required String coachId,
}) {
  if (entry.ownerId != null && entry.ownerId == coachId) {
    return 'You';
  }

  if (entry.approvedForGlobal &&
      entry.libraryScope == ProgrammeLibraryScope.cohortGlobal) {
    return 'Cohort Global';
  }

  return entry.libraryScope.displayLabel;
}
