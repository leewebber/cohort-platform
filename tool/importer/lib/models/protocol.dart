class Protocol {
  final String protocolId;
  final String name;
  final String? goal;
  final String? equipment;
  final int? durationMin;
  final String? capability;
  final String? demand;
  final String? recovery;
  final String? description;
  final String? mainSession;
  final String? coachingNotes;
  final String? trainingQuality;
  final String? sessionType;
  final String? environment;
  final String? suitableFor;
  final String? durationCategory;
  final String? technicalComplexity;
  final String? secondaryCapability;
  final String? requiredEquipment;
  final String? optionalEquipment;
  final int? adaptability;
  final bool? runningRequired;
  final bool? runningReplaceable;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final bool? noiseFriendly;

  const Protocol({
    required this.protocolId,
    required this.name,
    this.goal,
    this.equipment,
    this.durationMin,
    this.capability,
    this.demand,
    this.recovery,
    this.description,
    this.mainSession,
    this.coachingNotes,
    this.trainingQuality,
    this.sessionType,
    this.environment,
    this.suitableFor,
    this.durationCategory,
    this.technicalComplexity,
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

  factory Protocol.fromMap(Map<String, dynamic> map) {
    return Protocol(
      protocolId: map['protocol_id'] ?? '',
      name: map['name'] ?? '',
      goal: map['primary_capability'],
      equipment: map['equipment'],
      durationMin: map['duration_min'],
      capability: map['body_focus'],
      demand: map['physiological_demand'],
      recovery: map['recovery_cost'],
      description: map['purpose'],
      mainSession: map['main_session'] ?? map['original_workout'],
      coachingNotes: map['coaching_notes'],
      trainingQuality: map['training_quality'],
      sessionType: map['session_type'],
      environment: map['environment'],
      suitableFor: map['suitable_for'],
      durationCategory: map['duration_category'],
      technicalComplexity: map['technical_complexity'],
      secondaryCapability: map['secondary_capability'],
      requiredEquipment: map['required_equipment'],
      optionalEquipment: map['optional_equipment'],
      adaptability: _nullableInt(map['adaptability']),
      runningRequired: _nullableBool(map['running_required']),
      runningReplaceable: _nullableBool(map['running_replaceable']),
      hotelFriendly: _nullableBool(map['hotel_friendly']),
      indoorFriendly: _nullableBool(map['indoor_friendly']),
      noiseFriendly: _nullableBool(map['noise_friendly']),
    );
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool? _nullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 't' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'f' || normalized == '0') {
      return false;
    }
    return null;
  }
}