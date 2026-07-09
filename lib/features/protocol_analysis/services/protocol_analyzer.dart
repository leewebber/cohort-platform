import '../../../data/repositories/exercise_repository.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/protocol_step_repository.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol.dart';
import '../../../models/movement_profile.dart';
import '../../../models/protocol_analysis.dart';
import '../../../models/protocol_step.dart';

/// Single entry point for deriving intelligence from a protocol and its steps.
///
/// [ProtocolAnalyzer] loads the protocol record, ordered protocol steps, and
/// all referenced exercises. Analysis fields are introduced incrementally;
/// see [ProtocolAnalysis] for the planned roadmap.
class ProtocolAnalyzer {
  const ProtocolAnalyzer(
    this._protocolRepository,
    this._protocolStepRepository,
    this._exerciseRepository,
  );

  final ProtocolRepository _protocolRepository;
  final ProtocolStepRepository _protocolStepRepository;
  final ExerciseRepository _exerciseRepository;

  Future<ProtocolAnalysis> analyseProtocol(String protocolId) async {
    final protocol = await _protocolRepository.getProtocolById(protocolId);
    if (protocol == null) {
      throw StateError('Protocol not found: $protocolId');
    }

    final steps = await _protocolStepRepository.getProtocolSteps(protocolId);
    final exercises = await _loadReferencedExercises(steps);

    // TODO(Fingerprint): compute experiential signature from [steps] and [exercises].
    // TODO(Equipment Dependency): analyse equipment requirements across [steps] and [exercises].
    // TODO(Density): calculate work density from step prescriptions in [steps].
    // TODO(Complexity): assess skill demand from [steps] and [exercises].
    // TODO(Running Percentage): measure running share from [steps].
    // TODO(Transition Density): measure modality change frequency in [steps].
    // TODO(Substitution Difficulty): score swap resistance from [steps] and [exercises].

    return ProtocolAnalysis(
      protocolId: protocol.protocolId,
      protocolName: protocol.name,
      exerciseCount: exercises.length,
      stepCount: steps.length,
      requiredEquipmentSummary: _deriveRequiredEquipmentSummary(
        protocol,
        exercises,
      ),
      bodyFocusSummary: _deriveBodyFocusSummary(protocol, exercises),
      hasRunning: _deriveHasRunning(steps, exercises),
      hasErg: _deriveHasErg(steps, exercises),
      movementProfile: _buildMovementProfile(steps, exercises),
    );
  }

  MovementProfile _buildMovementProfile(
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    // v0.1 counts at most one increment per movement bucket per protocol step.
    // TODO: weight counts by reps, time, and distance from step prescriptions.
    // TODO: derive percentages for adaptation similarity comparisons.

    var push = 0;
    var pull = 0;
    var squat = 0;
    var hinge = 0;
    var lunge = 0;
    var carry = 0;
    var core = 0;
    var running = 0;
    var erg = 0;
    var upperBody = 0;
    var lowerBody = 0;

    final stepProfiles = <_StepMovementProfile>[];

    for (final step in steps) {
      stepProfiles.add(_profileForStep(step, exercises));
    }

    for (final stepProfile in stepProfiles) {
      if (!stepProfile.hasAnyMovement) {
        continue;
      }

      if (stepProfile.push) push += 1;
      if (stepProfile.pull) pull += 1;
      if (stepProfile.squat) squat += 1;
      if (stepProfile.hinge) hinge += 1;
      if (stepProfile.lunge) lunge += 1;
      if (stepProfile.carry) carry += 1;
      if (stepProfile.core) core += 1;
      if (stepProfile.running) running += 1;
      if (stepProfile.erg) erg += 1;
      if (stepProfile.upperBody) upperBody += 1;
      if (stepProfile.lowerBody) lowerBody += 1;
    }

    final totalMovements =
        stepProfiles.where((profile) => profile.hasAnyMovement).length;

    return MovementProfile(
      push: push,
      pull: pull,
      squat: squat,
      hinge: hinge,
      lunge: lunge,
      carry: carry,
      core: core,
      running: running,
      erg: erg,
      upperBody: upperBody,
      lowerBody: lowerBody,
      totalMovements: totalMovements,
    );
  }

  _StepMovementProfile _profileForStep(
    ProtocolStep step,
    Map<String, Exercise> exercises,
  ) {
    final exercise = _exerciseForStep(step, exercises);

    final hasPush = _matchesPattern(exercise?.movementPattern, 'push');
    final hasPull = _matchesPattern(exercise?.movementPattern, 'pull');
    final hasSquat = _matchesPattern(exercise?.movementPattern, 'squat');
    final hasHinge = _matchesPattern(exercise?.movementPattern, 'hinge');
    final hasLunge = _matchesPattern(exercise?.movementPattern, 'lunge');
    final hasCarry = _matchesPattern(exercise?.movementPattern, 'carry');
    final hasCore = _matchesPattern(exercise?.movementPattern, 'core');
    final hasRunningFromExercise = _matchesPattern(exercise?.movementPattern, 'run') ||
        _matchesPattern(exercise?.movementPattern, 'locomotion') ||
        _containsToken(exercise?.exerciseType, 'run') ||
        _containsToken(exercise?.category, 'run');
    final hasRunningFromStep = step.stepType.trim().toLowerCase() == 'run' ||
        (step.distance != null && step.distance!.trim().isNotEmpty) ||
        _containsToken(step.title, 'run');
    final hasRunning = hasRunningFromExercise || hasRunningFromStep;

    final hasErgFromExercise = _matchesPattern(exercise?.movementPattern, 'erg') ||
        _containsToken(exercise?.equipment, 'erg') ||
        _containsToken(exercise?.equipmentCategory, 'erg') ||
        _containsToken(exercise?.name, 'erg');
    final hasErg = hasErgFromExercise || _containsToken(step.title, 'erg');

    var hasUpperBody = _matchesBodyRegion(exercise?.bodyRegion, 'upper');
    var hasLowerBody = _matchesBodyRegion(exercise?.bodyRegion, 'lower');

    if (!hasUpperBody && (hasPush || hasPull)) {
      hasUpperBody = true;
    }

    if (!hasLowerBody &&
        (hasSquat || hasHinge || hasLunge || hasCarry || hasRunning)) {
      hasLowerBody = true;
    }

    final hasAnyMovement = hasPush ||
        hasPull ||
        hasSquat ||
        hasHinge ||
        hasLunge ||
        hasCarry ||
        hasCore ||
        hasRunning ||
        hasErg ||
        hasUpperBody ||
        hasLowerBody;

    return _StepMovementProfile(
      push: hasPush,
      pull: hasPull,
      squat: hasSquat,
      hinge: hasHinge,
      lunge: hasLunge,
      carry: hasCarry,
      core: hasCore,
      running: hasRunning,
      erg: hasErg,
      upperBody: hasUpperBody,
      lowerBody: hasLowerBody,
      hasAnyMovement: hasAnyMovement,
    );
  }

