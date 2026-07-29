/// Primary physiological stress emphasis for a session.
enum PhysiologicalEmphasis {
  neuromuscularStrength,
  hypertrophy,
  power,
  aerobic,
  anaerobicLactic,
  anaerobicAlactic,
  mixedEnergySystem,
  restorative,
  skillAcquisition,
}

extension PhysiologicalEmphasisDb on PhysiologicalEmphasis {
  String get dbValue {
    return switch (this) {
      PhysiologicalEmphasis.neuromuscularStrength => 'neuromuscular_strength',
      PhysiologicalEmphasis.hypertrophy => 'hypertrophy',
      PhysiologicalEmphasis.power => 'power',
      PhysiologicalEmphasis.aerobic => 'aerobic',
      PhysiologicalEmphasis.anaerobicLactic => 'anaerobic_lactic',
      PhysiologicalEmphasis.anaerobicAlactic => 'anaerobic_alactic',
      PhysiologicalEmphasis.mixedEnergySystem => 'mixed_energy_system',
      PhysiologicalEmphasis.restorative => 'restorative',
      PhysiologicalEmphasis.skillAcquisition => 'skill_acquisition',
    };
  }

  static PhysiologicalEmphasis? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final emphasis in PhysiologicalEmphasis.values) {
      if (emphasis.dbValue == normalized) return emphasis;
    }
    return null;
  }
}
