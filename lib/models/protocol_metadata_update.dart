class ProtocolMetadataUpdate {
  const ProtocolMetadataUpdate({
    this.primaryCapability,
    this.sessionType,
    this.equipment,
    this.environment,
    this.physiologicalDemand,
    this.recoveryCost,
    this.durationMin,
    this.durationCategory,
    this.technicalComplexity,
    this.suitableFor,
    this.secondaryCapability,
    this.requiredEquipment,
    this.optionalEquipment,
    this.adaptability,
    this.runningRequired,
    this.runningReplaceable,
    this.hotelFriendly,
    this.indoorFriendly,
    this.noiseFriendly,
  });

  final String? primaryCapability;
  final String? sessionType;
  final String? equipment;
  final String? environment;
  final String? physiologicalDemand;
  final String? recoveryCost;
  final int? durationMin;
  final String? durationCategory;
  final String? technicalComplexity;
  final String? suitableFor;
  final String? secondaryCapability;
  final String? requiredEquipment;
  final String? optionalEquipment;
  final int? adaptability;
  final bool? runningRequired;
  final bool? runningReplaceable;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final bool? noiseFriendly;

  Map<String, dynamic> toUpdateMap() {
    return {
      'primary_capability': _nullableString(primaryCapability),
      'session_type': _nullableString(sessionType),
      'equipment': _nullableString(equipment),
      'environment': _nullableString(environment),
      'physiological_demand': _nullableString(physiologicalDemand),
      'recovery_cost': _nullableString(recoveryCost),
      'duration_min': durationMin,
      'duration_category': _nullableString(durationCategory),
      'technical_complexity': _nullableString(technicalComplexity),
      'suitable_for': _nullableString(suitableFor),
      'secondary_capability': _nullableString(secondaryCapability),
      'required_equipment': _nullableString(requiredEquipment),
      'optional_equipment': _nullableString(optionalEquipment),
      'adaptability': adaptability,
      'running_required': runningRequired,
      'running_replaceable': runningReplaceable,
      'hotel_friendly': hotelFriendly,
      'indoor_friendly': indoorFriendly,
      'noise_friendly': noiseFriendly,
    };
  }

  static String? _nullableString(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
