/// Exercise Knowledge Authority — domain contracts, repository, and identity bridge.
///
/// Canonical identity: `EX-*` only.
/// Transitional `cohort.exercise.*` ids resolve only through the explicit bridge.
/// Does not own programme prescription, completion evidence, or adaptation
/// application. Live consumers are not migrated in Phase 3.1B–3.1D.
/// Phase 3.1F Part 2 authors local catalogue seed + identity mappings;
/// hosted apply and live-consumer migration remain separately authorised.
library;

export 'adapters/canonicalised_exercise_knowledge_adapter.dart';
export 'seed/founder_approved_identity_mappings_phase_3_1f.dart';
export 'graph/comparability_firewall.dart';
export 'graph/exercise_relationship_graph.dart';
export 'graph/relationship_eligibility.dart';
export 'in_memory/in_memory_exercise_knowledge_repository.dart';
export 'in_memory/in_memory_transitional_exercise_id_bridge.dart';
export 'models/alias_resolution.dart';
export 'models/coaching_content.dart';
export 'models/comparison_compatibility.dart';
export 'models/comparison_protocol.dart';
export 'models/equipment_requirement.dart';
export 'models/environment_suitability.dart';
export 'models/exercise_catalogue_snapshot.dart';
export 'models/exercise_definition.dart';
export 'models/exercise_definition_lookup.dart';
export 'models/exercise_identity_mapping.dart';
export 'models/exercise_movement_knowledge.dart';
export 'models/exercise_relationship.dart';
export 'models/knowledge_content_common.dart';
export 'models/knowledge_reference.dart';
export 'models/movement_standard.dart';
export 'models/substitution_constraint.dart';
export 'models/transitional_identity_resolution.dart';
export 'models/video_reference.dart';
export 'ports/exercise_knowledge_repository.dart';
export 'ports/transitional_exercise_id_bridge.dart';
export 'services/exercise_catalogue_snapshot_loader.dart';
export 'services/exercise_identity_mapping_publication_service.dart';
export 'services/exercise_knowledge_publication_service.dart';
export 'validation/exercise_identity_mapping_validator.dart';
export 'validation/exercise_knowledge_validation_issue.dart';
export 'validation/exercise_knowledge_validator.dart';
export 'validation/exercise_movement_content_validator.dart';
export 'value_objects/exercise_id.dart';
export 'value_objects/transitional_exercise_id.dart';
export 'vocabulary/exercise_impact_level.dart';
export 'vocabulary/exercise_laterality.dart';
export 'vocabulary/exercise_lifecycle_status.dart';
export 'vocabulary/exercise_modality.dart';
export 'vocabulary/exercise_relationship_semantics.dart';
export 'vocabulary/exercise_relationship_type.dart';
export 'vocabulary/exercise_technical_complexity.dart';
export 'vocabulary/performance_dimension.dart';
