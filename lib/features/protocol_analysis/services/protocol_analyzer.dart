import '../../../data/repositories/exercise_repository.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/protocol_step_repository.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol.dart';
import '../../../models/movement_profile.dart';
import '../../../models/protocol_analysis.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/protocol_step.dart';
import '../../../models/session_fingerprint.dart';

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

    // TODO(Fingerprint): weight fingerprint fields by reps, time, and distance.
    // TODO(Equipment Dependency): refine dependency from step-level equipment.
    // TODO(Density): calculate work density from step prescriptions in [steps].
    // TODO(Complexity): assess skill demand from [steps] and [exercises].
    // TODO(Running Percentage): measure running share from [steps].
    // TODO(Transition Density): refine from modality change frequency in [steps].
    // TODO(Substitution Difficulty): refine swap resistance from [steps] and [exercises].

    final movementProfile = _buildMovementProfile(steps, exercises);

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
      movementProfile: movementProfile,
      fingerprint: _buildSessionFingerprint(
        protocol: protocol,
        steps: steps,
        exercises: exercises,
        movementProfile: movementProfile,
      ),
    );
  }

  SessionFingerprint _buildSessionFingerprint({
    required Protocol protocol,
    required List<ProtocolStep> steps,
    required Map<String, Exercise> exercises,
    required MovementProfile movementProfile,
  }) {
    final structureType = _deriveStructureType(protocol, steps, exercises);
    final equipmentDependency = _deriveEquipmentDependency(protocol);
    final transitionDensity = _deriveTransitionDensity(
      structureType,
      steps.length,
    );

    return SessionFingerprint(
      structureType: structureType,
      pacingStyle: _derivePacingStyle(protocol, structureType),
      dominantStimulus: _deriveDominantStimulus(protocol),
      equipmentDependency: equipmentDependency,
      movementBias: _deriveMovementBias(movementProfile),
      transitionDensity: transitionDensity,
      substitutionDifficulty: _deriveSubstitutionDifficulty(
        protocol,
        equipmentDependency,
        transitionDensity,
      ),
    );
  }

  SessionStructureType _deriveStructureType(
    Protocol protocol,
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    final sessionType = _normalize(protocol.sessionType);

    switch (sessionType) {
      case 'circuit':
        return SessionStructureType.circuit;
      case 'amrap':
        return SessionStructureType.amrap;
      case 'emom':
        return SessionStructureType.emom;
      case 'intervals':
        return SessionStructureType.intervals;
      case 'strength':
      case 'hypertrophy':
        return SessionStructureType.strength;
      case 'running':
      case 'zone 2':
      case 'threshold run':
        return SessionStructureType.continuous;
      case 'conditioning':
        return SessionStructureType.continuous;
      case 'hybrid':
        if (steps.length >= 3) {
          return SessionStructureType.circuit;
        }
        return SessionStructureType.unknown;
      case 'benchmark':
        if (steps.length >= 3) {
          return SessionStructureType.circuit;
        }
        return SessionStructureType.strength;
      case 'recovery':
      case 'mobility':
        return steps.length <= 2
            ? SessionStructureType.continuous
            : SessionStructureType.circuit;
      default:
        return _inferStructureTypeFromSteps(steps, exercises);
    }
  }

  SessionStructureType _inferStructureTypeFromSteps(
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    if (steps.isEmpty) {
      return SessionStructureType.unknown;
    }

    if (steps.length == 1) {
      return SessionStructureType.strength;
    }

    final distinctStepTypes = steps
        .map((step) => _normalize(step.stepType))
        .where((type) => type.isNotEmpty)
        .toSet();

    if (steps.length >= 3 && distinctStepTypes.length >= 2) {
      return SessionStructureType.circuit;
    }

    final hasRunStep = steps.any((step) {
      return _isRunningStep(step, _exerciseForStep(step, exercises));
    });

    if (hasRunStep && steps.length <= 2) {
      return SessionStructureType.continuous;
    }

    return SessionStructureType.unknown;
  }

  SessionPacingStyle _derivePacingStyle(
    Protocol protocol,
    SessionStructureType structureType,
  ) {
    final sessionType = _normalize(protocol.sessionType);
    final demand = _normalize(protocol.demand);

    if (sessionType == 'emom' || sessionType == 'intervals') {
      return SessionPacingStyle.interval;
    }

    if (sessionType == 'amrap') {
      return SessionPacingStyle.density;
    }

    if (sessionType == 'recovery' ||
        sessionType == 'mobility' ||
        sessionType == 'strength') {
      return SessionPacingStyle.controlled;
    }

    if (sessionType == 'running' || sessionType == 'zone 2') {
      return SessionPacingStyle.steady;
    }

    if (sessionType == 'benchmark') {
      return SessionPacingStyle.maxEffort;
    }

    if (structureType == SessionStructureType.continuous) {
      return SessionPacingStyle.steady;
    }

    if (structureType == SessionStructureType.circuit) {
      if (demand == 'high' || demand == 'very high') {
        return SessionPacingStyle.density;
      }
      return SessionPacingStyle.maxEffort;
    }

    if (structureType == SessionStructureType.strength) {
      return SessionPacingStyle.controlled;
    }

    return SessionPacingStyle.unknown;
  }

  DominantStimulus _deriveDominantStimulus(Protocol protocol) {
    final trainingQuality = _normalize(protocol.trainingQuality);
    if (trainingQuality == 'recovery') {
      return DominantStimulus.recovery;
    }

    final capability = _normalize(protocol.goal);
    switch (capability) {
      case 'capacity':
        return DominantStimulus.capacity;
      case 'engine':
        return DominantStimulus.engine;
      case 'threshold':
        return DominantStimulus.threshold;
      case 'speed':
        return DominantStimulus.speed;
      case 'strength':
      case 'power':
        return DominantStimulus.strength;
      case 'hypertrophy':
        return DominantStimulus.hypertrophy;
      case 'recovery':
        return DominantStimulus.recovery;
      case 'mobility':
        return DominantStimulus.mobility;
      case 'mixed':
        return DominantStimulus.mixed;
      default:
        return DominantStimulus.unknown;
    }
  }

  EquipmentDependency _deriveEquipmentDependency(Protocol protocol) {
    final requiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      protocol.requiredEquipment,
    );

    if (requiredEquipment.isEmpty) {
      final legacyEquipment = _normalize(protocol.equipment);
      if (legacyEquipment.isEmpty || legacyEquipment == 'bodyweight') {
        return EquipmentDependency.low;
      }

      return _equipmentDependencyFromItems({legacyEquipment});
    }

    return _equipmentDependencyFromItems(requiredEquipment);
  }

  EquipmentDependency _equipmentDependencyFromItems(Set<String> items) {
    if (items.isEmpty) {
      return EquipmentDependency.low;
    }

    var hasHigh = false;
    var hasModerate = false;

    for (final item in items) {
      final normalized = _normalize(item);
      if (_isHighDependencyEquipment(normalized)) {
        hasHigh = true;
      } else if (_isModerateDependencyEquipment(normalized)) {
        hasModerate = true;
      } else if (!_isLowDependencyEquipment(normalized)) {
        hasModerate = true;
      }
    }

    if (hasHigh) {
      return EquipmentDependency.high;
    }
    if (hasModerate) {
      return EquipmentDependency.moderate;
    }

    return EquipmentDependency.low;
  }

  bool _isLowDependencyEquipment(String value) {
    return value == 'bodyweight' ||
        value == 'running shoes' ||
        value == 'none';
  }

  bool _isModerateDependencyEquipment(String value) {
    return value == 'minimal kit' ||
        value == 'dumbbell' ||
        value == 'kettlebell' ||
        value == 'bench' ||
        value == 'pull-up bar' ||
        value == 'wall ball';
  }

  bool _isHighDependencyEquipment(String value) {
    return value == 'bike erg' ||
        value == 'row erg' ||
        value == 'ski erg' ||
        value == 'bike' ||
        value == 'full gym' ||
        value == 'sandbag' ||
        value == 'barbell' ||
        value.contains('erg');
  }

  MovementBias _deriveMovementBias(MovementProfile profile) {
    if (profile.totalMovements == 0) {
      return MovementBias.mixed;
    }

    if (profile.runningPercent >= 40) {
      return MovementBias.runningDominant;
    }

    if (profile.upperBodyPercent >= 60) {
      return MovementBias.upperBody;
    }

    if (profile.lowerBodyPercent >= 60) {
      return MovementBias.lowerBody;
    }

    final patternPercents = <String, double>{
      'push': profile.pushPercent,
      'pull': profile.pullPercent,
      'squat': profile.squatPercent,
      'hinge': profile.hingePercent,
      'lunge': profile.lungePercent,
      'carry': profile.carryPercent,
      'core': profile.corePercent,
      'running': profile.runningPercent,
      'erg': profile.ergPercent,
    };

    final activePatterns = patternPercents.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (activePatterns.isEmpty) {
      return MovementBias.mixed;
    }

    final highest = activePatterns.first.value;
    final lowest = activePatterns.last.value;

    if (activePatterns.length >= 3 && (highest - lowest) <= 20) {
      return MovementBias.balanced;
    }

    if (highest >= 45) {
      switch (activePatterns.first.key) {
        case 'push':
          return MovementBias.pushDominant;
        case 'pull':
          return MovementBias.pullDominant;
        default:
          break;
      }
    }

    return MovementBias.mixed;
  }

  TransitionDensity _deriveTransitionDensity(
    SessionStructureType structureType,
    int stepCount,
  ) {
    if (stepCount <= 2) {
      return TransitionDensity.low;
    }

    if (structureType == SessionStructureType.circuit ||
        structureType == SessionStructureType.amrap) {
      if (stepCount >= 4) {
        return TransitionDensity.high;
      }
      return TransitionDensity.moderate;
    }

    if (structureType == SessionStructureType.emom ||
        structureType == SessionStructureType.intervals) {
      return TransitionDensity.moderate;
    }

    if (stepCount >= 6) {
      return TransitionDensity.high;
    }

    if (stepCount >= 3) {
      return TransitionDensity.moderate;
    }

    return TransitionDensity.low;
  }

  SubstitutionDifficulty _deriveSubstitutionDifficulty(
    Protocol protocol,
    EquipmentDependency equipmentDependency,
    TransitionDensity transitionDensity,
  ) {
    final adaptability = protocol.adaptability;
    if (adaptability != null) {
      if (adaptability >= 4) {
        return SubstitutionDifficulty.low;
      }
      if (adaptability == 3) {
        return SubstitutionDifficulty.moderate;
      }
      return SubstitutionDifficulty.high;
    }

    var score = 0;

    switch (equipmentDependency) {
      case EquipmentDependency.high:
        score += 2;
      case EquipmentDependency.moderate:
        score += 1;
      case EquipmentDependency.low:
        break;
    }

    if (transitionDensity == TransitionDensity.high) {
      score += 1;
    }

    if (protocol.runningRequired == true) {
      score += 1;
    }

    if (score >= 3) {
      return SubstitutionDifficulty.high;
    }
    if (score >= 1) {
      return SubstitutionDifficulty.moderate;
    }

    return SubstitutionDifficulty.low;
  }

  String _normalize(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  MovementProfile _buildMovementProfile(
    List<ProtocolStep> steps,
    Map<String, Exercise> exercises,
  ) {
    // v0.1 counts at most one increment per movement bucket per protocol step.
    // TODO: weight counts by reps, time, and distance from step prescriptions.
    // Percentages are derived on [MovementProfile] from these occurrence counts.

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
    final hasErg = _isErgStep(step, exercise);
    final hasRunning = !hasErg && _isRunningStep(step, exercise);

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
      if (_isRunningStep(step, _exerciseForStep(step, exercises))) {
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
      if (_isErgStep(step, _exerciseForStep(step, exercises))) {
        return true;
      }
    }

    return false;
  }

  bool _isRunningStep(ProtocolStep step, Exercise? exercise) {
    if (_isErgStep(step, exercise)) {
      return false;
    }

    if (_normalize(step.stepType) == 'run') {
      return true;
    }

    if (exercise != null && _isExplicitRunningExercise(exercise)) {
      return true;
    }

    if (_identifiesRunningInText(step.title)) {
      return true;
    }

    if (exercise != null && _identifiesRunningInText(exercise.name)) {
      return true;
    }

    return false;
  }

  bool _isErgStep(ProtocolStep step, Exercise? exercise) {
    if (_isErgRelatedText(step.title)) {
      return true;
    }

    if (exercise == null) {
      return false;
    }

    return _matchesPattern(exercise.movementPattern, 'erg') ||
        _isErgRelatedText(exercise.equipment) ||
        _isErgRelatedText(exercise.equipmentCategory) ||
        _isErgRelatedText(exercise.name);
  }

  bool _isExplicitRunningExercise(Exercise exercise) {
    if (_isErgRelatedText(exercise.name) ||
        _isErgRelatedText(exercise.equipment) ||
        _isErgRelatedText(exercise.equipmentCategory)) {
      return false;
    }

    if (_isExplicitRunningType(exercise.exerciseType)) {
      return true;
    }

    if (_isExplicitRunningType(exercise.category)) {
      return true;
    }

    return _matchesPattern(exercise.movementPattern, 'run');
  }

  bool _isExplicitRunningType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final lower = value.trim().toLowerCase();
    if (lower.contains('locomotion')) {
      return false;
    }

    return lower.contains('run');
  }

  bool _identifiesRunningInText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final lower = value.trim().toLowerCase();
    if (_isErgRelatedText(lower)) {
      return false;
    }

    const runningPhrases = [
      'threshold run',
      'trail run',
      'hill run',
      'tempo run',
      'easy run',
      'long run',
      'interval run',
      'fartlek',
      'sprint',
      'strides',
      'jogging',
    ];

    for (final phrase in runningPhrases) {
      if (lower.contains(phrase)) {
        return true;
      }
    }

    return RegExp(r'\brun(?:ning)?\b').hasMatch(lower) ||
        RegExp(r'\bjog(?:ging)?\b').hasMatch(lower);
  }

  bool _isErgRelatedText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }

    final lower = value.trim().toLowerCase();

    if (lower.contains('erg')) {
      return true;
    }

    if (lower.contains('bike')) {
      return true;
    }

    if (lower.contains('row erg') || lower.contains('rower')) {
      return true;
    }

    if (RegExp(r'\brow\b').hasMatch(lower) && lower.contains('erg')) {
      return true;
    }

    if (lower.contains('ski erg') || RegExp(r'\bski\b').hasMatch(lower)) {
      return true;
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
