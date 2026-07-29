import '../vocabulary/session_intent.dart';
import 'adaptation_constraint.dart';

/// Result of validating a proposed adaptation plan against constraints and intent.
class AdaptationValidationResult {
  const AdaptationValidationResult({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
    this.retainedPrimaryIntent,
    this.retainedSecondaryIntent,
    this.unresolvedConstraints = const [],
  });

  final bool valid;
  final List<String> errors;
  final List<String> warnings;
  final SessionIntent? retainedPrimaryIntent;
  final SessionIntent? retainedSecondaryIntent;
  final List<AdaptationConstraint> unresolvedConstraints;

  Map<String, dynamic> toJson() {
    return {
      'valid': valid,
      if (errors.isNotEmpty) 'errors': errors,
      if (warnings.isNotEmpty) 'warnings': warnings,
      if (retainedPrimaryIntent != null)
        'retained_primary_intent': retainedPrimaryIntent!.dbValue,
      if (retainedSecondaryIntent != null)
        'retained_secondary_intent': retainedSecondaryIntent!.dbValue,
      if (unresolvedConstraints.isNotEmpty)
        'unresolved_constraints': unresolvedConstraints
            .map((c) => c.toJson())
            .toList(),
    };
  }

  factory AdaptationValidationResult.fromJson(Map<String, dynamic> json) {
    final constraintsRaw = json['unresolved_constraints'];
    final constraints = <AdaptationConstraint>[];
    if (constraintsRaw is List) {
      for (final entry in constraintsRaw) {
        if (entry is Map<String, dynamic>) {
          constraints.add(AdaptationConstraint.fromJson(entry));
        } else if (entry is Map) {
          constraints.add(
            AdaptationConstraint.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    return AdaptationValidationResult(
      valid: json['valid'] == true,
      errors: _stringList(json['errors']),
      warnings: _stringList(json['warnings']),
      retainedPrimaryIntent: SessionIntentDb.fromDb(
        json['retained_primary_intent']?.toString(),
      ),
      retainedSecondaryIntent: SessionIntentDb.fromDb(
        json['retained_secondary_intent']?.toString(),
      ),
      unresolvedConstraints: constraints,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
