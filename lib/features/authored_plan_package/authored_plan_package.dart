/// Authored Plan Package compiler + import foundation (Phase 1).
///
/// Production programme direction: `ProgrammeLineage` + immutable
/// `ProgrammeVersion` + Session Revisions.
///
/// **Must not** depend on legacy generative PlanDefinition / Coach Brain
/// workout generation. See `docs/architecture/Authored_Plan_Package_v1.md`.
library;

export 'import/plan_package_catalogue_approval_service.dart';
export 'import/plan_package_existing_version_lookup.dart';
export 'import/plan_package_import_models.dart';
export 'import/plan_package_import_payload_builder.dart';
export 'import/plan_package_import_preview_service.dart';
export 'import/plan_package_import_service.dart';
export 'import/plan_package_import_store.dart';
export 'import/plan_package_import_supabase_store.dart';
export 'import/plan_package_session_resolver.dart';
export 'import/plan_package_session_supabase_resolver.dart';
export 'plan_package_canonicaliser.dart';
export 'plan_package_compiler.dart';
export 'plan_package_manifest.dart';
export 'plan_package_schema.dart';
export 'plan_package_validation_issue.dart';
export 'plan_package_validator.dart';
export 'plan_package_yaml_parser.dart';
