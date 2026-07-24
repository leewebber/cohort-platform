/// Semantic purpose of a Session block (M6).
enum SessionBlockType {
  warmUp,
  strength,
  skill,
  accessory,
  conditioning,
  core,
  coolDown,
  custom,
}

extension SessionBlockTypeDb on SessionBlockType {
  String get dbValue {
    return switch (this) {
      SessionBlockType.warmUp => 'warm_up',
      SessionBlockType.strength => 'strength',
      SessionBlockType.skill => 'skill',
      SessionBlockType.accessory => 'accessory',
      SessionBlockType.conditioning => 'conditioning',
      SessionBlockType.core => 'core',
      SessionBlockType.coolDown => 'cool_down',
      SessionBlockType.custom => 'custom',
    };
  }

  String get displayLabel {
    return switch (this) {
      SessionBlockType.warmUp => 'Warm-up',
      SessionBlockType.strength => 'Strength',
      SessionBlockType.skill => 'Skill',
      SessionBlockType.accessory => 'Accessory',
      SessionBlockType.conditioning => 'Conditioning',
      SessionBlockType.core => 'Core',
      SessionBlockType.coolDown => 'Cool-down',
      SessionBlockType.custom => 'Custom',
    };
  }

  String get defaultTitle {
    return switch (this) {
      SessionBlockType.custom => 'Custom Block',
      _ => displayLabel,
    };
  }

  static SessionBlockType fromDb(String? value) {
    return switch (value?.trim()) {
      'warm_up' => SessionBlockType.warmUp,
      'strength' => SessionBlockType.strength,
      'skill' => SessionBlockType.skill,
      'accessory' => SessionBlockType.accessory,
      'conditioning' => SessionBlockType.conditioning,
      'core' => SessionBlockType.core,
      'cool_down' => SessionBlockType.coolDown,
      _ => SessionBlockType.custom,
    };
  }

  /// Block types that use structured exercise prescriptions (Sprint 10).
  bool get supportsStructuredStrengthPrescription {
    return this == SessionBlockType.strength ||
        this == SessionBlockType.accessory;
  }
}
