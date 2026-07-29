/// Bands for semantic progression (no athlete history in v1).
class PrescriptionProgressionBand {
  const PrescriptionProgressionBand({
    required this.setsMin,
    required this.setsMax,
    required this.repsMin,
    required this.repsMax,
    required this.rpeMin,
    required this.rpeMax,
    this.restSecondsMin,
    this.restSecondsMax,
    this.durationMinutesMin,
    this.durationMinutesMax,
    this.workRestRatio,
    this.distanceMetresMin,
    this.distanceMetresMax,
  });

  final int setsMin;
  final int setsMax;
  final int repsMin;
  final int repsMax;
  final int rpeMin;
  final int rpeMax;
  final int? restSecondsMin;
  final int? restSecondsMax;
  final int? durationMinutesMin;
  final int? durationMinutesMax;
  final String? workRestRatio;
  final int? distanceMetresMin;
  final int? distanceMetresMax;

  PrescriptionProgressionBand scaled({
    double volumeFactor = 1,
    double intensityFactor = 1,
  }) {
    final setsHigh = (setsMax * volumeFactor).round().clamp(1, 12);
    final setsLow = (setsMin * volumeFactor).round().clamp(1, setsHigh);
    final rpeLow = (rpeMin * intensityFactor).round().clamp(1, 10);
    final rpeHigh = (rpeMax * intensityFactor).round().clamp(rpeLow, 10);
    return PrescriptionProgressionBand(
      setsMin: setsLow,
      setsMax: setsHigh,
      repsMin: repsMin,
      repsMax: repsMax,
      rpeMin: rpeLow,
      rpeMax: rpeHigh,
      restSecondsMin: restSecondsMin,
      restSecondsMax: restSecondsMax,
      durationMinutesMin: durationMinutesMin == null
          ? null
          : (durationMinutesMin! * volumeFactor).round().clamp(5, 180),
      durationMinutesMax: durationMinutesMax == null
          ? null
          : (durationMinutesMax! * volumeFactor).round().clamp(5, 180),
      workRestRatio: workRestRatio,
      distanceMetresMin: distanceMetresMin,
      distanceMetresMax: distanceMetresMax,
    );
  }
}

enum PrescriptionModality { strength, endurance, carry, mobility, intervals, assessment }

class ArchetypePrescriptionTemplate {
  const ArchetypePrescriptionTemplate({
    required this.archetypeId,
    required this.modality,
    required this.preparation,
    required this.primary,
    required this.secondary,
    required this.recovery,
  });

  final String archetypeId;
  final PrescriptionModality modality;
  final PrescriptionProgressionBand preparation;
  final PrescriptionProgressionBand primary;
  final PrescriptionProgressionBand secondary;
  final PrescriptionProgressionBand recovery;
}

/// Deterministic template library (parameterised; migrate to ontology later).
class PrescriptionTemplateLibrary {
  const PrescriptionTemplateLibrary._();

  static ArchetypePrescriptionTemplate? forArchetype(String archetypeId) {
    return _templates[archetypeId];
  }

  static const _strengthPrimary = PrescriptionProgressionBand(
    setsMin: 3,
    setsMax: 5,
    repsMin: 4,
    repsMax: 8,
    rpeMin: 7,
    rpeMax: 9,
    restSecondsMin: 120,
    restSecondsMax: 180,
  );

  static const _strengthAccessory = PrescriptionProgressionBand(
    setsMin: 2,
    setsMax: 3,
    repsMin: 8,
    repsMax: 12,
    rpeMin: 6,
    rpeMax: 8,
    restSecondsMin: 60,
    restSecondsMax: 90,
  );

