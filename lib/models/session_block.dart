import '../domain/adaptation/adaptation_domain.dart';
import 'block_performance_capture_mode.dart';
import 'session_block_adaptation_metadata_codec.dart';
import 'session_block_exercise_link.dart';
import 'session_block_type.dart';
import 'timer_configuration.dart';
import 'workout_format.dart';

/// Modular ordered unit of Session content (M6).
class SessionBlock {
  const SessionBlock({
    required this.localId,
    required this.blockType,
    required this.title,
    required this.content,
    required this.workoutFormat,
    required this.position,
    this.persistedId,
    this.timerConfiguration,
    this.linkedExercises = const [],
    this.coachNotes,
    this.performanceCaptureMode = BlockPerformanceCaptureMode.automatic,
    this.blockPriority,
    this.adaptationPolicy,
  });

  final String localId;
  final String? persistedId;
  final SessionBlockType blockType;
  final String title;
  final String content;
  final WorkoutFormat workoutFormat;
  final TimerConfiguration? timerConfiguration;
  final List<SessionBlockExerciseLink> linkedExercises;
  final String? coachNotes;
  final int position;
  final BlockPerformanceCaptureMode performanceCaptureMode;

  /// Explicit authored block priority; null means use type default at read time.
  final BlockPriority? blockPriority;

  /// Explicit authored adaptation policy; null means use type default at read time.
  final BlockAdaptationPolicy? adaptationPolicy;

  BlockPriority get effectiveBlockPriority =>
      blockPriority ??
      SessionBlockTypeAdaptationPolicy.defaultPriority(blockType);

  BlockAdaptationPolicy get effectiveAdaptationPolicy =>
      adaptationPolicy ??
      SessionBlockTypeAdaptationPolicy.defaultAdaptationPolicy(blockType);

  String get stableId => persistedId ?? 'legacy-$position';

  BlockAdaptationMetadata get explicitBlockAdaptationMetadata =>
      BlockAdaptationMetadata(
        blockTypeDbValue: blockType.dbValue,
        priority: blockPriority,
        adaptationPolicy: adaptationPolicy,
      );

  Map<String, dynamic> explicitAdaptationMetadataToMap() {
    final map = <String, dynamic>{};
    SessionBlockAdaptationMetadataCodec.writeExplicitToMap(
      target: map,
      blockPriority: blockPriority,
      adaptationPolicy: adaptationPolicy,
    );
    return map;
  }

  SessionBlock copyWith({
    String? localId,
    String? persistedId,
    SessionBlockType? blockType,
    String? title,
    String? content,
    WorkoutFormat? workoutFormat,
    TimerConfiguration? timerConfiguration,
    List<SessionBlockExerciseLink>? linkedExercises,
    String? coachNotes,
    int? position,
    BlockPerformanceCaptureMode? performanceCaptureMode,
    BlockPriority? blockPriority,
    BlockAdaptationPolicy? adaptationPolicy,
    bool clearTimerConfiguration = false,
    bool clearCoachNotes = false,
    bool clearBlockPriority = false,
    bool clearAdaptationPolicy = false,
  }) {
    return SessionBlock(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      blockType: blockType ?? this.blockType,
      title: title ?? this.title,
      content: content ?? this.content,
      workoutFormat: workoutFormat ?? this.workoutFormat,
      timerConfiguration: clearTimerConfiguration
          ? null
          : (timerConfiguration ?? this.timerConfiguration),
      linkedExercises: linkedExercises ?? this.linkedExercises,
      coachNotes: clearCoachNotes ? null : (coachNotes ?? this.coachNotes),
      position: position ?? this.position,
      performanceCaptureMode:
          performanceCaptureMode ?? this.performanceCaptureMode,
      blockPriority:
          clearBlockPriority ? null : (blockPriority ?? this.blockPriority),
      adaptationPolicy: clearAdaptationPolicy
          ? null
          : (adaptationPolicy ?? this.adaptationPolicy),
    );
  }

  SessionBlock withBlockAdaptationMetadata(BlockAdaptationMetadata metadata) {
    return copyWith(
      blockPriority: metadata.priority,
      adaptationPolicy: metadata.adaptationPolicy,
    );
  }

  Map<String, dynamic> toRowMap({required String sessionId}) {
    final map = <String, dynamic>{
      if (persistedId != null) 'block_id': persistedId,
      'session_id': sessionId,
      'block_type': blockType.dbValue,
      'title': title.trim(),
      'content': content,
      'workout_format': workoutFormat.dbValue,
      'timer_config': timerConfiguration?.toJson(),
      'coach_notes': _nullable(coachNotes),
      'position': position,
      'performance_capture_mode': performanceCaptureMode.dbValue,
    };
    SessionBlockAdaptationMetadataCodec.writeExplicitToMap(
      target: map,
      blockPriority: blockPriority,
      adaptationPolicy: adaptationPolicy,
    );
    return map;
  }

  factory SessionBlock.fromRow(
    Map<String, dynamic> row, {
    List<SessionBlockExerciseLink> linkedExercises = const [],
  }) {
    final timerRaw = row['timer_config'];
    TimerConfiguration? timer;
    if (timerRaw is Map<String, dynamic>) {
      timer = TimerConfiguration.fromJson(timerRaw);
    } else if (timerRaw is Map) {
      timer = TimerConfiguration.fromJson(
        Map<String, dynamic>.from(timerRaw),
      );
    }

    return SessionBlock(
      localId: 'block-${row['block_id']}',
      persistedId: row['block_id']?.toString(),
      blockType: SessionBlockTypeDb.fromDb(row['block_type']?.toString()),
      title: row['title']?.toString() ?? '',
      content: row['content']?.toString() ?? '',
      workoutFormat: WorkoutFormatDb.fromDb(row['workout_format']?.toString()),
      timerConfiguration: timer,
      linkedExercises: linkedExercises,
      coachNotes: row['coach_notes']?.toString(),
      position: row['position'] as int? ?? 1,
      performanceCaptureMode: BlockPerformanceCaptureModeDb.fromDb(
        row['performance_capture_mode']?.toString(),
      ),
      blockPriority: SessionBlockAdaptationMetadataCodec.parseBlockPriority(
        row[SessionBlockAdaptationMetadataKeys.blockPriority],
      ),
      adaptationPolicy: SessionBlockAdaptationMetadataCodec.parseAdaptationPolicy(
        row[SessionBlockAdaptationMetadataKeys.adaptationPolicy],
      ),
    );
  }

