import 'protocol_step_draft.dart';

/// Editable in-memory representation of a protocol before save.
///
/// Maps to `performance_protocols` and a list of [ProtocolStepDraft] rows.
/// See `07 Documentation/34_Protocol_Builder.md`.
class ProtocolDraft {
  const ProtocolDraft({
    required this.protocolId,
    required this.name,
    required this.steps,
    this.published = false,
    this.primaryCapability,
    this.secondaryCapability,
    this.sessionType,
    this.sessionFormat,
    this.durationMin,
    this.durationCategory,
    this.physiologicalDemand,
    this.recoveryCost,
    this.technicalComplexity,
    this.environment,
    this.requiredEquipment,
    this.optionalEquipment,
    this.suitableFor,
    this.adaptability,
    this.runningRequired,
    this.runningReplaceable,
    this.hotelFriendly,
    this.indoorFriendly,
    this.noiseFriendly,
    this.coachingNotes,
    this.purpose,
  });

  final String protocolId;
  final String name;
  final List<ProtocolStepDraft> steps;
  final bool published;

  final String? primaryCapability;
  final String? secondaryCapability;
  final String? sessionType;
  final String? sessionFormat;
  final int? durationMin;
  final String? durationCategory;
  final String? physiologicalDemand;
  final String? recoveryCost;
  final String? technicalComplexity;
  final String? environment;
  final String? requiredEquipment;
  final String? optionalEquipment;
  final String? suitableFor;
  final int? adaptability;
  final bool? runningRequired;
  final bool? runningReplaceable;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final bool? noiseFriendly;
  final String? coachingNotes;
  final String? purpose;

  ProtocolDraft copyWith({
    String? protocolId,
    String? name,
    List<ProtocolStepDraft>? steps,
    bool? published,
    String? primaryCapability,
    String? secondaryCapability,
    String? sessionType,
    String? sessionFormat,
    int? durationMin,
    String? durationCategory,
    String? physiologicalDemand,
    String? recoveryCost,
    String? technicalComplexity,
    String? environment,
    String? requiredEquipment,
    String? optionalEquipment,
    String? suitableFor,
    int? adaptability,
    bool? runningRequired,
    bool? runningReplaceable,
    bool? hotelFriendly,
    bool? indoorFriendly,
    bool? noiseFriendly,
    String? coachingNotes,
    String? purpose,
  }) {
    return ProtocolDraft(
      protocolId: protocolId ?? this.protocolId,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      published: published ?? this.published,
      primaryCapability: primaryCapability ?? this.primaryCapability,
      secondaryCapability: secondaryCapability ?? this.secondaryCapability,
      sessionType: sessionType ?? this.sessionType,
      sessionFormat: sessionFormat ?? this.sessionFormat,
      durationMin: durationMin ?? this.durationMin,
      durationCategory: durationCategory ?? this.durationCategory,
      physiologicalDemand: physiologicalDemand ?? this.physiologicalDemand,
      recoveryCost: recoveryCost ?? this.recoveryCost,
      technicalComplexity: technicalComplexity ?? this.technicalComplexity,
      environment: environment ?? this.environment,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      optionalEquipment: optionalEquipment ?? this.optionalEquipment,
      suitableFor: suitableFor ?? this.suitableFor,
      adaptability: adaptability ?? this.adaptability,
      runningRequired: runningRequired ?? this.runningRequired,
      runningReplaceable: runningReplaceable ?? this.runningReplaceable,
      hotelFriendly: hotelFriendly ?? this.hotelFriendly,
      indoorFriendly: indoorFriendly ?? this.indoorFriendly,
      noiseFriendly: noiseFriendly ?? this.noiseFriendly,
      coachingNotes: coachingNotes ?? this.coachingNotes,
      purpose: purpose ?? this.purpose,
    );
  }

  /// Maps coach-editable protocol fields to `performance_protocols` columns.
  Map<String, dynamic> toProtocolMap() {
    return {
      'protocol_id': protocolId,
      'name': name,
      'primary_capability': _nullableString(primaryCapability),
      'secondary_capability': _nullableString(secondaryCapability),
      'session_type': _nullableString(sessionType),
      'duration_min': durationMin,
      'duration_category': _nullableString(durationCategory),
      'physiological_demand': _nullableString(physiologicalDemand),
      'recovery_cost': _nullableString(recoveryCost),
      'technical_complexity': _nullableString(technicalComplexity),
      'environment': _nullableString(environment),
      'required_equipment': _nullableString(requiredEquipment),
      'optional_equipment': _nullableString(optionalEquipment),
      'suitable_for': _nullableString(suitableFor),
      'adaptability': adaptability,
      'running_required': runningRequired,
      'running_replaceable': runningReplaceable,
      'hotel_friendly': hotelFriendly,
      'indoor_friendly': indoorFriendly,
      'noise_friendly': noiseFriendly,
      'coaching_notes': _nullableString(coachingNotes),
      'purpose': _nullableString(purpose),
    };
  }

  static String? _nullableString(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
