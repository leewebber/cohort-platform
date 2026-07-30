import '../../../models/protocol_draft.dart';
import '../../../models/training_content_classification.dart';
import 'cohort_session_template_catalogue.dart';

/// Result of an idempotent canonical template seed run.
class CohortSessionTemplateSeedResult {
  const CohortSessionTemplateSeedResult({
    required this.insertedIds,
    required this.skippedExistingIds,
    required this.completedStepIds,
  });

  final List<String> insertedIds;
  final List<String> skippedExistingIds;

  /// Canonical headers that already existed with empty steps and were completed.
  final List<String> completedStepIds;

  int get consideredCount =>
      insertedIds.length + skippedExistingIds.length + completedStepIds.length;
}

/// Thrown when a colliding TMP-* row is not an official Cohort template, or
/// when an existing canonical row has a corrupt/partial step set.
class CohortSessionTemplateSeedConflictException implements Exception {
  const CohortSessionTemplateSeedConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persistence boundary for canonical template seeding (testable, not UI-bound).
abstract class CohortSessionTemplateSeedStore {
  Future<ProtocolDraft?> load(String protocolId);

  /// Inserts only when the ID is absent. Must not update existing rows.
  Future<void> insertIfAbsent(ProtocolDraft draft);

  /// Completes steps for an existing official template that has zero steps.
  /// Must not rewrite classification or non-empty step sets.
  Future<void> completeStepsIfEmpty(ProtocolDraft fullTemplate);
}

/// In-memory seed store for unit tests and local fixtures.
class InMemoryCohortSessionTemplateSeedStore
    implements CohortSessionTemplateSeedStore {
  final Map<String, ProtocolDraft> rows = {};

  @override
  Future<ProtocolDraft?> load(String protocolId) async {
    return rows[protocolId.trim()];
  }

  @override
  Future<void> insertIfAbsent(ProtocolDraft draft) async {
    final id = draft.protocolId.trim();
    if (rows.containsKey(id)) return;
    rows[id] = draft;
  }

  @override
  Future<void> completeStepsIfEmpty(ProtocolDraft fullTemplate) async {
    final id = fullTemplate.protocolId.trim();
    final existing = rows[id];
    if (existing == null) return;
    if (!TrainingContentClassification.isCanonicalSessionTemplate(existing)) {
      return;
    }
    if (existing.steps.isNotEmpty) return;
    rows[id] = fullTemplate;
  }
}

/// Applies the [CohortSessionTemplateCatalogue] idempotently.
///
/// Rules:
/// - Insert missing canonical templates only
/// - Refuse wrong-classification ID collisions (no silent masquerade)
/// - Complete empty step sets for official templates; refuse partial/corrupt sets
/// - Never overwrite coach-owned sessions or Cohort Protocols
/// - Not invoked from normal app startup
class CohortSessionTemplateSeedService {
  const CohortSessionTemplateSeedService({
    required CohortSessionTemplateSeedStore store,
  }) : _store = store;

  final CohortSessionTemplateSeedStore _store;

  Future<CohortSessionTemplateSeedResult> seedCanonicalTemplates({
    List<ProtocolDraft>? catalogue,
  }) async {
    final templates = catalogue ?? CohortSessionTemplateCatalogue.all();
    final inserted = <String>[];
    final skippedExisting = <String>[];
    final completedSteps = <String>[];

    for (final template in templates) {
      final id = template.protocolId.trim();
      if (!CohortSessionTemplateCatalogue.isCanonicalSeedId(id)) {
        throw ArgumentError('Refusing to seed non-canonical template id: $id');
      }
      if (!TrainingContentClassification.isCanonicalSessionTemplate(template)) {
        throw ArgumentError(
          'Seed catalogue entry $id must be a full official Cohort template.',
        );
      }

      final existing = await _store.load(id);
      if (existing == null) {
        await _store.insertIfAbsent(template);
        final after = await _store.load(id);
        if (after != null) {
          inserted.add(id);
        }
        continue;
      }

      if (!TrainingContentClassification.isCanonicalSessionTemplate(existing)) {
        throw CohortSessionTemplateSeedConflictException(
          'Canonical template seed conflict for $id: existing row is not an '
          'official Cohort template and will not be overwritten.',
        );
      }

      if (existing.steps.isEmpty && template.steps.isNotEmpty) {
        await _store.completeStepsIfEmpty(template);
        final after = await _store.load(id);
        if (after != null && after.steps.length == template.steps.length) {
          completedSteps.add(id);
        } else {
          throw CohortSessionTemplateSeedConflictException(
            'Canonical template seed conflict for $id: failed to complete '
            'empty step set.',
          );
        }
        continue;
      }

      if (existing.steps.length != template.steps.length) {
        throw CohortSessionTemplateSeedConflictException(
          'Canonical template seed conflict for $id: expected '
          '${template.steps.length} steps but found ${existing.steps.length}.',
        );
      }

      skippedExisting.add(id);
    }

    return CohortSessionTemplateSeedResult(
      insertedIds: inserted,
      skippedExistingIds: skippedExisting,
      completedStepIds: completedSteps,
    );
  }
}
