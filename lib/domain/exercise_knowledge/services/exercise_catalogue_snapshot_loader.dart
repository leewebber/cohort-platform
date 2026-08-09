import '../models/exercise_catalogue_snapshot.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../validation/exercise_knowledge_validator.dart';

/// Load + validate an immutable catalogue snapshot from JSON-like maps.
///
/// Fail-closed: invalid catalogues are not returned as loadable snapshots.
class ExerciseCatalogueSnapshotLoader {
  const ExerciseCatalogueSnapshotLoader({
    this.validator = const ExerciseKnowledgeValidator(),
  });

  final ExerciseKnowledgeValidator validator;

  ExerciseCatalogueLoadResult load(Map<String, Object?> json) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    late final ExerciseCatalogueSnapshot snapshot;
    try {
      snapshot = ExerciseCatalogueSnapshot.fromJson(json);
    } on FormatException catch (e) {
      return ExerciseCatalogueLoadResult.invalid([
        ExerciseKnowledgeValidationIssue(
          path: 'catalogue',
          message: e.message,
          code: 'catalogue_parse_failed',
        ),
      ]);
    }

    if (snapshot.catalogueVersion.trim().isEmpty) {
      issues.add(
        const ExerciseKnowledgeValidationIssue(
          path: 'catalogue_version',
          message: 'Catalogue version must not be blank.',
          code: 'blank_catalogue_version',
        ),
      );
    }

    issues.addAll(
      validator.validateCatalogue(
        definitions: snapshot.definitions,
        relationships: snapshot.relationships,
        comparisonProtocols: snapshot.comparisonProtocols,
      ),
    );

    if (issues.isNotEmpty) {
      return ExerciseCatalogueLoadResult.invalid(issues);
    }
    return ExerciseCatalogueLoadResult.valid(snapshot);
  }
}

class ExerciseCatalogueLoadResult {
  const ExerciseCatalogueLoadResult._({
    required this.isValid,
    this.snapshot,
    this.issues = const [],
  });

  factory ExerciseCatalogueLoadResult.valid(ExerciseCatalogueSnapshot snapshot) =>
      ExerciseCatalogueLoadResult._(isValid: true, snapshot: snapshot);

  factory ExerciseCatalogueLoadResult.invalid(
    List<ExerciseKnowledgeValidationIssue> issues,
  ) =>
      ExerciseCatalogueLoadResult._(isValid: false, issues: issues);

  final bool isValid;
  final ExerciseCatalogueSnapshot? snapshot;
  final List<ExerciseKnowledgeValidationIssue> issues;
}
