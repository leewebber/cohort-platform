/// Authored Plan Package compiler foundation (Phase 1 / Sprint 1.1).
///
/// Production programme direction: [ProgrammeLineage] + immutable
/// [ProgrammeVersion] + Session Revisions.
///
/// **Must not** depend on legacy generative [PlanDefinition] / Coach Brain
/// workout generation. See `docs/architecture/Authored_Plan_Package_v1.md`.
library;

export 'plan_package_canonicaliser.dart';
export 'plan_package_compiler.dart';
export 'plan_package_manifest.dart';
export 'plan_package_schema.dart';
export 'plan_package_validation_issue.dart';
export 'plan_package_validator.dart';
export 'plan_package_yaml_parser.dart';
