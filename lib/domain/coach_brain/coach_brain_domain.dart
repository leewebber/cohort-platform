/// Coach Brain domain — pure Dart routing framework (no UI, persistence, or adaptation engine).
library;

export 'composition/coach_brain_dependencies.dart';
export 'contracts/coach_decision_context.dart';
export 'contracts/coach_decision_request.dart';
export 'contracts/coach_decision_result.dart';
export 'handlers/coach_decision_handler.dart';
export 'handlers/stub_coach_decision_handlers.dart';
export 'routing/coach_decision_handler_registry.dart';
export 'routing/coach_decision_router.dart';
export 'session_adaptation/session_adaptation_coach_decision_context.dart';
export 'session_adaptation/session_adaptation_coach_decision_failure_code.dart';
export 'session_adaptation/session_adaptation_coach_decision_handler.dart';
export 'session_adaptation/session_adaptation_pipeline.dart';
export 'vocabulary/coach_decision_type.dart';
