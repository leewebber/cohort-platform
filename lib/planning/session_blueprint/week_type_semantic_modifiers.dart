import 'models/session_blueprint.dart';
import 'models/session_blueprint_semantics.dart';

/// Deterministic week-type adjustments applied after archetype base profile.
class WeekTypeSemanticAdjustment {
  const WeekTypeSemanticAdjustment({
    this.intensityDelta = 0,
    this.volumeDelta = 0,
    this.densityDelta = 0,
    this.progressionEmphasis = SessionProgressionEmphasis.general,
    this.requireAssessmentComponent = false,
    this.requireRecoveryComponent = false,
    this.stripOptionalHighFatigue = false,
    this.addAssessmentIntegrityTag = false,
    this.primaryEmphasisBoost = false,
    this.reduceSecondaryFatigue = false,
  });

  final int intensityDelta;
  final int volumeDelta;
  final int densityDelta;
  final SessionProgressionEmphasis progressionEmphasis;
  final bool requireAssessmentComponent;
  final bool requireRecoveryComponent;
  final bool stripOptionalHighFatigue;
  final bool addAssessmentIntegrityTag;
  final bool primaryEmphasisBoost;
  final bool reduceSecondaryFatigue;
}

class WeekTypeSemanticModifierRegistry {
  const WeekTypeSemanticModifierRegistry._();

  static WeekTypeSemanticAdjustment adjustmentFor(String? weekTypeId) {
    if (weekTypeId == null) {
      return const WeekTypeSemanticAdjustment();
    }
    if (weekTypeId.contains('accumulation')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.accumulation,
        volumeDelta: 1,
        primaryEmphasisBoost: true,
      );
    }
    if (weekTypeId.contains('intensification')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.intensification,
        intensityDelta: 1,
        volumeDelta: -1,
        primaryEmphasisBoost: true,
      );
    }
    if (weekTypeId.contains('realisation')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.realisation,
        intensityDelta: 1,
        volumeDelta: -1,
        reduceSecondaryFatigue: true,
        stripOptionalHighFatigue: true,
      );
    }
    if (weekTypeId.contains('deload')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.deload,
        intensityDelta: -1,
        volumeDelta: -1,
        densityDelta: -1,
        stripOptionalHighFatigue: true,
      );
    }
    if (weekTypeId.contains('assessment')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.assessment,
        requireAssessmentComponent: true,
        addAssessmentIntegrityTag: true,
        reduceSecondaryFatigue: true,
      );
    }
    if (weekTypeId.contains('recovery')) {
      return const WeekTypeSemanticAdjustment(
        progressionEmphasis: SessionProgressionEmphasis.recovery,
        intensityDelta: -2,
        volumeDelta: -1,
        densityDelta: -1,
        requireRecoveryComponent: true,
      );
    }
    return const WeekTypeSemanticAdjustment();
  }

  static SemanticIntensityTarget applyIntensity(
    SemanticIntensityTarget base,
    WeekTypeSemanticAdjustment adj,
  ) {
    var level = base.level;
    if (adj.intensityDelta > 0) {
      level = level.elevate(adj.intensityDelta);
    } else if (adj.intensityDelta < 0) {
      level = level.cap(-adj.intensityDelta);
    }
    return SemanticIntensityTarget(
      level: level,
      domainEmphasis: base.domainEmphasis,
      rationale: base.rationale,
    );
  }

  static SemanticVolumeTarget applyVolume(
    SemanticVolumeTarget base,
    WeekTypeSemanticAdjustment adj,
  ) {
    var level = base.level;
    if (adj.volumeDelta > 0) {
      level = level.increase(adj.volumeDelta);
    } else if (adj.volumeDelta < 0) {
      level = level.reduce(-adj.volumeDelta);
    }
    return SemanticVolumeTarget(
      level: level,
      descriptors: base.descriptors,
      rationale: base.rationale,
    );
  }

  static SemanticDensityTarget applyDensity(
    SemanticDensityTarget base,
    WeekTypeSemanticAdjustment adj,
  ) {
    var level = base.level;
    if (adj.densityDelta < 0) {
      level = level.soften(-adj.densityDelta);
    }
    return SemanticDensityTarget(level: level, rationale: base.rationale);
  }
}
