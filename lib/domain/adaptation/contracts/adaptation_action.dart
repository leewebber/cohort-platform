import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/session_intent.dart';

/// A single explainable adaptation step applied to an entity.
class AdaptationAction {
  const AdaptationAction({
    required this.actionType,
    required this.targetScope,
    required this.targetId,
    required this.reason,
    this.originalReference,
    this.adaptedReference,
    this.expectedIntentImpact,
    this.explanation,
  });

  final AdaptationActionType actionType;
  final String targetScope;
  final String targetId;
  final String reason;
  final String? originalReference;
  final String? adaptedReference;
  final AdaptationFidelity? expectedIntentImpact;
  final String? explanation;

  Map<String, dynamic> toJson() {
    return {
      'action_type': actionType.dbValue,
      'target_scope': targetScope,
      'target_id': targetId,
      'reason': reason,
      if (originalReference != null) 'original_reference': originalReference,
      if (adaptedReference != null) 'adapted_reference': adaptedReference,
      if (expectedIntentImpact != null)
        'expected_intent_impact': expectedIntentImpact!.dbValue,
      if (explanation != null && explanation!.trim().isNotEmpty)
        'explanation': explanation!.trim(),
    };
  }

  factory AdaptationAction.fromJson(Map<String, dynamic> json) {
    return AdaptationAction(
      actionType: AdaptationActionTypeDb.fromDb(json['action_type']?.toString()) ??
          AdaptationActionType.adjustPrescription,
      targetScope: json['target_scope']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      originalReference: json['original_reference']?.toString(),
      adaptedReference: json['adapted_reference']?.toString(),
      expectedIntentImpact: AdaptationFidelityDb.fromDb(
        json['expected_intent_impact']?.toString(),
      ),
      explanation: json['explanation']?.toString(),
    );
  }
}

/// Qualitative assessment of intent preservation after one or more actions.
class AdaptationFidelityAssessment {
  const AdaptationFidelityAssessment({
    required this.fidelity,
    required this.primaryIntentRetained,
    required this.secondaryIntentRetained,
    this.compromisedCharacteristics = const [],
    this.explanationData = const {},
  });

  final AdaptationFidelity fidelity;
  final bool primaryIntentRetained;
  final bool secondaryIntentRetained;
  final List<String> compromisedCharacteristics;
  final Map<String, String> explanationData;

  Map<String, dynamic> toJson() {
    return {
      'fidelity': fidelity.dbValue,
      'primary_intent_retained': primaryIntentRetained,
      'secondary_intent_retained': secondaryIntentRetained,
      if (compromisedCharacteristics.isNotEmpty)
        'compromised_characteristics': compromisedCharacteristics,
      if (explanationData.isNotEmpty) 'explanation_data': explanationData,
    };
  }

  factory AdaptationFidelityAssessment.fromJson(Map<String, dynamic> json) {
    return AdaptationFidelityAssessment(
      fidelity: AdaptationFidelityDb.fromDb(json['fidelity']?.toString()) ??
          AdaptationFidelity.compromised,
      primaryIntentRetained: json['primary_intent_retained'] == true,
      secondaryIntentRetained: json['secondary_intent_retained'] == true,
      compromisedCharacteristics: _stringList(json['compromised_characteristics']),
      explanationData: _stringMap(json['explanation_data']),
    );
  }

  /// Derives a qualitative fidelity level from intent retention flags.
  factory AdaptationFidelityAssessment.fromIntentRetention({
    required SessionIntent? primaryIntent,
    required SessionIntent? secondaryIntent,
    required bool primaryRetained,
    required bool secondaryRetained,
    List<String> compromised = const [],
  }) {
    final fidelity = () {
      if (primaryRetained && secondaryRetained) return AdaptationFidelity.full;
      if (primaryRetained) return AdaptationFidelity.high;
      if (secondaryRetained) return AdaptationFidelity.moderate;
      return AdaptationFidelity.compromised;
    }();

    return AdaptationFidelityAssessment(
      fidelity: fidelity,
      primaryIntentRetained: primaryRetained,
      secondaryIntentRetained: secondaryRetained,
      compromisedCharacteristics: compromised,
      explanationData: {
        if (primaryIntent != null)
          'primary_intent': primaryIntent.dbValue,
        if (secondaryIntent != null)
          'secondary_intent': secondaryIntent.dbValue,
      },
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), val?.toString() ?? ''),
      );
    }
    return const {};
  }
}
