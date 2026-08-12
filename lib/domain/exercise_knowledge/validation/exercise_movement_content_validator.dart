import '../models/coaching_content.dart';
import '../models/exercise_definition.dart';
import '../models/knowledge_content_common.dart';
import '../models/movement_standard.dart';
import '../models/video_reference.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'exercise_knowledge_validation_issue.dart';

/// Fail-closed validation for canonical movement-content bodies.
class ExerciseMovementContentValidator {
  const ExerciseMovementContentValidator({this.maxReplacementDepth = 8});

  final int maxReplacementDepth;

  List<ExerciseKnowledgeValidationIssue> validate({
    required List<ExerciseDefinition> definitions,
    required List<MovementStandard> movementStandards,
    required List<CoachingContent> coachingContents,
    required List<VideoReference> videoReferences,
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final records = <ExerciseKnowledgeContentRecord>[
      ...movementStandards,
      ...coachingContents,
      ...videoReferences,
    ];
    final definitionsById = {
      for (final definition in definitions) definition.id.value: definition,
    };

    final seenVersions = <String>{};
    final publishedByStableId = <String, ExerciseKnowledgeContentRecord>{};
    final byStableId = <String, List<ExerciseKnowledgeContentRecord>>{};
    final byAnyId = <String, List<ExerciseKnowledgeContentRecord>>{};

    for (final record in records) {
      final path =
          '${record.contentKind.wireValue}s[${record.id.value}:${record.version}]';
      final versionKey =
          '${record.contentKind.wireValue}:${record.id.value}:${record.version}';
      if (!seenVersions.add(versionKey)) {
        issues.add(
          _issue(
            path,
            'duplicate_content_version',
            'Duplicate content id and version.',
          ),
        );
      }
      byStableId
          .putIfAbsent(
            '${record.contentKind.wireValue}:${record.id.value}',
            () => [],
          )
          .add(record);
      byAnyId.putIfAbsent(record.id.value, () => []).add(record);

      if (record.version.trim().isEmpty) {
        issues.add(
          _issue(path, 'blank_content_version', 'Version is required.'),
        );
      }
      final definition = definitionsById[record.exerciseId.value];
      if (definition == null) {
        issues.add(
          _issue(
            '$path.exercise_id',
            'content_unknown_exercise',
            'Content references an unknown canonical exercise.',
          ),
        );
      } else if (record.lifecycleStatus == ExerciseLifecycleStatus.published &&
          definition.lifecycleStatus != ExerciseLifecycleStatus.published) {
        issues.add(
          _issue(
            '$path.exercise_id',
            'published_content_non_operational_exercise',
            'Published content requires a published exercise definition.',
          ),
        );
      }

      if (record.lifecycleStatus == ExerciseLifecycleStatus.published) {
        final stableKey = '${record.contentKind.wireValue}:${record.id.value}';
        if (publishedByStableId.containsKey(stableKey)) {
          issues.add(
            _issue(
              path,
              'conflicting_current_published_versions',
              'Only one current published version may exist for a stable id.',
            ),
          );
        } else {
          publishedByStableId[stableKey] = record;
        }
        issues.addAll(_validatePublishedCommon(record, path));
      }
    }

    for (final standard in movementStandards) {
      issues.addAll(_validateMovementStandard(standard));
    }
    for (final coaching in coachingContents) {
      issues.addAll(_validateCoachingContent(coaching));
    }
    for (final video in videoReferences) {
      issues.addAll(_validateVideoReference(video));
    }

    issues.addAll(
      _validateDefinitionReferences(
        definitions: definitions,
        publishedStandards: {
          for (final item in movementStandards.where(_published))
            item.id.value: item,
        },
        publishedCoaching: {
          for (final item in coachingContents.where(_published))
            item.id.value: item,
        },
        publishedVideos: {
          for (final item in videoReferences.where(_published))
            item.id.value: item,
        },
      ),
    );
    issues.addAll(_validateReplacements(records, byStableId, byAnyId));
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validatePublishedCommon(
    ExerciseKnowledgeContentRecord record,
    String path,
  ) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    if (record.reviewerId == null) {
      issues.add(
        _issue(
          '$path.reviewer',
          'published_content_missing_reviewer',
          'Published content requires an explicit reviewer.',
        ),
      );
    }
    if (record.reviewedAt == null || record.publishedAt == null) {
      issues.add(
        _issue(
          path,
          'published_content_missing_timestamps',
          'Published content requires reviewed_at and published_at.',
        ),
      );
    }
    if (record.provenance.sourceType.trim().isEmpty ||
        record.provenance.sourceReference.trim().isEmpty) {
      issues.add(
        _issue(
          '$path.provenance',
          'published_content_missing_provenance',
          'Published content requires source type and source reference.',
        ),
      );
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validateMovementStandard(
    MovementStandard standard,
  ) {
    if (standard.lifecycleStatus != ExerciseLifecycleStatus.published) {
      return const [];
    }
    final path = 'movement_standards[${standard.id.value}:${standard.version}]';
    final issues = <ExerciseKnowledgeValidationIssue>[];
    for (final entry in {
      'language': standard.language,
      'title': standard.title,
      'applicability_key': standard.applicabilityKey,
      'start_position': standard.startPosition,
    }.entries) {
      if (entry.value.trim().isEmpty) {
        issues.add(
          _issue(
            '$path.${entry.key}',
            'incomplete_published_movement_standard',
            'Published movement standards require ${entry.key}.',
          ),
        );
      }
    }
    if (standard.executionSequence.any(_blank) ||
        standard.executionSequence.isEmpty) {
      issues.add(
        _issue(
          '$path.execution_sequence',
          'incomplete_published_movement_standard',
          'Published movement standards require ordered execution steps.',
        ),
      );
    }
    if (standard.completionCriteria.any(_blank) ||
        standard.completionCriteria.isEmpty) {
      issues.add(
        _issue(
          '$path.completion_criteria',
          'incomplete_published_movement_standard',
          'Published movement standards require observable completion criteria.',
        ),
      );
    }
    if (standard.safetyBoundaryRefs.isEmpty &&
        standard.safetyNotes.every(_blank)) {
      issues.add(
        _issue(
          '$path.safety_notes',
          'published_standard_missing_safety_boundary',
          'Published standards require a non-clinical safety boundary.',
        ),
      );
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validateCoachingContent(
    CoachingContent coaching,
  ) {
    if (coaching.lifecycleStatus != ExerciseLifecycleStatus.published) {
      return const [];
    }
    final path = 'coaching_contents[${coaching.id.value}:${coaching.version}]';
    final issues = <ExerciseKnowledgeValidationIssue>[];
    if (coaching.language.trim().isEmpty || coaching.audience.trim().isEmpty) {
      issues.add(
        _issue(
          path,
          'incomplete_published_coaching_content',
          'Published coaching content requires language and audience.',
        ),
      );
    }
    final requiredLists = {
      'setup_guidance': coaching.setupGuidance,
      'execution_instructions': coaching.executionInstructions,
      'coaching_cues': coaching.coachingCues,
      'breathing_guidance': coaching.breathingGuidance,
      'safety_notes': coaching.safetyNotes,
    };
    for (final entry in requiredLists.entries) {
      if (entry.value.isEmpty || entry.value.any(_blank)) {
        issues.add(
          _issue(
            '$path.${entry.key}',
            'incomplete_published_coaching_content',
            'Published coaching content requires non-blank ${entry.key}.',
          ),
        );
      }
    }
    if (coaching.faultCorrections.isEmpty ||
        coaching.faultCorrections.any(
          (item) => item.fault.trim().isEmpty || item.correction.trim().isEmpty,
        )) {
      issues.add(
        _issue(
          '$path.fault_corrections',
          'incomplete_published_coaching_content',
          'Published faults require corresponding corrections.',
        ),
      );
    }
    if (coaching.regressionProgressionExplanation.trim().isEmpty) {
      issues.add(
        _issue(
          '$path.regression_progression_explanation',
          'incomplete_published_coaching_content',
          'Published coaching requires neutral regression/progression explanation.',
        ),
      );
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validateVideoReference(
    VideoReference video,
  ) {
    final path = 'video_references[${video.id.value}:${video.version}]';
    final issues = <ExerciseKnowledgeValidationIssue>[];
    if (video.durationSeconds != null && video.durationSeconds! <= 0) {
      issues.add(
        _issue(
          '$path.duration_seconds',
          'invalid_video_duration',
          'Video duration must be positive.',
        ),
      );
    }
    if (video.lifecycleStatus != ExerciseLifecycleStatus.published) {
      return issues;
    }
    if (video.purpose.trim().isEmpty || video.language.trim().isEmpty) {
      issues.add(
        _issue(
          path,
          'incomplete_published_video_reference',
          'Published video references require purpose and language.',
        ),
      );
    }
    final uriText = video.canonicalUri?.trim();
    if (uriText != null && uriText.isNotEmpty && !_validHttpsUri(uriText)) {
      issues.add(
        _issue(
          '$path.canonical_uri',
          'invalid_video_uri',
          'Published video URI must be canonical HTTPS with a host.',
        ),
      );
    }
    if (video.availability == VideoAvailabilityState.available) {
      if (video.providerKey == null ||
          uriText == null ||
          !_validHttpsUri(uriText) ||
          video.lastVerifiedAt == null) {
        issues.add(
          _issue(
            path,
            'available_video_missing_delivery_metadata',
            'Available video requires provider, HTTPS URI, and last verification.',
          ),
        );
      }
      if (_blankNullable(video.rightsBasis) ||
          _blankNullable(video.ownerOrLicensor) ||
          _blankNullable(video.attributionRequirements)) {
        issues.add(
          _issue(
            path,
            'available_video_missing_rights_metadata',
            'Available video requires rights, owner/licensor, and attribution.',
          ),
        );
      }
    }
    if (video.transcriptState == AccessibilityAvailabilityState.available &&
        video.transcriptReferenceId == null) {
      issues.add(
        _issue(
          '$path.transcript_reference_id',
          'available_transcript_missing_reference',
          'Available transcript state requires an explicit transcript reference.',
        ),
      );
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validateDefinitionReferences({
    required List<ExerciseDefinition> definitions,
    required Map<String, MovementStandard> publishedStandards,
    required Map<String, CoachingContent> publishedCoaching,
    required Map<String, VideoReference> publishedVideos,
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    for (final definition in definitions.where(_published)) {
      for (final ref in definition.movementStandardRefs) {
        final target = publishedStandards[ref.id.value];
        if (target == null || target.exerciseId != definition.id) {
          issues.add(
            _issue(
              'definitions[${definition.id.value}].movement_standard_refs',
              'unresolved_published_movement_standard_ref',
              'Published movement-standard reference must resolve in EX-* scope.',
            ),
          );
        }
      }
      for (final ref in definition.coachingContentRefs) {
        final target = publishedCoaching[ref.id.value];
        if (target == null || target.exerciseId != definition.id) {
          issues.add(
            _issue(
              'definitions[${definition.id.value}].coaching_content_refs',
              'unresolved_published_coaching_content_ref',
              'Published coaching reference must resolve in EX-* scope.',
            ),
          );
        }
      }
      for (final ref in definition.mediaRefs) {
        final target = publishedVideos[ref.id.value];
        if (ref.kind.name != 'video' ||
            target == null ||
            target.exerciseId != definition.id) {
          issues.add(
            _issue(
              'definitions[${definition.id.value}].media_refs',
              'unresolved_published_media_ref',
              'Published media reference must resolve to governed video metadata.',
            ),
          );
        }
      }
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> _validateReplacements(
    List<ExerciseKnowledgeContentRecord> records,
    Map<String, List<ExerciseKnowledgeContentRecord>> byStableId,
    Map<String, List<ExerciseKnowledgeContentRecord>> byAnyId,
  ) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    for (final record in records) {
      if (record.replacementId == null) continue;
      final path =
          '${record.contentKind.wireValue}s[${record.id.value}:${record.version}]';
      final visited = <String>{};
      var current = record;
      var depth = 0;
      while (current.replacementId != null) {
        final key = '${current.contentKind.wireValue}:${current.id.value}';
        if (!visited.add(key)) {
          issues.add(
            _issue(
              '$path.replacement_id',
              'replacement_cycle',
              'Replacement graph must be acyclic.',
            ),
          );
          break;
        }
        depth++;
        if (depth > maxReplacementDepth) {
          issues.add(
            _issue(
              '$path.replacement_id',
              'replacement_depth_exceeded',
              'Replacement graph exceeds maximum depth $maxReplacementDepth.',
            ),
          );
          break;
        }
        final targetKey =
            '${current.contentKind.wireValue}:${current.replacementId!.value}';
        final candidates = byStableId[targetKey] ?? const [];
        if (candidates.length != 1) {
          final wrongKind =
              byAnyId[current.replacementId!.value]?.any(
                (item) => item.contentKind != current.contentKind,
              ) ??
              false;
          issues.add(
            _issue(
              '$path.replacement_id',
              wrongKind
                  ? 'replacement_scope_mismatch'
                  : candidates.isEmpty
                  ? 'replacement_missing'
                  : 'replacement_ambiguous',
              wrongKind
                  ? 'Replacement must preserve content kind.'
                  : 'Replacement must resolve to exactly one compatible record.',
            ),
          );
          break;
        }
        final target = candidates.single;
        if (target.contentKind != current.contentKind ||
            target.exerciseId != current.exerciseId) {
          issues.add(
            _issue(
              '$path.replacement_id',
              'replacement_scope_mismatch',
              'Replacement must preserve content kind and canonical exercise.',
            ),
          );
          break;
        }
        if (target.lifecycleStatus == ExerciseLifecycleStatus.draft) {
          issues.add(
            _issue(
              '$path.replacement_id',
              'replacement_target_not_resolvable',
              'Replacement target must be published or retired.',
            ),
          );
          break;
        }
        current = target;
      }
    }
    return issues;
  }
}

bool _published(Object item) => switch (item) {
  ExerciseDefinition value =>
    value.lifecycleStatus == ExerciseLifecycleStatus.published,
  ExerciseKnowledgeContentRecord value =>
    value.lifecycleStatus == ExerciseLifecycleStatus.published,
  _ => false,
};

bool _blank(String value) => value.trim().isEmpty;

bool _blankNullable(String? value) => value == null || value.trim().isEmpty;

bool _validHttpsUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme.toLowerCase() == 'https' &&
      uri.host.trim().isNotEmpty;
}

ExerciseKnowledgeValidationIssue _issue(
  String path,
  String code,
  String message,
) => ExerciseKnowledgeValidationIssue(path: path, code: code, message: message);
