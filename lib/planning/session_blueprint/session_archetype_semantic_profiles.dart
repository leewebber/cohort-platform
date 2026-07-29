import 'models/session_blueprint.dart';
import 'models/session_blueprint_semantics.dart';

/// Isolated v1 archetype semantic profiles (migrate to ontology metadata later).
class SessionArchetypeSemanticProfile {
  const SessionArchetypeSemanticProfile({
    required this.archetypeId,
    required this.intensity,
    required this.volume,
    required this.density,
    required this.domainEmphasis,
    required this.componentTemplates,
    required this.baseSubstitutionTags,
    required this.expectedFatiguePosture,
  });

  final String archetypeId;
  final SemanticIntensityTarget intensity;
  final SemanticVolumeTarget volume;
  final SemanticDensityTarget density;
  final SemanticDomainEmphasis domainEmphasis;
  final List<SessionStructuralComponentTemplate> componentTemplates;
  final List<SessionSubstitutionPolicyTag> baseSubstitutionTags;
  final SemanticFatiguePosture expectedFatiguePosture;
}

class SessionStructuralComponentTemplate {
  const SessionStructuralComponentTemplate({
    required this.componentType,
    required this.purpose,
    required this.relativeEmphasis,
    required this.optionality,
    required this.fatigueContribution,
    this.orderingConstraint,
  });

  final SessionStructuralComponentType componentType;
  final String purpose;
  final SessionComponentEmphasis relativeEmphasis;
  final SessionComponentOptionality optionality;
  final SessionFatigueContribution fatigueContribution;
  final String? orderingConstraint;
}

class SessionArchetypeProfileRegistry {
  const SessionArchetypeProfileRegistry._();

  static SessionArchetypeSemanticProfile? profileFor(String archetypeId) {
    return _profiles[archetypeId];
  }

