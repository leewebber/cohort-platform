import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/session_adaptation_metadata_codec.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../../models/workout_format.dart';

/// Code-based programme/session authoring (same models as Session Builder + FounderAcceptanceContent).
///
/// Import this module for founder/dev Dart definitions, then persist with
/// [ProgrammeCodeAuthoringPersistence].
class ProgrammeCodeAuthoringException implements Exception {
  ProgrammeCodeAuthoringException(this.messages);

  final List<String> messages;

  @override
  String toString() => messages.join(' ');
}

/// Validates adaptation metadata for code-authored sessions before model construction.
class ProgrammeCodeSessionAuthoringValidation {
  const ProgrammeCodeSessionAuthoringValidation._();

  static List<String> validate({
    SessionIntent? primarySessionIntent,
    List<SessionIntent> secondarySessionIntents = const [],
    int? minimumViableDurationMin,
    int? plannedDurationMin,
  }) {
    return SessionAdaptationMetadataValidation.validate(
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      minimumViableDurationMin: minimumViableDurationMin,
      plannedDurationMin: plannedDurationMin,
    );
  }

  static void validateOrThrow({
    SessionIntent? primarySessionIntent,
    List<SessionIntent> secondarySessionIntents = const [],
    int? minimumViableDurationMin,
    int? plannedDurationMin,
  }) {
    final messages = validate(
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      minimumViableDurationMin: minimumViableDurationMin,
      plannedDurationMin: plannedDurationMin,
    );
    if (messages.isNotEmpty) {
      throw ProgrammeCodeAuthoringException(messages);
    }
  }
}

/// Canonical code-authored block — same [SessionBlock] model as Session Builder.
SessionBlock block({
  required SessionBlockType type,
  String? title,
  String? localId,
  int position = 1,
  String content = '',
  WorkoutFormat workoutFormat = WorkoutFormat.none,
  TimerConfiguration? timerConfiguration,
  List<SessionBlockExerciseLink> linkedExercises = const [],
  String? coachNotes,
  BlockPerformanceCaptureMode performanceCaptureMode =
      BlockPerformanceCaptureMode.automatic,
  BlockPriority? blockPriority,
  BlockAdaptationPolicy? adaptationPolicy,
}) {
  final resolvedTitle = title?.trim().isNotEmpty == true
      ? title!.trim()
      : type.defaultTitle;

  return SessionBlock(
    localId: localId ?? 'block-code-${type.dbValue}-$position',
    blockType: type,
    title: resolvedTitle,
    content: content,
    workoutFormat: workoutFormat,
    timerConfiguration: timerConfiguration,
    linkedExercises: linkedExercises,
    coachNotes: coachNotes,
    position: position,
    performanceCaptureMode: performanceCaptureMode ==
            BlockPerformanceCaptureMode.automatic
        ? BlockPerformanceCaptureModeDb.resolveDefault(
            blockType: type,
            workoutFormat: workoutFormat,
          )
        : performanceCaptureMode,
    blockPriority: blockPriority,
    adaptationPolicy: adaptationPolicy,
  );
}

SessionBlockExerciseLink exerciseLink({
  required String exerciseId,
  required int position,
  String? localId,
  String? displayLabelOverride,
}) {
  return SessionBlockExerciseLink(
    localId: localId ?? 'link-code-$exerciseId-$position',
    exerciseId: exerciseId,
    position: position,
    displayLabelOverride: displayLabelOverride,
  );
}

/// Programme-bound session definition (same shape as embedded Session Builder saves).
ProtocolDraft programmeSession({
  required String protocolId,
  required String name,
  required String programmeVersionId,
  String? ownerId,
  String? sessionFormat,
  String? sessionType,
  int? durationMin,
  String? purpose,
  String? coachingNotes,
  SessionIntent? primarySessionIntent,
  List<SessionIntent> secondarySessionIntents = const [],
  int? minimumViableDurationMin,
  List<SessionBlock> blocks = const [],
  List<ProtocolStepDraft> steps = const [],
  bool validateAdaptationMetadata = true,
}) {
  if (validateAdaptationMetadata) {
    ProgrammeCodeSessionAuthoringValidation.validateOrThrow(
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      minimumViableDurationMin: minimumViableDurationMin,
      plannedDurationMin: durationMin,
    );
  }

  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    steps: steps,
    blocks: _renumberBlocks(blocks),
    published: false,
    contentKind: TrainingContentKind.session,
    authoringScope: TrainingAuthoringScope.programmeOnly,
    endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    programmeVersionId: programmeVersionId,
    ownerId: ownerId,
    sessionFormat: sessionFormat,
    sessionType: sessionType,
    durationMin: durationMin,
    purpose: purpose,
    coachingNotes: coachingNotes,
    primarySessionIntent: primarySessionIntent,
    secondarySessionIntents: secondarySessionIntents,
    minimumViableDurationMin: minimumViableDurationMin,
  );
}

/// Alias for [programmeSession] — concise founder / code programme authoring entry point.
ProtocolDraft session({
  required String protocolId,
  required String name,
  required String programmeVersionId,
  String? ownerId,
  String? sessionFormat,
  String? sessionType,
  int? durationMin,
  String? purpose,
  String? coachingNotes,
  SessionIntent? primarySessionIntent,
  List<SessionIntent> secondarySessionIntents = const [],
  int? minimumViableDurationMin,
  List<SessionBlock> blocks = const [],
  List<ProtocolStepDraft> steps = const [],
  bool validateAdaptationMetadata = true,
}) {
  return programmeSession(
    protocolId: protocolId,
    name: name,
    programmeVersionId: programmeVersionId,
    ownerId: ownerId,
    sessionFormat: sessionFormat,
    sessionType: sessionType,
    durationMin: durationMin,
    purpose: purpose,
    coachingNotes: coachingNotes,
    primarySessionIntent: primarySessionIntent,
    secondarySessionIntents: secondarySessionIntents,
    minimumViableDurationMin: minimumViableDurationMin,
    blocks: blocks,
    steps: steps,
    validateAdaptationMetadata: validateAdaptationMetadata,
  );
}

/// Reusable coach Session Library entry (same persistence path as library authoring).
ProtocolDraft reusableSession({
  required String protocolId,
  required String name,
  required String ownerId,
  String? sessionFormat,
  String? sessionType,
  int? durationMin,
  SessionIntent? primarySessionIntent,
  List<SessionIntent> secondarySessionIntents = const [],
  int? minimumViableDurationMin,
  List<SessionBlock> blocks = const [],
  List<ProtocolStepDraft> steps = const [],
  bool published = true,
  bool validateAdaptationMetadata = true,
}) {
  if (validateAdaptationMetadata) {
    ProgrammeCodeSessionAuthoringValidation.validateOrThrow(
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      minimumViableDurationMin: minimumViableDurationMin,
      plannedDurationMin: durationMin,
    );
  }

  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    steps: steps,
    blocks: _renumberBlocks(blocks),
    published: published,
    contentKind: TrainingContentKind.session,
    authoringScope: TrainingAuthoringScope.coachPrivate,
    endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    ownerId: ownerId,
    sessionFormat: sessionFormat,
    sessionType: sessionType,
    durationMin: durationMin,
    primarySessionIntent: primarySessionIntent,
    secondarySessionIntents: secondarySessionIntents,
    minimumViableDurationMin: minimumViableDurationMin,
  );
}

List<SessionBlock> _renumberBlocks(List<SessionBlock> blocks) {
  if (blocks.isEmpty) return const [];
  return [
    for (var i = 0; i < blocks.length; i++) blocks[i].copyWith(position: i + 1),
  ];
}
