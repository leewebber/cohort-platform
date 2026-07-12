import '../models/exercise.dart';
import '../models/protocol_step.dart';

/// Runtime execution model for a single step shown in the session player.
///
/// [ProtocolStep] is the stored programming model (persisted in Supabase).
/// [SessionStep] is derived from that data at play time for display and flow.
class SessionStep {
  const SessionStep({
    required this.stepNumber,
    required this.title,
    this.prescription,
    this.coachCue,
    this.prescribedSets,
    this.prescribedReps,
    this.prescribedLoad,
    this.prescribedRest,
    this.protocolStepId,
    this.exerciseId,
  });

  final int stepNumber;
  final String title;
  final String? prescription;
  final String? coachCue;
  final String? prescribedSets;
  final String? prescribedReps;
  final String? prescribedLoad;
  final String? prescribedRest;
  final int? protocolStepId;
  final String? exerciseId;

  factory SessionStep.fromProtocolStep(
    ProtocolStep step, {
    Exercise? exercise,
  }) {
    return SessionStep(
      stepNumber: step.stepOrder,
      title: step.title,
      prescription: _prescriptionFromStep(step),
      coachCue: _coachCueFromStep(step, exercise),
      prescribedSets: step.sets,
      prescribedReps: step.reps,
      prescribedLoad: step.load,
      prescribedRest: step.rest,
      protocolStepId: step.id,
      exerciseId: step.exerciseId,
    );
  }

  static String? _prescriptionFromStep(ProtocolStep step) {
    final parts = <String>[];

    if (step.sets != null && step.sets!.trim().isNotEmpty) {
      parts.add('${step.sets} sets');
    }

    if (step.reps != null && step.reps!.trim().isNotEmpty) {
      parts.add('${step.reps} reps');
    }

    if (step.distance != null && step.distance!.trim().isNotEmpty) {
      parts.add(step.distance!);
    }

    if (step.duration != null && step.duration!.trim().isNotEmpty) {
      parts.add(step.duration!);
    }

    if (step.load != null && step.load!.trim().isNotEmpty) {
      parts.add(step.load!);
    }

    if (step.tempo != null && step.tempo!.trim().isNotEmpty) {
      parts.add(step.tempo!);
    }

    if (step.rest != null && step.rest!.trim().isNotEmpty) {
      parts.add('Rest ${step.rest}');
    }

    if (parts.isEmpty) return null;

    return parts.join(' • ');
  }

  static String? _coachCueFromStep(
    ProtocolStep step,
    Exercise? exercise,
  ) {
    final coachingCues = exercise?.coachingCues?.trim();
    if (coachingCues != null && coachingCues.isNotEmpty) {
      return coachingCues;
    }

    final notes = step.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }

    return null;
  }
}
