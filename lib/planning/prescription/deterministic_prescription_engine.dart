import '../../application/ports/knowledge_graph_reader.dart';
import '../../application/ports/prescription_engine.dart';
import '../exercise_policy/models/exercise_policy_models.dart';
import '../session_blueprint/models/session_blueprint.dart';
import '../session_blueprint/models/session_blueprint_semantics.dart';
import 'models/prescription_models.dart';
import 'prescription_templates.dart';
import 'prescription_validator.dart';

/// Deterministic blueprint + semantic plan → prescribed session.
class DeterministicPrescriptionEngine implements PrescriptionEngine {
  DeterministicPrescriptionEngine({
    KnowledgeGraphReader? knowledge,
    PrescriptionValidator? validator,
  }) : _knowledge = knowledge,
       _validator = validator ?? const PrescriptionValidator();

  final KnowledgeGraphReader? _knowledge;
  final PrescriptionValidator _validator;

  @override
  PrescriptionResult prescribe(PrescriptionRequest request) {
    final factors = <PrescriptionExplainabilityFactor>[];
    final warnings = <PrescriptionWarning>[];

    final reqVal = _validator.validateRequest(request);
    if (!reqVal.isValid) {
      return _invalid(request, reqVal.messages, factors);
    }

    final bp = request.blueprint;
    final plan = request.executionPlan;
    final template = PrescriptionTemplateLibrary.forArchetype(
      bp.sessionArchetype.archetypeId,
    );
    if (template == null) {
      return _invalid(
        request,
        ['No prescription template for ${bp.sessionArchetype.archetypeId}'],
        factors,
      );
    }

    factors.add(
      PrescriptionExplainabilityFactor(
        layer: PrescriptionExplainabilityLayer.template,
        code: 'template_selected',
        summary: 'Archetype template ${template.archetypeId}',
        rationale: template.modality.name,
        sourceEntityIds: [template.archetypeId],
      ),
    );

    final modifiers = _semanticModifiers(bp, factors);
    final prescriptions = <ExercisePrescription>[];

    for (final selection in plan.orderedSelections) {
      final band = _bandForSelection(
        selection: selection,
        template: template,
        modifiers: modifiers,
        blueprint: bp,
      );
      final modality = _resolveModality(selection, template);
      final rx = _buildPrescription(
        selection: selection,
        band: band,
        modality: modality,
        blueprint: bp,
        modifiers: modifiers,
      );
      prescriptions.add(rx);
      factors.addAll(rx.explainability);
    }

    var status = PrescriptionStatus.complete;
    if (prescriptions.length < plan.orderedSelections.length) {
      status = PrescriptionStatus.partial;
    }
    if (bp.status == SessionBlueprintStatus.partial) {
      status = PrescriptionStatus.partial;
    }

    final duration = _estimateDuration(prescriptions);

    return PrescriptionResult(
      status: status,
      planId: plan.planId,
      blueprintId: plan.blueprintId,
      sessionArchetypeId: plan.sessionArchetypeId,
      primaryTrainingIntentId: plan.primaryTrainingIntentId,
      prescriptions: prescriptions,
      explainability: PrescriptionExplainability(
        factors: factors,
        narrativeSummary: _narrative(bp, template, modifiers, status),
      ),
      warnings: warnings,
      estimatedDurationMinutesMin: duration.$1,
      estimatedDurationMinutesMax: duration.$2,
    );
  }

