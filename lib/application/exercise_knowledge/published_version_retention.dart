import 'package:cohort_plan_package/cohort_plan_package.dart';
import '../../domain/exercise_knowledge/models/exercise_definition.dart';
import '../../domain/exercise_knowledge/models/exercise_definition_lookup.dart';
import '../../domain/exercise_knowledge/ports/exercise_knowledge_repository.dart';
import '../../domain/exercise_knowledge/validation/exercise_knowledge_validator.dart';
import '../../domain/exercise_knowledge/value_objects/exercise_id.dart';

/// An authorised publication producer resolves this event from its own approval
/// records. A submitted file, row snapshot or client digest is never that record.
abstract interface class ExerciseVersionPublicationAuthority {
  Future<Map<String, Object?>?> verifiedPublicationFor(
    ExerciseDefinition definition,
  );
}

typedef RetainPublishedExerciseVersion =
    Future<Map<String, Object?>> Function(
      String canonicalText,
      Map<String, Object?> verifiedPublication,
    );

/// Extends the accepted published lookup. Deliberately has no default Supabase
/// client: deployment must provision the unassigned trusted producer capability.
class PublishedExerciseVersionRetention {
  const PublishedExerciseVersionRetention({
    required this.lookup,
    required this.authority,
    required this.retain,
  });
  final ExerciseKnowledgeRepository lookup;
  final ExerciseVersionPublicationAuthority authority;
  final RetainPublishedExerciseVersion retain;

  Future<Map<String, Object?>> retainExact(
    ExerciseId id,
    String version,
  ) async {
    final found = lookup.getDefinition(
      id,
      visibility: ExerciseKnowledgeVisibility.operational,
    );
    final definition = found.definition;
    if (!found.isOperational ||
        definition == null ||
        definition.version != version ||
        definition.publishedAt == null ||
        definition.owner != 'founder' ||
        const ExerciseKnowledgeValidator()
            .validateDefinition(definition)
            .isNotEmpty) {
      throw StateError('Authoritative exact published version unavailable.');
    }
    final publication = await authority.verifiedPublicationFor(definition);
    if (publication == null) {
      throw StateError('Verified publication provenance unavailable.');
    }
    return retain(
      personalisationCanonicalJson(definition.toJson()),
      publication,
    );
  }
}
