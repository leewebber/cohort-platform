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
  String get dbValue => switch (this) {
        SessionBlockType.warmUp => 'warm_up',
        SessionBlockType.strength => 'strength',
        SessionBlockType.skill => 'skill',
        SessionBlockType.accessory => 'accessory',
        SessionBlockType.conditioning => 'conditioning',
        SessionBlockType.core => 'core',
        SessionBlockType.coolDown => 'cool_down',
        SessionBlockType.custom => 'custom',
      };

  String get displayLabel => switch (this) {
        SessionBlockType.warmUp => 'Warm-up',
        SessionBlockType.strength => 'Strength',
        SessionBlockType.skill => 'Skill',
        SessionBlockType.accessory => 'Accessory',
        SessionBlockType.conditioning => 'Conditioning',
        SessionBlockType.core => 'Core',
        SessionBlockType.coolDown => 'Cool-down',
        SessionBlockType.custom => 'Custom',
      };

  String get defaultTitle => switch (this) {
        SessionBlockType.custom => 'Custom Block',
        _ => displayLabel,
      };

  static SessionBlockType fromDb(String? value) => switch (value?.trim()) {
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