  static SessionBlock mergeAdaptationFromRow({
    required SessionBlock block,
    required Map<String, dynamic> row,
  }) {
    final hasPriority = row.containsKey(
      SessionBlockAdaptationMetadataKeys.blockPriority,
    );
    final hasPolicy = row.containsKey(
      SessionBlockAdaptationMetadataKeys.adaptationPolicy,
    );
    if (!hasPriority && !hasPolicy) {
      return block;
    }

    return block.copyWith(
      blockPriority: hasPriority
          ? SessionBlockAdaptationMetadataCodec.parseBlockPriority(
              row[SessionBlockAdaptationMetadataKeys.blockPriority],
            )
          : block.blockPriority,
      adaptationPolicy: hasPolicy
          ? SessionBlockAdaptationMetadataCodec.parseAdaptationPolicy(
              row[SessionBlockAdaptationMetadataKeys.adaptationPolicy],
            )
          : block.adaptationPolicy,
    );
  }

  static SessionBlock create({
    required SessionBlockType blockType,
    required int position,
  }) {
    return SessionBlock(
      localId: 'block-local-${DateTime.now().microsecondsSinceEpoch}-$position',
      blockType: blockType,
      title: blockType.defaultTitle,
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: position,
      performanceCaptureMode: BlockPerformanceCaptureModeDb.resolveDefault(
        blockType: blockType,
        workoutFormat: WorkoutFormat.none,
      ),
    );
  }

  SessionBlock deepClone({required int position, String? titleSuffix}) {
    final clonedLinks = linkedExercises
        .asMap()
        .entries
        .map(
          (entry) => SessionBlockExerciseLink(
            localId:
                'link-clone-${DateTime.now().microsecondsSinceEpoch}-${entry.key}',
            exerciseId: entry.value.exerciseId,
            position: entry.value.position,
            displayLabelOverride: entry.value.displayLabelOverride,
            prescription: entry.value.prescription,
          ),
        )
        .toList(growable: false);

    return SessionBlock(
      localId: 'block-clone-${DateTime.now().microsecondsSinceEpoch}-$position',
      blockType: blockType,
      title: titleSuffix == null ? title : '$title$titleSuffix',
      content: content,
      workoutFormat: workoutFormat,
      timerConfiguration: timerConfiguration == null
          ? null
          : TimerConfiguration.fromJson(timerConfiguration!.toJson()),
      linkedExercises: clonedLinks,
      coachNotes: coachNotes,
      position: position,
      performanceCaptureMode: performanceCaptureMode,
      blockPriority: blockPriority,
      adaptationPolicy: adaptationPolicy == null
          ? null
          : BlockAdaptationPolicy.fromJson(adaptationPolicy!.toJson()),
    );
  }

  bool get hasMeaningfulContent {
    if (content.trim().isNotEmpty) return true;
    if (linkedExercises.any((link) => link.hasStructuredPrescription)) {
      return true;
    }
    if (linkedExercises.isNotEmpty) return true;
    if (workoutFormat != WorkoutFormat.none &&
        timerConfiguration != null &&
        timerConfiguration!.validateForFormat(workoutFormat).isEmpty) {
      return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionBlock &&
        other.localId == localId &&
        other.persistedId == persistedId &&
        other.blockType == blockType &&
        other.title == title &&
        other.content == content &&
        other.workoutFormat == workoutFormat &&
        other.timerConfiguration == timerConfiguration &&
        _linkedExercisesEqual(other.linkedExercises, linkedExercises) &&
        other.coachNotes == coachNotes &&
        other.position == position &&
        other.performanceCaptureMode == performanceCaptureMode &&
        other.blockPriority == blockPriority &&
        _adaptationPolicyEqual(other.adaptationPolicy, adaptationPolicy);
  }

  @override
  int get hashCode => Object.hash(
        localId,
        persistedId,
        blockType,
        title,
        content,
        workoutFormat,
        timerConfiguration,
        Object.hashAll(linkedExercises),
        coachNotes,
        position,
        performanceCaptureMode,
        blockPriority,
        adaptationPolicy?.toJson().toString(),
      );

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool _linkedExercisesEqual(
    List<SessionBlockExerciseLink> a,
    List<SessionBlockExerciseLink> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _adaptationPolicyEqual(
    BlockAdaptationPolicy? a,
    BlockAdaptationPolicy? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.canRemove == b.canRemove &&
        a.canShorten == b.canShorten &&
        a.canReduceVolume == b.canReduceVolume &&
        a.canReduceIntensity == b.canReduceIntensity &&
        a.canIncreaseRest == b.canIncreaseRest &&
        a.canSuperset == b.canSuperset &&
        a.canReplaceExercises == b.canReplaceExercises &&
        a.canReplaceBlock == b.canReplaceBlock &&
        a.minimumViablePrescription == b.minimumViablePrescription &&
        _stringListEqual(a.dependsOnBlockIds, b.dependsOnBlockIds);
  }

  static bool _stringListEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
