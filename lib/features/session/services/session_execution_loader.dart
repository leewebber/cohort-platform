import '../../../data/repositories/exercise_repository.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/protocol_step_repository.dart';
import '../../../data/repositories/session_block_repository.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol.dart';
import '../../../models/session_block.dart';
import '../models/session_execution_plan.dart';
import 'legacy_step_to_block_converter.dart';

class SessionExecutionLoadResult {
  const SessionExecutionLoadResult({required this.plan});

  final SessionExecutionPlan plan;
}

class SessionExecutionLoader {
  SessionExecutionLoader({
    ProtocolRepository? protocolRepository,
    ProtocolStepRepository? protocolStepRepository,
    SessionBlockRepository? sessionBlockRepository,
    ExerciseRepository? exerciseRepository,
    LegacyStepToBlockConverter? legacyConverter,
  })  : _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _protocolStepRepository =
            protocolStepRepository ?? const ProtocolStepRepository(),
        _sessionBlockRepository =
            sessionBlockRepository ?? const SessionBlockRepository(),
        _exerciseRepository = exerciseRepository ?? ExerciseRepository(),
        _legacyConverter = legacyConverter ?? const LegacyStepToBlockConverter();

  final ProtocolRepository _protocolRepository;
  final ProtocolStepRepository _protocolStepRepository;
  final SessionBlockRepository _sessionBlockRepository;
  final ExerciseRepository _exerciseRepository;
  final LegacyStepToBlockConverter _legacyConverter;

  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
  }) async {
    final trimmedId = protocolId.trim();
    final protocol = await _protocolRepository.getProtocolById(trimmedId);

    var blocks = await _sessionBlockRepository.getSessionBlocks(trimmedId);
    if (blocks.isEmpty) {
      final steps = await _protocolStepRepository.getProtocolSteps(trimmedId);
      blocks = _legacyConverter.convertStepsToBlocks(steps);
    }

    final exercisesById = await _loadExercises(blocks);
    final executionBlocks = blocks
        .map(
          (block) => SessionExecutionBlock.fromSessionBlock(
            block,
            exercisesById: exercisesById,
          ),
        )
        .toList(growable: false);

    final title = _resolveTitle(
      displayTitle: displayTitle,
      protocol: protocol,
      protocolId: trimmedId,
    );

    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: trimmedId,
        sessionTitle: title,
        blocks: executionBlocks,
        protocol: protocol,
        durationMin: protocol?.durationMin,
        coachNotes: protocol?.coachingNotes,
        programmeContextLabel: programmeContextLabel,
      ),
    );
  }

  Future<Map<String, Exercise>> _loadExercises(List<SessionBlock> blocks) async {
    final ids = <String>{};
    for (final block in blocks) {
      for (final link in block.linkedExercises) {
        if (link.exerciseId.trim().isNotEmpty) {
          ids.add(link.exerciseId.trim());
        }
      }
    }

    final exercises = <String, Exercise>{};
    for (final id in ids) {
      final exercise = await _exerciseRepository.getExerciseById(id);
      if (exercise != null) exercises[id] = exercise;
    }
    return exercises;
  }

  String _resolveTitle({
    required String? displayTitle,
    required Protocol? protocol,
    required String protocolId,
  }) {
    final fromDisplay = displayTitle?.trim();
    if (fromDisplay != null && fromDisplay.isNotEmpty) return fromDisplay;

    final fromProtocol = protocol?.name.trim();
    if (fromProtocol != null && fromProtocol.isNotEmpty) return fromProtocol;

    return protocolId;
  }
}
