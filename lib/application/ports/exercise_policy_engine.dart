import '../../planning/exercise_policy/models/exercise_policy_models.dart';

/// Converts [SessionBlueprint] into semantic movement selections (ADR-025).
abstract interface class ExercisePolicyEngine {
  ExercisePolicyResult evaluate(ExercisePolicyRequest request);
}
