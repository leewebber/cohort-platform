import '../../adaptation/vocabulary/training_environment.dart';
import '../models/exercise_relationship.dart';
import '../vocabulary/exercise_relationship_type.dart';

/// Supplied context for pure relationship eligibility evaluation.
///
/// Only fields justified by existing [SubstitutionConstraint] contracts.
/// Incomplete context yields [RelationshipEligibilityStatus.indeterminate]
/// (fail closed for selection — caller must not treat as eligible).
class RelationshipEligibilityContext {
  const RelationshipEligibilityContext({
    this.environment,
    this.availableEquipmentTokens,
    this.permittedRelationshipTypes,
    this.requiredCharacteristics,
    this.allowEmergencyOrRegressionOnly = true,
    this.blockedSportStandardIds = const <String>{},
  });

  final TrainingEnvironment? environment;

  /// Lowercase-normalized equipment tokens available in the context.
  final Set<String>? availableEquipmentTokens;

  final Set<ExerciseRelationshipType>? permittedRelationshipTypes;

  /// Characteristics that must remain among [mustPreserveCharacteristics].
  final Set<String>? requiredCharacteristics;

  final bool allowEmergencyOrRegressionOnly;

  /// Sport standards that make the substitution invalid when restricted.
  final Set<String> blockedSportStandardIds;
}

enum RelationshipEligibilityStatus {
  /// May be considered — never means selected.
  eligible,

  /// Explicitly not eligible under supplied context.
  ineligible,

  /// Context incomplete for a decisive answer — fail closed for selection.
  indeterminate,
}

class RelationshipEligibilityResult {
  const RelationshipEligibilityResult({
    required this.status,
    this.reasons = const [],
  });

  final RelationshipEligibilityStatus status;
  final List<String> reasons;

  bool get mayBeConsidered => status == RelationshipEligibilityStatus.eligible;

  /// Never implies automatic selection.
  bool get isSelected => false;
}

/// Deterministic eligibility evaluator — discovery constraint gate only.
class RelationshipEligibilityEvaluator {
  const RelationshipEligibilityEvaluator();

  RelationshipEligibilityResult evaluate({
    required ExerciseRelationship relationship,
    required RelationshipEligibilityContext context,
  }) {
    final reasons = <String>[];
    final constraint = relationship.substitutionConstraint;

    if (context.permittedRelationshipTypes != null &&
        !context.permittedRelationshipTypes!
            .contains(relationship.relationshipType)) {
      return RelationshipEligibilityResult(
        status: RelationshipEligibilityStatus.ineligible,
        reasons: [
          'Relationship type ${relationship.relationshipType.wireValue} '
              'is not permitted in context.',
        ],
      );
    }

    if (constraint.requiredRelationshipTypes.isNotEmpty &&
        !constraint.requiredRelationshipTypes
            .contains(relationship.relationshipType)) {
      return const RelationshipEligibilityResult(
        status: RelationshipEligibilityStatus.ineligible,
        reasons: ['Relationship type fails requiredRelationshipTypes.'],
      );
    }

    if (constraint.emergencyOrRegressionOnly &&
        !context.allowEmergencyOrRegressionOnly) {
      return const RelationshipEligibilityResult(
        status: RelationshipEligibilityStatus.ineligible,
        reasons: ['Emergency/regression-only relationship not allowed.'],
      );
    }

    // Environment
    if (constraint.requiredEnvironments.isNotEmpty ||
        constraint.forbiddenEnvironments.isNotEmpty) {
      final env = context.environment;
      if (env == null) {
        return const RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.indeterminate,
          reasons: ['Training environment context is required but missing.'],
        );
      }
      if (constraint.forbiddenEnvironments.contains(env)) {
        return RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.ineligible,
          reasons: ['Environment ${env.dbValue} is forbidden.'],
        );
      }
      if (constraint.requiredEnvironments.isNotEmpty &&
          !constraint.requiredEnvironments.contains(env)) {
        return RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.ineligible,
          reasons: ['Environment ${env.dbValue} is not among required.'],
        );
      }
    }

    // Equipment
    if (constraint.requiredEquipmentTokens.isNotEmpty ||
        constraint.forbiddenEquipmentTokens.isNotEmpty) {
      final available = context.availableEquipmentTokens;
      if (available == null) {
        return const RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.indeterminate,
          reasons: ['Equipment context is required but missing.'],
        );
      }
      final normalized = available.map(_norm).toSet();
      for (final forbidden in constraint.forbiddenEquipmentTokens) {
        if (normalized.contains(_norm(forbidden))) {
          return RelationshipEligibilityResult(
            status: RelationshipEligibilityStatus.ineligible,
            reasons: ['Forbidden equipment present: $forbidden'],
          );
        }
      }
      for (final required in constraint.requiredEquipmentTokens) {
        if (!normalized.contains(_norm(required))) {
          return RelationshipEligibilityResult(
            status: RelationshipEligibilityStatus.ineligible,
            reasons: ['Required equipment missing: $required'],
          );
        }
      }
    }

    // Characteristics
    if (constraint.mustPreserveCharacteristics.isNotEmpty &&
        context.requiredCharacteristics != null) {
      final must = constraint.mustPreserveCharacteristics.map(_norm).toSet();
      final required = context.requiredCharacteristics!.map(_norm).toSet();
      if (!required.every(must.contains)) {
        return const RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.ineligible,
          reasons: ['Required characteristics are not preserved by relationship.'],
        );
      }
    }

    // Sport standards
    for (final blocked in context.blockedSportStandardIds) {
      if (constraint.sportStandardRestrictionIds
          .map(_norm)
          .contains(_norm(blocked))) {
        return RelationshipEligibilityResult(
          status: RelationshipEligibilityStatus.ineligible,
          reasons: [
            'Blocked by sport-standard restriction: $blocked',
          ],
        );
      }
    }

    if (reasons.isEmpty) {
      return const RelationshipEligibilityResult(
        status: RelationshipEligibilityStatus.eligible,
        reasons: ['Authored relationship may be considered under context.'],
      );
    }
    return RelationshipEligibilityResult(
      status: RelationshipEligibilityStatus.eligible,
      reasons: reasons,
    );
  }
}

String _norm(String value) => value.trim().toLowerCase();
