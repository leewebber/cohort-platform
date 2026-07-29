import '../domain/adaptation/adaptation_domain.dart';
import 'session_adaptation_metadata_codec.dart';

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
  final SessionIntent? primarySessionIntent;
  final List<SessionIntent> secondarySessionIntents;
  final int? minimumViableDurationMin;

  Protocol({
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
    this.primarySessionIntent,
    List<SessionIntent>? secondarySessionIntents,
    int? minimumViableDurationMin,
  }) : secondarySessionIntents =
           SessionAdaptationMetadataCodec.canonicalizeSecondaries(
             primary: primarySessionIntent,
             secondary:
                 secondarySessionIntents ??
                 SessionAdaptationMetadataCodec.emptySecondaries,
           ),
       minimumViableDurationMin =
           SessionAdaptationMetadataCodec.normalizeMinimumViableDurationMin(
             minimumViableDurationMin,
           );

  factory Protocol.fromMap(Map<String, dynamic> map) {
    final primary = SessionAdaptationMetadataCodec.parsePrimary(
      map[SessionAdaptationMetadataKeys.primarySessionIntent],
    );
    final secondary = SessionAdaptationMetadataCodec.parseSecondaryList(
      map[SessionAdaptationMetadataKeys.secondarySessionIntents],
    );
    final minDuration =
        SessionAdaptationMetadataCodec.parseMinimumViableDurationMin(
          map[SessionAdaptationMetadataKeys.minimumViableDurationMin],
        );

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
      primarySessionIntent: primary,
      secondarySessionIntents:
          SessionAdaptationMetadataCodec.canonicalizeSecondaries(
            primary: primary,
            secondary: secondary,
          ),
      minimumViableDurationMin: minDuration,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'protocol_id': protocolId,
      'name': name,
      'primary_capability': goal,
      'equipment': equipment,
      'duration_min': durationMin,
      'body_focus': capability,
      'physiological_demand': demand,
      'recovery_cost': recovery,
      'purpose': description,
      'main_session': mainSession,
      'coaching_notes': coachingNotes,
      'training_quality': trainingQuality,
      'session_type': sessionType,
      'environment': environment,
      'suitable_for': suitableFor,
      'duration_category': durationCategory,
      'technical_complexity': technicalComplexity,
      'secondary_capability': secondaryCapability,
      'required_equipment': requiredEquipment,
      'optional_equipment': optionalEquipment,
      'adaptability': adaptability,
      'running_required': runningRequired,
      'running_replaceable': runningReplaceable,
      'hotel_friendly': hotelFriendly,
      'indoor_friendly': indoorFriendly,
      'noise_friendly': noiseFriendly,
    };

    SessionAdaptationMetadataCodec.writeToMap(
      target: map,
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      minimumViableDurationMin: minimumViableDurationMin,
    );

    return map;
  }

  Protocol copyWith({
    String? protocolId,
    String? name,
    String? goal,
    String? equipment,
    int? durationMin,
    String? capability,
    String? demand,
    String? recovery,
    String? description,
    String? mainSession,
    String? coachingNotes,
    String? trainingQuality,
    String? sessionType,
    String? environment,
    String? suitableFor,
    String? durationCategory,
    String? technicalComplexity,
    String? secondaryCapability,
    String? requiredEquipment,
    String? optionalEquipment,
    int? adaptability,
    bool? runningRequired,
    bool? runningReplaceable,
    bool? hotelFriendly,
    bool? indoorFriendly,
    bool? noiseFriendly,
    SessionIntent? primarySessionIntent,
    List<SessionIntent>? secondarySessionIntents,
    int? minimumViableDurationMin,
    bool clearPrimarySessionIntent = false,
    bool clearSecondarySessionIntents = false,
    bool clearMinimumViableDurationMin = false,
  }) {
    final resolvedPrimary = clearPrimarySessionIntent
        ? null
        : (primarySessionIntent ?? this.primarySessionIntent);
    final resolvedSecondary = clearSecondarySessionIntents
        ? SessionAdaptationMetadataCodec.emptySecondaries
        : (secondarySessionIntents ?? this.secondarySessionIntents);
    final resolvedMin = clearMinimumViableDurationMin
        ? null
        : SessionAdaptationMetadataCodec.normalizeMinimumViableDurationMin(
            minimumViableDurationMin ?? this.minimumViableDurationMin,
          );

    return Protocol(
      protocolId: protocolId ?? this.protocolId,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      equipment: equipment ?? this.equipment,
      durationMin: durationMin ?? this.durationMin,
      capability: capability ?? this.capability,
      demand: demand ?? this.demand,
      recovery: recovery ?? this.recovery,
      description: description ?? this.description,
      mainSession: mainSession ?? this.mainSession,
      coachingNotes: coachingNotes ?? this.coachingNotes,
      trainingQuality: trainingQuality ?? this.trainingQuality,
      sessionType: sessionType ?? this.sessionType,
      environment: environment ?? this.environment,
      suitableFor: suitableFor ?? this.suitableFor,
      durationCategory: durationCategory ?? this.durationCategory,
      technicalComplexity: technicalComplexity ?? this.technicalComplexity,
      secondaryCapability: secondaryCapability ?? this.secondaryCapability,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      optionalEquipment: optionalEquipment ?? this.optionalEquipment,
      adaptability: adaptability ?? this.adaptability,
      runningRequired: runningRequired ?? this.runningRequired,
      runningReplaceable: runningReplaceable ?? this.runningReplaceable,
      hotelFriendly: hotelFriendly ?? this.hotelFriendly,
      indoorFriendly: indoorFriendly ?? this.indoorFriendly,
      noiseFriendly: noiseFriendly ?? this.noiseFriendly,
      primarySessionIntent: resolvedPrimary,
      secondarySessionIntents: resolvedSecondary,
      minimumViableDurationMin: resolvedMin,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Protocol &&
        other.protocolId == protocolId &&
        other.primarySessionIntent == primarySessionIntent &&
        _listEquals(other.secondarySessionIntents, secondarySessionIntents) &&
        other.minimumViableDurationMin == minimumViableDurationMin;
  }

  @override
  int get hashCode => Object.hash(
    protocolId,
    primarySessionIntent,
    Object.hashAll(secondarySessionIntents),
    minimumViableDurationMin,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