  _SemanticModifiers _semanticModifiers(
    SessionBlueprint bp,
    List<PrescriptionExplainabilityFactor> factors,
  ) {
    var volumeFactor = switch (bp.semanticVolume.level) {
      SemanticVolumeLevel.minimal => 0.7,
      SemanticVolumeLevel.low => 0.85,
      SemanticVolumeLevel.moderate => 1.0,
      SemanticVolumeLevel.high => 1.1,
      SemanticVolumeLevel.veryHigh => 1.2,
    };

    var intensityFactor = switch (bp.semanticIntensity.level) {
      SemanticIntensityLevel.restorative => 0.85,
      SemanticIntensityLevel.low => 0.9,
      SemanticIntensityLevel.moderate => 1.0,
      SemanticIntensityLevel.moderatelyHigh => 1.05,
      SemanticIntensityLevel.high => 1.1,
      SemanticIntensityLevel.maximal => 1.15,
      SemanticIntensityLevel.variable => 1.0,
    };

    if (bp.substitutionPolicyTags.contains(
      SessionSubstitutionPolicyTag.fatigueReduced,
    )) {
      volumeFactor *= 0.85;
      intensityFactor *= 0.9;
      factors.add(
        const PrescriptionExplainabilityFactor(
          layer: PrescriptionExplainabilityLayer.constraint,
          code: 'fatigue_reduced_rx',
          summary: 'Reduced volume and effort for fatigue policy',
          rationale: 'Blueprint fatigueReduced tag applied.',
        ),
      );
    }

    final emphasis = bp.progressionContext.progressionEmphasis;
    if (emphasis == SessionProgressionEmphasis.deload ||
        emphasis == SessionProgressionEmphasis.recovery) {
      volumeFactor *= 0.75;
      intensityFactor *= 0.85;
    } else if (emphasis == SessionProgressionEmphasis.intensification) {
      intensityFactor *= 1.05;
      volumeFactor *= 0.95;
    }

    factors.add(
      PrescriptionExplainabilityFactor(
        layer: PrescriptionExplainabilityLayer.blueprintSemantics,
        code: 'semantic_modifiers',
        summary:
            'Volume×${volumeFactor.toStringAsFixed(2)} intensity×${intensityFactor.toStringAsFixed(2)}',
        rationale:
            '${bp.semanticIntensity.level.name} intensity, ${bp.semanticVolume.level.name} volume, ${bp.semanticDensity.level.name} density',
      ),
    );

    return _SemanticModifiers(
      volumeFactor: volumeFactor,
      intensityFactor: intensityFactor,
      density: bp.semanticDensity.level,
    );
  }

  PrescriptionProgressionBand _bandForSelection({
    required ExerciseSelection selection,
    required ArchetypePrescriptionTemplate template,
    required _SemanticModifiers modifiers,
    required SessionBlueprint blueprint,
  }) {
    PrescriptionProgressionBand base = switch (selection.movementRole) {
      ExerciseMovementRole.primary => template.primary,
      ExerciseMovementRole.secondary => template.secondary,
      ExerciseMovementRole.recovery => template.recovery,
      _ => template.preparation,
    };

    if (selection.structuralComponentType ==
        SessionStructuralComponentType.assessment) {
      base = template.primary.copyWithAssessment();
    }

    var band = base.scaled(
      volumeFactor: modifiers.volumeFactor,
      intensityFactor: modifiers.intensityFactor,
    );

    if (modifiers.density == SemanticDensityLevel.dense ||
        modifiers.density == SemanticDensityLevel.continuous) {
      band = band.copyWithRest(
        ((band.restSecondsMin ?? 60) * 0.85).round(),
        ((band.restSecondsMax ?? 90) * 0.85).round(),
      );
    }

    if (blueprint.constraints.any((c) => c.code == 'poor_recovery')) {
      band = band.scaled(volumeFactor: 0.9, intensityFactor: 0.9);
    }

    return band;
  }

  PrescriptionModality _resolveModality(
    ExerciseSelection selection,
    ArchetypePrescriptionTemplate template,
  ) {
    final ex = _knowledge?.exerciseById(selection.exerciseId);
    if (ex != null) {
      if (ex.movementPatternIds.any((p) => p.contains('locomotion'))) {
        return PrescriptionModality.endurance;
      }
      if (ex.movementPatternIds.any((p) => p.contains('carry'))) {
        return PrescriptionModality.carry;
      }
      if (ex.movementPatternIds.any((p) => p.contains('cyclical'))) {
        return PrescriptionModality.intervals;
      }
    }
    if (selection.exerciseId.contains('running')) {
      return PrescriptionModality.endurance;
    }
    return template.modality;
  }

