/// Exercise Knowledge Authority — domain contracts and repository boundary.
///
/// Canonical identity: `EX-*` only.
/// Does not own programme prescription, completion evidence, or adaptation
/// application. Live consumers are not migrated in Phase 3.1B/3.1C.
/// Production persistence is deferred (no schema migration in 3.1C).
library;

export 'in_memory/in_memory_exercise_knowledge_repository.dart';
export 'models/alias_resolution.dart';
export 'models/comparison_compatibility.dart';
export 'models/comparison_protocol.dart';
export 'models/equipment_requirement.dart';
export 'models/environment_suitability.dart';
export 'models/exercise_catalogue_snapshot.dart';
export 'models/exercise_definition.dart';
export 'models/exercise_definition_lookup.dart';
export 'models/exercise_relationship.dart';
export 'models/knowledge_reference.dart';
export 'models/substitution_constraint.dart';
export 'ports/exercise_knowledge_repository.dart';
export 'ports/transitional_exercise_id_bridge.dart';
export 'services/exercise_catalogue_snapshot_loader.dart';
export 'services/exercise_knowledge_publication_service.dart';
export 'validation/exercise_knowledge_validation_issue.dart';
export 'validation/exercise_knowledge_validator.dart';
export 'value_objects/exercise_id.dart';
export 'vocabulary/exercise_impact_level.dart';
export 'vocabulary/exercise_laterality.dart';
export 'vocabulary/exercise_lifecycle_status.dart';
export 'vocabulary/exercise_modality.dart';
export 'vocabulary/exercise_relationship_type.dart';
export 'vocabulary/exercise_technical_complexity.dart';
export 'vocabulary/performance_dimension.dart';
