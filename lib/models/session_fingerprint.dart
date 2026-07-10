/// Experiential signature of a protocol session (v1).
///
/// Derived from protocol metadata, steps, exercises, and [MovementProfile].
/// Fingerprints are stable for a given protocol version and comparable across
/// sessions for adaptation similarity ranking.
class SessionFingerprint {
  const SessionFingerprint({
    required this.structureType,
    required this.pacingStyle,
    required this.dominantStimulus,
    required this.equipmentDependency,
    required this.movementBias,
    required this.transitionDensity,
    required this.substitutionDifficulty,
  });

  final SessionStructureType structureType;
  final SessionPacingStyle pacingStyle;
  final DominantStimulus dominantStimulus;
  final EquipmentDependency equipmentDependency;
  final MovementBias movementBias;
  final TransitionDensity transitionDensity;
  final SubstitutionDifficulty substitutionDifficulty;

  @override
  String toString() {
    return 'SessionFingerprint('
        'structureType: $structureType, '
        'pacingStyle: $pacingStyle, '
        'dominantStimulus: $dominantStimulus, '
        'equipmentDependency: $equipmentDependency, '
        'movementBias: $movementBias, '
        'transitionDensity: $transitionDensity, '
        'substitutionDifficulty: $substitutionDifficulty'
        ')';
  }
}

/// How work is organised within the session.
enum SessionStructureType {
  circuit,
  amrap,
  emom,
  intervals,
  strength,
  continuous,
  unknown,
}

/// How effort is distributed across the session.
enum SessionPacingStyle {
  steady,
  interval,
  density,
  maxEffort,
  controlled,
  unknown,
}

/// Primary training feel signalled by metadata.
enum DominantStimulus {
  capacity,
  engine,
  threshold,
  speed,
  strength,
  hypertrophy,
  recovery,
  mobility,
  mixed,
  unknown,
}

/// How tightly the session depends on specific equipment.
enum EquipmentDependency {
  low,
  moderate,
  high,
}

/// Dominant movement emphasis from step distribution.
enum MovementBias {
  balanced,
  upperBody,
  lowerBody,
  runningDominant,
  pushDominant,
  pullDominant,
  mixed,
}

/// How frequently the athlete changes task or modality.
enum TransitionDensity {
  low,
  moderate,
  high,
}

/// How resistant the session is to movement swaps.
enum SubstitutionDifficulty {
  low,
  moderate,
  high,
}