  ExercisePrescription _buildPrescription({
    required ExerciseSelection selection,
    required PrescriptionProgressionBand band,
    required PrescriptionModality modality,
    required SessionBlueprint blueprint,
    required _SemanticModifiers modifiers,
  }) {
    final sets = ((band.setsMin + band.setsMax) / 2).round();
    final explain = <PrescriptionExplainabilityFactor>[
      PrescriptionExplainabilityFactor(
        layer: PrescriptionExplainabilityLayer.progression,
        code: 'progression_band',
        summary: 'Sets $sets, RPE ${band.rpeMin}–${band.rpeMax}',
        rationale: 'Derived from archetype template and semantic modifiers.',
        exerciseId: selection.exerciseId,
      ),
      PrescriptionExplainabilityFactor(
        layer: PrescriptionExplainabilityLayer.role,
        code: 'movement_role',
        summary: 'Role ${selection.movementRole.name}',
        rationale: 'Component ${selection.structuralComponentSequence}',
        exerciseId: selection.exerciseId,
      ),
    ];

    String repsDescription;
    PrescriptionIntervalStructure? intervals;
    int? durMin = band.durationMinutesMin;
    int? durMax = band.durationMinutesMax;

    if (modality == PrescriptionModality.endurance) {
      repsDescription = 'continuous';
      if (durMin == null || durMin == 0) {
        durMin = 25;
        durMax = 35;
      }
      explain.add(
        PrescriptionExplainabilityFactor(
          layer: PrescriptionExplainabilityLayer.template,
          code: 'endurance_duration',
          summary: 'Duration emphasis $durMin–$durMax min',
          rationale: 'Threshold/aerobic template for locomotion.',
          exerciseId: selection.exerciseId,
        ),
      );
    } else if (modality == PrescriptionModality.carry) {
      repsDescription = '1 carry per set';
      explain.add(
        PrescriptionExplainabilityFactor(
          layer: PrescriptionExplainabilityLayer.template,
          code: 'carry_distance',
          summary:
              'Distance ${band.distanceMetresMin}–${band.distanceMetresMax} m',
          rationale: 'Loaded carry progression band.',
          exerciseId: selection.exerciseId,
        ),
      );
    } else if (modality == PrescriptionModality.intervals) {
      repsDescription = '1 interval per set';
      intervals = PrescriptionIntervalStructure(
        rounds: sets,
        workDescription:
            '${band.durationMinutesMin}–${band.durationMinutesMax} min @ RPE ${band.rpeMin}–${band.rpeMax}',
        restDescription:
            '${band.restSecondsMin ?? 60}–${band.restSecondsMax ?? 90} s',
        workRestRatio: band.workRestRatio,
      );
      explain.add(
        PrescriptionExplainabilityFactor(
          layer: PrescriptionExplainabilityLayer.template,
          code: 'interval_structure',
          summary: '${intervals.rounds} rounds ${band.workRestRatio ?? "1:1"}',
          rationale: 'Mixed-engine density template.',
          exerciseId: selection.exerciseId,
        ),
      );
    } else if (modality == PrescriptionModality.mobility) {
      repsDescription = 'quality focus';
      durMin ??= 15;
      durMax ??= 25;
    } else if (modality == PrescriptionModality.assessment) {
      repsDescription = '${band.repsMin}–${band.repsMax} quality reps';
    } else {
      repsDescription = '${band.repsMin}–${band.repsMax} reps';
      explain.add(
        PrescriptionExplainabilityFactor(
          layer: PrescriptionExplainabilityLayer.template,
          code: 'strength_structure',
          summary:
              '$sets×$repsDescription @ RPE ${band.rpeMin}–${band.rpeMax}',
          rationale: 'Strength progression band from template.',
          exerciseId: selection.exerciseId,
        ),
      );
    }

    final rest = band.restSecondsMax ?? band.restSecondsMin;
    return ExercisePrescription(
      exerciseId: selection.exerciseId,
      exerciseLabel: selection.exerciseLabel,
      sequence: selection.sequence,
      structuralComponentSequence: selection.structuralComponentSequence,
      movementRole: selection.movementRole,
      sets: sets,
      repsDescription: repsDescription,
      durationMinutesMin: durMin,
      durationMinutesMax: durMax,
      distanceMetresMin: band.distanceMetresMin,
      distanceMetresMax: band.distanceMetresMax,
      restSeconds: rest,
      rpeMin: band.rpeMin,
      rpeMax: band.rpeMax,
      effortGuidance: 'Target RPE ${band.rpeMin}–${band.rpeMax}',
      loadGuidance: modality == PrescriptionModality.strength
          ? 'Load to RPE band; no 1RM required in v1'
          : 'Pace/effort to RPE band',
      intervals: intervals,
      explainability: explain,
    );
  }

