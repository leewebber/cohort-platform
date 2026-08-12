import 'dart:convert';

import '../../domain/exercise_knowledge/models/coaching_content.dart';
import '../../domain/exercise_knowledge/models/movement_standard.dart';

/// Immutable, UI-neutral text guidance for one canonical exercise identity.
///
/// This application read model contains no prescription, athlete evidence,
/// adaptation, comparison, substitution, relationship, or media authority.
class OperationalExerciseTextGuidance {
  OperationalExerciseTextGuidance({
    required this.exerciseId,
    required this.canonicalName,
    required List<OperationalMovementStandardProjection> movementStandards,
    required List<OperationalCoachingContentProjection> coachingContents,
  }) : movementStandards = List.unmodifiable(movementStandards),
       coachingContents = List.unmodifiable(coachingContents);

  final String exerciseId;
  final String canonicalName;
  final List<OperationalMovementStandardProjection> movementStandards;
  final List<OperationalCoachingContentProjection> coachingContents;

  bool get hasTextGuidance =>
      movementStandards.isNotEmpty || coachingContents.isNotEmpty;

  Map<String, Object?> toJson() => {
    'exercise_id': exerciseId,
    'canonical_name': canonicalName,
    'movement_standards': movementStandards
        .map((standard) => standard.toJson())
        .toList(growable: false),
    'coaching_contents': coachingContents
        .map((content) => content.toJson())
        .toList(growable: false),
  };

  String toCanonicalJson() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is OperationalExerciseTextGuidance &&
      other.toCanonicalJson() == toCanonicalJson();

  @override
  int get hashCode => toCanonicalJson().hashCode;
}

class OperationalMovementStandardProjection {
  OperationalMovementStandardProjection({
    required this.contentId,
    required this.version,
    required this.language,
    required this.title,
    required this.applicabilityKey,
    required this.startPosition,
    required List<String> executionSequence,
    required List<String> completionCriteria,
    required List<String> invalidRepetitionCriteria,
    required List<String> safetyNotes,
  }) : executionSequence = List.unmodifiable(executionSequence),
       completionCriteria = List.unmodifiable(completionCriteria),
       invalidRepetitionCriteria = List.unmodifiable(invalidRepetitionCriteria),
       safetyNotes = List.unmodifiable(safetyNotes);

  factory OperationalMovementStandardProjection.fromDomain(
    MovementStandard standard,
  ) => OperationalMovementStandardProjection(
    contentId: standard.id.value,
    version: standard.version,
    language: standard.language,
    title: standard.title,
    applicabilityKey: standard.applicabilityKey,
    startPosition: standard.startPosition,
    executionSequence: standard.executionSequence,
    completionCriteria: standard.completionCriteria,
    invalidRepetitionCriteria: standard.invalidRepetitionCriteria,
    safetyNotes: standard.safetyNotes,
  );

  final String contentId;
  final String version;
  final String language;
  final String title;
  final String applicabilityKey;
  final String startPosition;
  final List<String> executionSequence;
  final List<String> completionCriteria;
  final List<String> invalidRepetitionCriteria;
  final List<String> safetyNotes;

  Map<String, Object?> toJson() => {
    'content_id': contentId,
    'version': version,
    'language': language,
    'title': title,
    'applicability_key': applicabilityKey,
    'start_position': startPosition,
    'execution_sequence': executionSequence,
    'completion_criteria': completionCriteria,
    'invalid_repetition_criteria': invalidRepetitionCriteria,
    'safety_notes': safetyNotes,
  };

  @override
  bool operator ==(Object other) =>
      other is OperationalMovementStandardProjection &&
      other.contentId == contentId &&
      other.version == version &&
      other.language == language &&
      other.title == title &&
      other.applicabilityKey == applicabilityKey &&
      other.startPosition == startPosition &&
      _listEquals(other.executionSequence, executionSequence) &&
      _listEquals(other.completionCriteria, completionCriteria) &&
      _listEquals(other.invalidRepetitionCriteria, invalidRepetitionCriteria) &&
      _listEquals(other.safetyNotes, safetyNotes);

  @override
  int get hashCode => Object.hash(
    contentId,
    version,
    language,
    title,
    applicabilityKey,
    startPosition,
    Object.hashAll(executionSequence),
    Object.hashAll(completionCriteria),
    Object.hashAll(invalidRepetitionCriteria),
    Object.hashAll(safetyNotes),
  );
}