  static const _templates = <String, ArchetypePrescriptionTemplate>{
    'cohort.session_archetype.heavy_lower': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      modality: PrescriptionModality.strength,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 2,
        repsMin: 5,
        repsMax: 8,
        rpeMin: 5,
        rpeMax: 6,
        restSecondsMin: 45,
        restSecondsMax: 60,
      ),
      primary: _strengthPrimary,
      secondary: _strengthAccessory,
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.heavy_upper': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.heavy_upper',
      modality: PrescriptionModality.strength,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 2,
        repsMin: 5,
        repsMax: 10,
        rpeMin: 5,
        rpeMax: 6,
        restSecondsMin: 45,
        restSecondsMax: 60,
      ),
      primary: _strengthPrimary,
      secondary: _strengthAccessory,
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.tempo_run': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.tempo_run',
      modality: PrescriptionModality.endurance,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 8,
        durationMinutesMax: 12,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 7,
        rpeMax: 8,
        durationMinutesMin: 20,
        durationMinutesMax: 35,
        workRestRatio: 'continuous',
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 5,
        rpeMax: 6,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.long_easy_run': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.long_easy_run',
      modality: PrescriptionModality.endurance,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 5,
        rpeMax: 6,
        durationMinutesMin: 45,
        durationMinutesMax: 75,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 0,
        durationMinutesMax: 0,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
      ),
    ),
    'cohort.session_archetype.carry_session': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.carry_session',
      modality: PrescriptionModality.carry,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 2,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 5,
        rpeMax: 6,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 4,
        setsMax: 6,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 7,
        rpeMax: 8,
        distanceMetresMin: 20,
        distanceMetresMax: 40,
        restSecondsMin: 60,
        restSecondsMax: 90,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 2,
        setsMax: 3,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 6,
        rpeMax: 7,
        distanceMetresMin: 15,
        distanceMetresMax: 30,
        restSecondsMin: 45,
        restSecondsMax: 60,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.recovery_session': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.recovery_session',
      modality: PrescriptionModality.mobility,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 10,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 15,
        durationMinutesMax: 25,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 0,
        durationMinutesMax: 0,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 2,
        rpeMax: 3,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.mobility_flow': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.mobility_flow',
      modality: PrescriptionModality.mobility,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 2,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 20,
        durationMinutesMax: 30,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 0,
        durationMinutesMax: 0,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 2,
        rpeMax: 3,
        durationMinutesMin: 3,
        durationMinutesMax: 5,
      ),
    ),
    'cohort.session_archetype.technique_session': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.technique_session',
      modality: PrescriptionModality.assessment,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 4,
        rpeMax: 5,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 3,
        setsMax: 5,
        repsMin: 3,
        repsMax: 6,
        rpeMin: 5,
        rpeMax: 6,
        restSecondsMin: 60,
        restSecondsMax: 90,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 2,
        setsMax: 3,
        repsMin: 5,
        repsMax: 8,
        rpeMin: 5,
        rpeMax: 6,
        restSecondsMin: 45,
        restSecondsMax: 60,
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
    'cohort.session_archetype.mixed_engine': ArchetypePrescriptionTemplate(
      archetypeId: 'cohort.session_archetype.mixed_engine',
      modality: PrescriptionModality.intervals,
      preparation: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 5,
        rpeMax: 6,
        durationMinutesMin: 8,
        durationMinutesMax: 10,
      ),
      primary: PrescriptionProgressionBand(
        setsMin: 6,
        setsMax: 8,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 8,
        rpeMax: 9,
        durationMinutesMin: 2,
        durationMinutesMax: 3,
        workRestRatio: '1:1',
        restSecondsMin: 60,
        restSecondsMax: 90,
      ),
      secondary: PrescriptionProgressionBand(
        setsMin: 3,
        setsMax: 4,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 7,
        rpeMax: 8,
        durationMinutesMin: 1,
        durationMinutesMax: 2,
        workRestRatio: '1:1',
      ),
      recovery: PrescriptionProgressionBand(
        setsMin: 1,
        setsMax: 1,
        repsMin: 1,
        repsMax: 1,
        rpeMin: 3,
        rpeMax: 4,
        durationMinutesMin: 5,
        durationMinutesMax: 8,
      ),
    ),
  };
}