  (int, int) _estimateDuration(List<ExercisePrescription> rx) {
    var min = 0;
    var max = 0;
    for (final p in rx) {
      if (p.durationMinutesMin != null && p.durationMinutesMax != null) {
        min += p.durationMinutesMin!;
        max += p.durationMinutesMax!;
      } else {
        final perSet = ((p.restSeconds ?? 60) / 60).ceil();
        min += p.sets * (1 + perSet);
        max += p.sets * (2 + perSet);
      }
    }
    return (min.clamp(15, 180), max.clamp(20, 240));
  }

  String _narrative(
    SessionBlueprint bp,
    ArchetypePrescriptionTemplate template,
    _SemanticModifiers modifiers,
    PrescriptionStatus status,
  ) {
    return 'Prescription for ${bp.sessionArchetype.label} using ${template.modality.name} template '
        'with ${bp.semanticIntensity.level.name} intensity and ${bp.semanticVolume.level.name} volume. '
        'Status=$status.';
  }

  PrescriptionResult _invalid(
    PrescriptionRequest request,
    List<String> messages,
    List<PrescriptionExplainabilityFactor> factors,
  ) {
    factors.add(
      PrescriptionExplainabilityFactor(
        layer: PrescriptionExplainabilityLayer.outcome,
        code: 'invalid_input',
        summary: 'Prescription aborted',
        rationale: messages.join('; '),
      ),
    );
    return PrescriptionResult(
      status: PrescriptionStatus.invalidInput,
      planId: request.executionPlan.planId,
      blueprintId: request.executionPlan.blueprintId,
      sessionArchetypeId: request.executionPlan.sessionArchetypeId,
      primaryTrainingIntentId: request.executionPlan.primaryTrainingIntentId,
      prescriptions: const [],
      explainability: PrescriptionExplainability(
        factors: factors,
        narrativeSummary: messages.isEmpty ? 'Invalid' : messages.first,
      ),
      warnings: messages
          .map((m) => PrescriptionWarning(code: 'invalid_input', message: m))
          .toList(),
      estimatedDurationMinutesMin: 0,
      estimatedDurationMinutesMax: 0,
    );
  }
}

class _SemanticModifiers {
  const _SemanticModifiers({
    required this.volumeFactor,
    required this.intensityFactor,
    required this.density,
  });

  final double volumeFactor;
  final double intensityFactor;
  final SemanticDensityLevel density;
}

extension on PrescriptionProgressionBand {
  PrescriptionProgressionBand copyWithAssessment() {
    return PrescriptionProgressionBand(
      setsMin: 3,
      setsMax: 4,
      repsMin: 3,
      repsMax: 5,
      rpeMin: 5,
      rpeMax: 6,
      restSecondsMin: 90,
      restSecondsMax: 120,
    );
  }

  PrescriptionProgressionBand copyWithRest(int min, int max) {
    return PrescriptionProgressionBand(
      setsMin: setsMin,
      setsMax: setsMax,
      repsMin: repsMin,
      repsMax: repsMax,
      rpeMin: rpeMin,
      rpeMax: rpeMax,
      restSecondsMin: min,
      restSecondsMax: max,
      durationMinutesMin: durationMinutesMin,
      durationMinutesMax: durationMinutesMax,
      workRestRatio: workRestRatio,
      distanceMetresMin: distanceMetresMin,
      distanceMetresMax: distanceMetresMax,
    );
  }
}