class OperationalFaultCorrectionProjection {
  const OperationalFaultCorrectionProjection({
    required this.fault,
    required this.correction,
  });

  factory OperationalFaultCorrectionProjection.fromDomain(
    CoachingFaultCorrection item,
  ) => OperationalFaultCorrectionProjection(
    fault: item.fault,
    correction: item.correction,
  );

  final String fault;
  final String correction;

  Map<String, Object?> toJson() => {'fault': fault, 'correction': correction};

  @override
  bool operator ==(Object other) =>
      other is OperationalFaultCorrectionProjection &&
      other.fault == fault &&
      other.correction == correction;

  @override
  int get hashCode => Object.hash(fault, correction);
}

class OperationalCoachingContentProjection {
  OperationalCoachingContentProjection({
    required this.contentId,
    required this.version,
    required this.language,
    required this.audience,
    required List<String> setupGuidance,
    required List<String> executionInstructions,
    required List<String> coachingCues,
    required List<OperationalFaultCorrectionProjection> faultCorrections,
    required List<String> breathingGuidance,
    required List<String> safetyNotes,
    required this.regressionProgressionExplanation,
  }) : setupGuidance = List.unmodifiable(setupGuidance),
       executionInstructions = List.unmodifiable(executionInstructions),
       coachingCues = List.unmodifiable(coachingCues),
       faultCorrections = List.unmodifiable(faultCorrections),
       breathingGuidance = List.unmodifiable(breathingGuidance),
       safetyNotes = List.unmodifiable(safetyNotes);

  factory OperationalCoachingContentProjection.fromDomain(
    CoachingContent content,
  ) => OperationalCoachingContentProjection(
    contentId: content.id.value,
    version: content.version,
    language: content.language,
    audience: content.audience,
    setupGuidance: content.setupGuidance,
    executionInstructions: content.executionInstructions,
    coachingCues: content.coachingCues,
    faultCorrections: content.faultCorrections
        .map(OperationalFaultCorrectionProjection.fromDomain)
        .toList(growable: false),
    breathingGuidance: content.breathingGuidance,
    safetyNotes: content.safetyNotes,
    regressionProgressionExplanation: content.regressionProgressionExplanation,
  );

  final String contentId;
  final String version;
  final String language;
  final String audience;
  final List<String> setupGuidance;
  final List<String> executionInstructions;
  final List<String> coachingCues;
  final List<OperationalFaultCorrectionProjection> faultCorrections;
  final List<String> breathingGuidance;
  final List<String> safetyNotes;
  final String regressionProgressionExplanation;

  Map<String, Object?> toJson() => {
    'content_id': contentId,
    'version': version,
    'language': language,
    'audience': audience,
    'setup_guidance': setupGuidance,
    'execution_instructions': executionInstructions,
    'coaching_cues': coachingCues,
    'fault_corrections': faultCorrections
        .map((item) => item.toJson())
        .toList(growable: false),
    'breathing_guidance': breathingGuidance,
    'safety_notes': safetyNotes,
    'regression_progression_explanation': regressionProgressionExplanation,
  };

  @override
  bool operator ==(Object other) =>
      other is OperationalCoachingContentProjection &&
      other.contentId == contentId &&
      other.version == version &&
      other.language == language &&
      other.audience == audience &&
      _listEquals(other.setupGuidance, setupGuidance) &&
      _listEquals(other.executionInstructions, executionInstructions) &&
      _listEquals(other.coachingCues, coachingCues) &&
      _listEquals(other.faultCorrections, faultCorrections) &&
      _listEquals(other.breathingGuidance, breathingGuidance) &&
      _listEquals(other.safetyNotes, safetyNotes) &&
      other.regressionProgressionExplanation ==
          regressionProgressionExplanation;

  @override
  int get hashCode => Object.hash(
    contentId,
    version,
    language,
    audience,
    Object.hashAll(setupGuidance),
    Object.hashAll(executionInstructions),
    Object.hashAll(coachingCues),
    Object.hashAll(faultCorrections),
    Object.hashAll(breathingGuidance),
    Object.hashAll(safetyNotes),
    regressionProgressionExplanation,
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
