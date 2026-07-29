import '../../../models/exercise.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/workout_format.dart';
import '../../../features/session/models/session_execution_plan.dart';
import '../exercise_policy/models/exercise_policy_models.dart';
import '../session_blueprint/models/session_blueprint.dart';
import 'models/prescription_models.dart';

/// Maps [PrescriptionResult] → M7 [SessionExecutionPlan] without changing player architecture.
class PrescriptionExecutionPlanAdapter {
  const PrescriptionExecutionPlanAdapter();

  SessionExecutionPlan toExecutionPlan({
    required PrescriptionResult result,
    required SemanticSessionExecutionPlan semanticPlan,
    List<Exercise> exercises = const [],
  }) {
    final exerciseById = {for (final e in exercises) e.exerciseId: e};
    final rxByExercise = {
      for (final p in result.prescriptions) p.exerciseId: p,
    };

    final blocks = <SessionExecutionBlock>[];
    var blockPosition = 0;

    for (final mapping in semanticPlan.componentMappings) {
      if (mapping.exerciseIds.isEmpty) continue;
      blockPosition++;
      final blockType = _blockType(mapping.componentType);
      final links = <SessionExecutionExerciseSummary>[];

      for (var i = 0; i < mapping.exerciseIds.length; i++) {
        final exerciseId = mapping.exerciseIds[i];
        final rx = rxByExercise[exerciseId];
        final label = rx?.exerciseLabel ?? exerciseId;
        final strengthRx = rx == null ? null : _toStrengthPrescription(rx);

        links.add(
          SessionExecutionExerciseSummary(
            exerciseId: exerciseId,
            displayName: label,
            exercise: exerciseById[exerciseId],
            prescription: strengthRx,
          ),
        );
      }

      blocks.add(
        SessionExecutionBlock(
          blockId: 'block_${mapping.componentSequence}',
          title: _title(mapping.componentType, mapping.purpose),
          blockType: blockType,
          content: _blockContent(mapping, rxByExercise),
          workoutFormat: _workoutFormat(mapping.componentType),
          position: blockPosition,
          linkedExercises: links,
          coachNotes: result.explainability.narrativeSummary,
        ),
      );
    }

    return SessionExecutionPlan(
      sessionId: result.planId,
      sessionTitle: semanticPlan.sessionObjectiveSummary ?? 'Prescribed session',
      blocks: blocks,
      durationMin: result.estimatedDurationMinutesMax,
      programmeContextLabel: result.sessionArchetypeId,
    );
  }

  SessionBlockType _blockType(SessionStructuralComponentType type) {
    return switch (type) {
      SessionStructuralComponentType.preparation ||
      SessionStructuralComponentType.movementPreparation =>
        SessionBlockType.warmUp,
      SessionStructuralComponentType.primaryDevelopment => SessionBlockType.strength,
      SessionStructuralComponentType.secondaryDevelopment ||
      SessionStructuralComponentType.supportingCapacity ||
      SessionStructuralComponentType.transitionPractice =>
        SessionBlockType.conditioning,
      SessionStructuralComponentType.skillOrTechnique ||
      SessionStructuralComponentType.assessment =>
        SessionBlockType.skill,
      SessionStructuralComponentType.recoveryOrCooldown => SessionBlockType.coolDown,
      SessionStructuralComponentType.trunkOrStability => SessionBlockType.core,
    };
  }

  WorkoutFormat _workoutFormat(SessionStructuralComponentType type) {
    return switch (type) {
      SessionStructuralComponentType.secondaryDevelopment ||
      SessionStructuralComponentType.transitionPractice =>
        WorkoutFormat.amrap,
      _ => WorkoutFormat.none,
    };
  }

  String _title(SessionStructuralComponentType type, String purpose) {
    return switch (type) {
      SessionStructuralComponentType.primaryDevelopment => 'Primary work',
      SessionStructuralComponentType.preparation => 'Preparation',
      SessionStructuralComponentType.recoveryOrCooldown => 'Cool-down',
      _ => purpose,
    };
  }

  String _blockContent(
    SemanticComponentExerciseMapping mapping,
    Map<String, ExercisePrescription> rxByExercise,
  ) {
    final parts = <String>[];
    for (final id in mapping.exerciseIds) {
      final rx = rxByExercise[id];
      if (rx == null) continue;
      parts.add(
        '${rx.exerciseLabel}: ${rx.sets} sets — ${rx.repsDescription} (${rx.effortGuidance})',
      );
    }
    return parts.join('\n');
  }

  StrengthExercisePrescription? _toStrengthPrescription(ExercisePrescription rx) {
    if (rx.durationMinutesMin != null &&
        rx.durationMinutesMax != null &&
        rx.repsDescription == 'continuous') {
      return StrengthExercisePrescription(
        sets: rx.sets,
        reps: StrengthRepPrescription(
          type: StrengthRepType.duration,
          text: '${rx.durationMinutesMin}–${rx.durationMinutesMax} min',
        ),
        load: StrengthLoadPrescription(
          type: StrengthLoadType.freeText,
          text: rx.effortGuidance,
        ),
        restSeconds: rx.restSeconds,
      );
    }

    if (rx.distanceMetresMin != null && rx.distanceMetresMax != null) {
      return StrengthExercisePrescription(
        sets: rx.sets,
        reps: StrengthRepPrescription(
          type: StrengthRepType.distance,
          text: '${rx.distanceMetresMin}–${rx.distanceMetresMax} m',
        ),
        load: StrengthLoadPrescription(
          type: StrengthLoadType.rpe,
          rpe: rx.rpeMax,
        ),
        restSeconds: rx.restSeconds,
      );
    }

    if (rx.intervals != null) {
      return StrengthExercisePrescription(
        sets: rx.intervals!.rounds,
        reps: StrengthRepPrescription(
          type: StrengthRepType.duration,
          text: rx.intervals!.workDescription,
        ),
        load: StrengthLoadPrescription(
          type: StrengthLoadType.freeText,
          text: rx.effortGuidance,
        ),
        restSeconds: rx.restSeconds,
        coachCue: 'Rest: ${rx.intervals!.restDescription}',
      );
    }

    return StrengthExercisePrescription(
      sets: rx.sets,
      reps: StrengthRepPrescription.range(
        min: _parseRepsMin(rx.repsDescription),
        max: _parseRepsMax(rx.repsDescription),
      ),
      load: StrengthLoadPrescription(
        type: StrengthLoadType.freeText,
        text: rx.effortGuidance,
      ),
      restSeconds: rx.restSeconds,
    );
  }

  int _parseRepsMin(String desc) {
    final match = RegExp(r'(\d+)').firstMatch(desc);
    return int.tryParse(match?.group(1) ?? '') ?? 6;
  }

  int _parseRepsMax(String desc) {
    final matches = RegExp(r'(\d+)').allMatches(desc).toList();
    if (matches.length >= 2) {
      return int.tryParse(matches[1].group(1) ?? '') ?? 8;
    }
    return _parseRepsMin(desc);
  }
}
