import '../../../programme/models/programme_catalog_entry.dart';
import '../models/programme_catalogue_sort_mode.dart';

/// Client-side search, filter, and sort for catalogue entries.
class ProgrammeCatalogueListProcessor {
  const ProgrammeCatalogueListProcessor();

  List<ProgrammeCatalogEntry> apply({
    required List<ProgrammeCatalogEntry> entries,
    String searchTerm = '',
    String? primaryGoal,
    ProgrammeCatalogueSortMode sortMode =
        ProgrammeCatalogueSortMode.lastEdited,
  }) {
    final filtered = _filter(
      entries: entries,
      searchTerm: searchTerm,
      primaryGoal: primaryGoal,
    );
    return _sort(filtered, sortMode);
  }

  List<ProgrammeCatalogEntry> _filter({
    required List<ProgrammeCatalogEntry> entries,
    required String searchTerm,
    String? primaryGoal,
  }) {
    final term = searchTerm.trim().toLowerCase();
    final goal = primaryGoal?.trim();

    return entries.where((entry) {
      if (goal != null && goal.isNotEmpty) {
        final entryGoal = entry.primaryGoal?.trim() ?? '';
        if (entryGoal.toLowerCase() != goal.toLowerCase()) {
          return false;
        }
      }

      if (term.isEmpty) return true;

      return entry.name.toLowerCase().contains(term) ||
          entry.lineageCode.toLowerCase().contains(term) ||
          (entry.description?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  List<ProgrammeCatalogEntry> _sort(
    List<ProgrammeCatalogEntry> entries,
    ProgrammeCatalogueSortMode sortMode,
  ) {
    final sorted = List<ProgrammeCatalogEntry>.from(entries);

    switch (sortMode) {
      case ProgrammeCatalogueSortMode.lastEdited:
        sorted.sort((left, right) {
          final leftStamp = left.updatedAt ?? left.publishedAt ?? left.archivedAt;
          final rightStamp =
              right.updatedAt ?? right.publishedAt ?? right.archivedAt;

          if (leftStamp == null && rightStamp == null) {
            return left.name.toLowerCase().compareTo(right.name.toLowerCase());
          }
          if (leftStamp == null) return 1;
          if (rightStamp == null) return -1;
          return rightStamp.compareTo(leftStamp);
        });
      case ProgrammeCatalogueSortMode.nameAZ:
        sorted.sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );
      case ProgrammeCatalogueSortMode.versionNewest:
        sorted.sort((left, right) {
          final lineageCompare =
              left.lineageCode.compareTo(right.lineageCode);
          if (lineageCompare != 0) return lineageCompare;
          return right.versionNumber.compareTo(left.versionNumber);
        });
    }

    return sorted;
  }
}
