/// Canonical adaptation domain (pure Dart — no UI or persistence wiring).
library;

export 'vocabulary/adaptation_vocabulary.dart';
export 'contracts/adaptation_constraint.dart';
export 'contracts/adaptation_constraint_kind.dart';
export 'contracts/block_adaptation_policy.dart';
export 'contracts/minimum_viable_prescription.dart';
export 'contracts/adaptation_action.dart';
export 'contracts/adaptation_validation_result.dart';
export 'contracts/adaptation_metadata_contracts.dart';
export 'mapping/adaptation_reason_mapping.dart';
export 'mapping/session_block_type_adaptation_policy.dart';
export 'evaluation/adaptation_constraint_context.dart';
export 'evaluation/adaptation_evaluation_result.dart';
export 'evaluation/planned_session_adaptation_input_factory.dart';
export 'evaluation/session_adaptation_read_only_evaluator.dart';
export 'planning/adaptation_plan_result.dart';
export 'planning/adaptation_plan_rationale.dart';
export 'planning/adaptation_plan_step.dart';
export 'planning/adaptation_plan_validator.dart';
export 'planning/prescription_reduction_proposal.dart';
export 'planning/session_adaptation_planner.dart';
export 'application/adaptation_plan_application_result.dart';
export 'application/adaptation_plan_applier.dart';
export 'application/adapted_session_execution_snapshot.dart';
export 'application/adapted_session_execution_snapshot_validator.dart';
export 'application/prescription_execution_snapshot.dart';