  bool _matchesPattern(String? value, String pattern) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    for (final part in value.split(',')) {
      if (_containsToken(part, pattern)) {
        return true;
      }
    }

    return false;
  }

  bool _matchesBodyRegion(String? value, String region) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    for (final part in value.split(',')) {
      if (_containsToken(part, region)) {
        return true;
      }
    }

    return false;
  }

  String _deriveRequiredEquipmentSummary(
    Protocol protocol,
    Map<String, Exercise> exercises,
  ) {
    final equipment = <String>{};

    for (final exercise in exercises.values) {
      _addTokens(equipment, exercise.equipment);
      _addTokens(equipment, exercise.equipmentCategory);
    }

    if (equipment.isEmpty) {
      _addTokens(equipment, protocol.requiredEquipment);
    }

    if (equipment.isEmpty) {
      _addTokens(equipment, protocol.equipment);
    }

    return _joinSorted(equipment);
  }

  String _deriveBodyFocusSummary(
    Protocol protocol,
    Map<String, Exercise> exercises,
  ) {
    final bodyFocus = <String>{};

    for (final exercise in exercises.values) {
      _addTokens(bodyFocus, exercise.bodyRegion);
      _addTokens(bodyFocus, exercise.movementPattern);
    }

    if (bodyFocus.isEmpty) {
      _addTokens(bodyFocus, protocol.capability);
    }

    return _joinSorted(bodyFocus);
  }

  bool _deriveHasRunning(
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    for (final step in steps) {
      if (step.stepType.trim().toLowerCase() == 'run') {
        return true;
      }

      if (step.distance != null && step.distance!.trim().isNotEmpty) {
        return true;
      }

      if (_containsToken(step.title, 'run')) {
        return true;
      }

      final exercise = _exerciseForStep(step, exercises);
      if (exercise == null) continue;

      if (_containsToken(exercise.exerciseType, 'run') ||
          _containsToken(exercise.category, 'run') ||
          _containsToken(exercise.movementPattern, 'run')) {
        return true;
      }
    }

    return false;
  }

  bool _deriveHasErg(
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    for (final step in steps) {
      if (_containsToken(step.title, 'erg')) {
        return true;
      }

      final exercise = _exerciseForStep(step, exercises);
      if (exercise == null) continue;

      if (_containsToken(exercise.equipment, 'erg') ||
          _containsToken(exercise.equipmentCategory, 'erg') ||
          _containsToken(exercise.name, 'erg')) {
        return true;
      }
    }

    return false;
  }

  Exercise? _exerciseForStep(
    ProtocolStep step,
    Map<String, Exercise> exercises,
  ) {
    final exerciseId = step.exerciseId?.trim();
    if (exerciseId == null || exerciseId.isEmpty) {
      return null;
    }

    return exercises[exerciseId];
  }

  void _addTokens(Set<String> tokens, String? value) {
    if (value == null || value.trim().isEmpty) {
      return;
    }

    for (final part in value.split(',')) {
      final token = part.trim();
      if (token.isNotEmpty) {
        tokens.add(token);
      }
    }
  }

  String _joinSorted(Set<String> values) {
    if (values.isEmpty) {
      return '';
    }

    final sorted = values.toList()..sort();
    return sorted.join(', ');
  }

  bool _containsToken(String? value, String token) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    return value.toLowerCase().contains(token.toLowerCase());
  }

  Future<Map<String, Exercise>> _loadReferencedExercises(
    List<ProtocolStep> steps,
  ) async {
    final exerciseIds = steps
        .map((step) => step.exerciseId)
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final exercises = <String, Exercise>{};

    for (final exerciseId in exerciseIds) {
      final exercise = await _exerciseRepository.getExerciseById(exerciseId);
      if (exercise != null) {
        exercises[exerciseId] = exercise;
      }
    }

    return exercises;
  }
}

class _StepMovementProfile {
  const _StepMovementProfile({
    required this.push,
    required this.pull,
    required this.squat,
    required this.hinge,
    required this.lunge,
    required this.carry,
    required this.core,
    required this.running,
    required this.erg,
    required this.upperBody,
    required this.lowerBody,
    required this.hasAnyMovement,
  });

  final bool push;
  final bool pull;
  final bool squat;
  final bool hinge;
  final bool lunge;
  final bool carry;
  final bool core;
  final bool running;
  final bool erg;
  final bool upperBody;
  final bool lowerBody;
  final bool hasAnyMovement;
}
