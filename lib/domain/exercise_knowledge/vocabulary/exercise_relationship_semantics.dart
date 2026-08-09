import 'exercise_relationship_type.dart';

/// Authored semantics for [ExerciseRelationshipType] — documentation + guards.
///
/// Does not invent symmetry, inverses, equivalence, or comparability.
class ExerciseRelationshipSemantics {
  const ExerciseRelationshipSemantics(this.type);

  final ExerciseRelationshipType type;

  /// All current types are authored directional edges.
  bool get isDirectional => true;

  /// No type is treated as automatically symmetric.
  bool get isExplicitlySymmetric => false;

  /// Inverse must be authored as a separate relationship record.
  bool get inverseMustBeAuthoredSeparately => true;

  /// Bounded typed traversal is meaningful for discovery (not selection).
  bool get traversalMeaningful => true;

  /// Cycles are not globally forbidden for this type.
  bool get forbidsCycles => false;

  String get sourceMeaning => switch (type) {
        ExerciseRelationshipType.progression =>
          'Source is the easier / less advanced movement.',
        ExerciseRelationshipType.regression =>
          'Source is the primary / more advanced movement.',
        ExerciseRelationshipType.lateralAlternative =>
          'Source exercise for which a lateral alternative is authored.',
        ExerciseRelationshipType.equipmentAlternative =>
          'Source exercise that may have an equipment-limited alternative.',
        ExerciseRelationshipType.environmentAlternative =>
          'Source exercise that may have an environment-limited alternative.',
        ExerciseRelationshipType.relatedNonComparable =>
          'Source of a related but explicitly non-comparable connection.',
        ExerciseRelationshipType.directlyComparableVariant =>
          'Source of an explicitly comparable variant (protocol required).',
      };

  String get targetMeaning => switch (type) {
        ExerciseRelationshipType.progression =>
          'Target is a progression of the source.',
        ExerciseRelationshipType.regression =>
          'Target is a regression of the source.',
        ExerciseRelationshipType.lateralAlternative =>
          'Target is a lateral alternative of the source.',
        ExerciseRelationshipType.equipmentAlternative =>
          'Target may preserve intent under different equipment.',
        ExerciseRelationshipType.environmentAlternative =>
          'Target may preserve intent under a different environment.',
        ExerciseRelationshipType.relatedNonComparable =>
          'Target is related but not comparable by default.',
        ExerciseRelationshipType.directlyComparableVariant =>
          'Target may share a series only via an explicit comparison protocol.',
      };

  /// Explicit non-authorities for every relationship type.
  List<String> get nonAuthorities => const [
        'Does not select or apply a substitution',
        'Does not rewrite a programme or session',
        'Does not grant comparison compatibility by adjacency',
        'Does not merge performance evidence',
        'Does not rank candidates',
        'Does not bypass athlete agreement',
      ];
}

extension ExerciseRelationshipTypeSemantics on ExerciseRelationshipType {
  ExerciseRelationshipSemantics get semantics =>
      ExerciseRelationshipSemantics(this);
}
