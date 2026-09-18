import 'content_graph_manifest.dart';
import 'content_graph_models.dart';

enum ContentGraphReconstructionClass {
  fullyResolvable,
  resolvableThroughSupplemental,
  explicitlyUnresolved,
  invalidConflicting,
}

class ContentGraphReconstructionItem {
  const ContentGraphReconstructionItem({
    required this.id,
    required this.classification,
    this.reason,
  });

  final String id;
  final ContentGraphReconstructionClass classification;
  final String? reason;
}

class ContentGraphReconstructionReport {
  const ContentGraphReconstructionReport({
    required this.jobKey,
    required this.sourceFingerprint,
    required this.dryRun,
    required this.items,
    required this.rowsWritten,
    this.rejectedCode,
  });

  final String jobKey;
  final String sourceFingerprint;
  final bool dryRun;
  final List<ContentGraphReconstructionItem> items;
  final int rowsWritten;
  final String? rejectedCode;

  int get resolvableCount => items
      .where((i) =>
          i.classification == ContentGraphReconstructionClass.fullyResolvable)
      .length;
  int get supplementalCount => items
      .where((i) =>
          i.classification ==
          ContentGraphReconstructionClass.resolvableThroughSupplemental)
      .length;
  int get unresolvedCount => items
      .where((i) =>
          i.classification ==
          ContentGraphReconstructionClass.explicitlyUnresolved)
      .length;
  int get invalidCount => items
      .where((i) =>
          i.classification ==
          ContentGraphReconstructionClass.invalidConflicting)
      .length;
}

/// Deterministic reconstruction of graph manifests from canonical rows +
/// supplemental SQL. Does not rewrite authored content or assignment pins.
class ContentGraphReconstructionService {
  ContentGraphReconstructionService();

  final _jobs = <String, ContentGraphReconstructionReport>{};

  ContentGraphReconstructionReport run({
    required String jobKey,
    required String sourceCanonical,
    required Iterable<ContentExercise> exercises,
    required Iterable<String> supplementalExerciseIds,
    Iterable<String> authoredExerciseIds = const [],
    bool dryRun = true,
    bool apply = false,
  }) {
    final fingerprint = ContentGraphBinding.sha256Hex(sourceCanonical);
    final existing = _jobs[jobKey];
    if (existing != null && existing.sourceFingerprint != fingerprint) {
      final rejected = ContentGraphReconstructionReport(
        jobKey: jobKey,
        sourceFingerprint: fingerprint,
        dryRun: dryRun,
        items: existing.items,
        rowsWritten: 0,
        rejectedCode: 'source_changed_during_resume',
      );
      _jobs[jobKey] = rejected;
      return rejected;
    }

    final supplemental = supplementalExerciseIds.toSet();
    final authored = authoredExerciseIds.toSet();
    final items = <ContentGraphReconstructionItem>[];
    for (final exercise in exercises) {
      if (exercise.unresolvedLegacy || !exercise.id.startsWith('EX-')) {
        items.add(
          ContentGraphReconstructionItem(
            id: exercise.id,
            classification:
                ContentGraphReconstructionClass.explicitlyUnresolved,
            reason: 'name_only_or_legacy',
          ),
        );
        continue;
      }
      if (!RegExp(r'^EX-[0-9]{3,}$').hasMatch(exercise.id)) {
        items.add(
          ContentGraphReconstructionItem(
            id: exercise.id,
            classification:
                ContentGraphReconstructionClass.invalidConflicting,
            reason: 'non_canonical_id',
          ),
        );
        continue;
      }
      if (authored.contains(exercise.id)) {
        items.add(
          ContentGraphReconstructionItem(
            id: exercise.id,
            classification: ContentGraphReconstructionClass.fullyResolvable,
          ),
        );
      } else if (supplemental.contains(exercise.id)) {
        items.add(
          ContentGraphReconstructionItem(
            id: exercise.id,
            classification:
                ContentGraphReconstructionClass.resolvableThroughSupplemental,
          ),
        );
      } else {
        items.add(
          ContentGraphReconstructionItem(
            id: exercise.id,
            classification:
                ContentGraphReconstructionClass.explicitlyUnresolved,
            reason: 'not_guessed',
          ),
        );
      }
    }
    items.sort((a, b) => a.id.compareTo(b.id));

    final write = !dryRun && apply;
    final alreadyApplied = existing != null &&
        existing.rejectedCode == null &&
        !existing.dryRun;
    final rowsWritten = write && !alreadyApplied ? items.length : 0;
    final report = ContentGraphReconstructionReport(
      jobKey: jobKey,
      sourceFingerprint: fingerprint,
      dryRun: dryRun,
      items: items,
      rowsWritten: rowsWritten,
    );
    if (existing == null || existing.rejectedCode == null) {
      _jobs[jobKey] = report;
    }
    return report;
  }
}