  static const _profiles = <String, SessionArchetypeSemanticProfile>{
    'cohort.session_archetype.long_easy_run': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.long_easy_run',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.low,
        domainEmphasis: SemanticDomainEmphasis.aerobic,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.high,
        descriptors: [
          SemanticVolumeDescriptor.extendedDuration,
          SemanticVolumeDescriptor.repeatedExposure,
        ],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.controlled),
      domainEmphasis: SemanticDomainEmphasis.aerobic,
      expectedFatiguePosture: SemanticFatiguePosture.low,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveEnergySystem,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.preparation,
          purpose: 'General warm-up and session entry',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Sustained easy aerobic development',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.moderate,
          orderingConstraint: 'after_preparation',
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.recoveryOrCooldown,
          purpose: 'Gradual return to rest',
          relativeEmphasis: SessionComponentEmphasis.minimal,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ],
    ),
    'cohort.session_archetype.tempo_run': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.tempo_run',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.moderatelyHigh,
        domainEmphasis: SemanticDomainEmphasis.threshold,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.moderate,
        descriptors: [SemanticVolumeDescriptor.standardDuration],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.controlled),
      domainEmphasis: SemanticDomainEmphasis.threshold,
      expectedFatiguePosture: SemanticFatiguePosture.elevated,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveEnergySystem,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
        SessionSubstitutionPolicyTag.preserveMovementPattern,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.preparation,
          purpose: 'Aerobic and neuromuscular preparation',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Sustained threshold-oriented running stimulus',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.secondaryDevelopment,
          purpose: 'Optional aerobic flush or strides',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.optional,
          fatigueContribution: SessionFatigueContribution.low,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.recoveryOrCooldown,
          purpose: 'Cooldown and parasympathetic shift',
          relativeEmphasis: SessionComponentEmphasis.minimal,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ],
    ),
    'cohort.session_archetype.heavy_lower': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.heavy_lower',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.high,
        domainEmphasis: SemanticDomainEmphasis.maximalStrength,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.moderate,
        descriptors: [SemanticVolumeDescriptor.lowRepetitionExposure],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.moderate),
      domainEmphasis: SemanticDomainEmphasis.maximalStrength,
      expectedFatiguePosture: SemanticFatiguePosture.elevated,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveMovementPattern,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.movementPreparation,
          purpose: 'Lower-body movement preparation',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Primary lower-body strength or hypertrophy work',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.supportingCapacity,
          purpose: 'Accessory lower-body or trunk support',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.moderate,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.recoveryOrCooldown,
          purpose: 'Mobility and cooldown',
          relativeEmphasis: SessionComponentEmphasis.minimal,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ],
    ),
    'cohort.session_archetype.heavy_upper': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.heavy_upper',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.high,
        domainEmphasis: SemanticDomainEmphasis.maximalStrength,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.moderate,
        descriptors: [SemanticVolumeDescriptor.lowRepetitionExposure],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.moderate),
      domainEmphasis: SemanticDomainEmphasis.maximalStrength,
      expectedFatiguePosture: SemanticFatiguePosture.elevated,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveMovementPattern,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.movementPreparation,
          purpose: 'Upper-body movement preparation',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Primary upper-body strength or hypertrophy work',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.supportingCapacity,
          purpose: 'Accessory upper-body support',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.moderate,
        ),
      ],
    ),
    'cohort.session_archetype.carry_session': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.carry_session',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.moderatelyHigh,
        domainEmphasis: SemanticDomainEmphasis.mixed,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.high,
        descriptors: [SemanticVolumeDescriptor.highAccumulatedWork],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.dense),
      domainEmphasis: SemanticDomainEmphasis.mixed,
      expectedFatiguePosture: SemanticFatiguePosture.high,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
        SessionSubstitutionPolicyTag.preserveMovementPattern,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.preparation,
          purpose: 'Grip and trunk preparation',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Loaded carry and grip endurance emphasis',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.trunkOrStability,
          purpose: 'Trunk stability under load',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.recommended,
          fatigueContribution: SessionFatigueContribution.moderate,
        ),
      ],
    ),
    'cohort.session_archetype.mobility_flow': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.mobility_flow',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.restorative,
        domainEmphasis: SemanticDomainEmphasis.technique,
      ),
      volume: SemanticVolumeTarget(level: SemanticVolumeLevel.low),
      density: SemanticDensityTarget(level: SemanticDensityLevel.sparse),
      domainEmphasis: SemanticDomainEmphasis.technique,
      expectedFatiguePosture: SemanticFatiguePosture.restorative,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.techniquePriority,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.skillOrTechnique,
          purpose: 'Mobility and tissue quality sequences',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ],
    ),
    'cohort.session_archetype.technique_session': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.technique_session',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.low,
        domainEmphasis: SemanticDomainEmphasis.technique,
      ),
      volume: SemanticVolumeTarget(level: SemanticVolumeLevel.low),
      density: SemanticDensityTarget(level: SemanticDensityLevel.controlled),
      domainEmphasis: SemanticDomainEmphasis.technique,
      expectedFatiguePosture: SemanticFatiguePosture.low,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.techniquePriority,
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveMovementPattern,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.movementPreparation,
          purpose: 'Pattern preparation',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.skillOrTechnique,
          purpose: 'Low-fatigue skill and pattern practice',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
        ),
      ],
    ),
    'cohort.session_archetype.recovery_session': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.recovery_session',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.restorative,
        domainEmphasis: SemanticDomainEmphasis.aerobic,
      ),
      volume: SemanticVolumeTarget(level: SemanticVolumeLevel.minimal),
      density: SemanticDensityTarget(level: SemanticDensityLevel.sparse),
      domainEmphasis: SemanticDomainEmphasis.aerobic,
      expectedFatiguePosture: SemanticFatiguePosture.restorative,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.fatigueReduced,
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.recoveryOrCooldown,
          purpose: 'Active recovery and restorative movement',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.none,
        ),
      ],
    ),
    'cohort.session_archetype.mixed_engine': SessionArchetypeSemanticProfile(
      archetypeId: 'cohort.session_archetype.mixed_engine',
      intensity: SemanticIntensityTarget(
        level: SemanticIntensityLevel.moderatelyHigh,
        domainEmphasis: SemanticDomainEmphasis.mixed,
      ),
      volume: SemanticVolumeTarget(
        level: SemanticVolumeLevel.high,
        descriptors: [
          SemanticVolumeDescriptor.repeatedExposure,
          SemanticVolumeDescriptor.highAccumulatedWork,
        ],
      ),
      density: SemanticDensityTarget(level: SemanticDensityLevel.variable),
      domainEmphasis: SemanticDomainEmphasis.mixed,
      expectedFatiguePosture: SemanticFatiguePosture.high,
      baseSubstitutionTags: [
        SessionSubstitutionPolicyTag.preservePrimaryIntent,
        SessionSubstitutionPolicyTag.preserveEnergySystem,
        SessionSubstitutionPolicyTag.preserveCapabilityTarget,
      ],
      componentTemplates: [
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.preparation,
          purpose: 'Hybrid session preparation',
          relativeEmphasis: SessionComponentEmphasis.low,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.low,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.primaryDevelopment,
          purpose: 'Primary conditioning or hybrid engine work',
          relativeEmphasis: SessionComponentEmphasis.primary,
          optionality: SessionComponentOptionality.required,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.secondaryDevelopment,
          purpose: 'Secondary engine or station-specific rounds',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.optional,
          fatigueContribution: SessionFatigueContribution.high,
        ),
        SessionStructuralComponentTemplate(
          componentType: SessionStructuralComponentType.transitionPractice,
          purpose: 'Transition or compromised-running practice',
          relativeEmphasis: SessionComponentEmphasis.moderate,
          optionality: SessionComponentOptionality.optional,
          fatigueContribution: SessionFatigueContribution.moderate,
        ),
      ],
    ),
  };
}
