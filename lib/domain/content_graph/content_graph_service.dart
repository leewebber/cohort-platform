import 'content_graph_canonical.dart';
import 'content_graph_models.dart';
import 'content_graph_store.dart';
import 'content_graph_vocabulary.dart';

class CompileResult {
  const CompileResult({
    required this.canonicalJson,
    required this.sha256,
  });

  final String canonicalJson;
  final String sha256;
}

class ContentGraphService {
  ContentGraphService({
    required this.store,
    this.canonicaliser = const ContentGraphCanonicaliser(),
    this.differ = const ContentGraphDiffer(),
  });

  final ContentGraphStore store;
  final ContentGraphCanonicaliser canonicaliser;
  final ContentGraphDiffer differ;

  ProgrammeVersion createDraftVersion({
    required ContentActor actor,
    required String programmeId,
    required String draftVersionId,
    String? cloneFromVersionId,
    String? label,
  }) {
    _requirePublisher(actor, programmeId: programmeId);
    final programme = _requireProgramme(programmeId);
    if (cloneFromVersionId != null) {
      return cloneDraftFromPublished(
        actor: actor,
        publishedVersionId: cloneFromVersionId,
        draftVersionId: draftVersionId,
        label: label,
      );
    }
    final next = _nextVersionNumber(programmeId);
    final draft = ProgrammeVersion(
      id: draftVersionId,
      programmeId: programme.id,
      versionNumber: next,
      lifecycle: ContentLifecycle.draft,
      ownerId: actor.publisherId,
      label: label ?? 'v$next',
    );
    store.putProgrammeVersion(draft);
    return draft;
  }

  ProgrammeVersion cloneDraftFromPublished({
    required ContentActor actor,
    required String publishedVersionId,
    required String draftVersionId,
    String? label,
  }) {
    final source = _requireVersion(publishedVersionId);
    if (source.lifecycle != ContentLifecycle.published) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Clone source must be a published version.',
      );
    }
    _requirePublisher(actor, programmeId: source.programmeId);
    final next = _nextVersionNumber(source.programmeId);
    final draft = ProgrammeVersion(
      id: draftVersionId,
      programmeId: source.programmeId,
      versionNumber: next,
      lifecycle: ContentLifecycle.draft,
      ownerId: actor.publisherId,
      label: label ?? 'v$next',
      supersedesVersionId: source.id,
      sourcePackageRef: source.sourcePackageRef,
    );
    store.putProgrammeVersion(draft);
    for (final placement in store.placementsForVersion(source.id).toList()) {
      store.putPlacement(
        ProgrammePlacement(
          id: '${placement.id}->$draftVersionId',
          programmeVersionId: draft.id,
          sessionTemplateVersionId: placement.sessionTemplateVersionId,
          weekNumber: placement.weekNumber,
          dayKey: placement.dayKey,
          slotOrder: placement.slotOrder,
          titleOverride: placement.titleOverride,
          progressionParameters: Map.of(placement.progressionParameters),
          adaptationPermission: placement.adaptationPermission,
          optional: placement.optional,
        ),
      );
    }
    return draft;
  }

  List<String> validateDraft(String programmeVersionId) {
    final version = _requireVersion(programmeVersionId);
    if (version.lifecycle != ContentLifecycle.draft) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Only drafts can be validated for publication.',
      );
    }
    final issues = <String>[];
    final placements = store.placementsForVersion(version.id).toList();
    if (placements.isEmpty) {
      issues.add('missing_placements');
    }
    final seenSlots = <String>{};
    final sessionIds = <String>{};
    for (final placement in placements) {
      final slot = '${placement.weekNumber}/${placement.dayKey}/${placement.slotOrder}';
      if (!seenSlots.add(slot)) {
        issues.add('duplicate_slot:$slot');
      }
      final session = store.sessionTemplateVersion(placement.sessionTemplateVersionId);
      if (session == null) {
        issues.add('unresolved_session:${placement.sessionTemplateVersionId}');
        continue;
      }
      if (session.lifecycle != ContentLifecycle.published) {
        issues.add('unpublished_session:${session.id}');
      }
      if (session.ownerId != version.ownerId) {
        issues.add('cross_namespace_session:${session.id}');
      }
      sessionIds.add(session.id);
    }
    for (final sessionId in sessionIds) {
      final blocks = store.blocksForSessionVersion(sessionId).toList();
      if (blocks.isEmpty) {
        issues.add('missing_blocks:$sessionId');
      }
      for (final block in blocks) {
        if (block.exerciseIds.isEmpty) {
          issues.add('missing_exercises:${block.id}');
        }
        for (final exerciseId in block.exerciseIds) {
          final exercise = store.exercise(exerciseId);
          if (exercise == null) {
            issues.add('unresolved_exercise:$exerciseId');
          } else if (exercise.unresolvedLegacy) {
            issues.add('legacy_unresolved_exercise:$exerciseId');
          }
        }
      }
    }
    return issues;
  }

  CompileResult compileDraft(String programmeVersionId) {
    final version = _requireVersion(programmeVersionId);
    final placements = store.placementsForVersion(version.id).toList();
    final sessionIds = placements.map((p) => p.sessionTemplateVersionId).toSet();
    final sessions = [
      for (final id in sessionIds) _requireSessionVersion(id),
    ];
    final blocks = [
      for (final id in sessionIds) ...store.blocksForSessionVersion(id),
    ];
    final json = canonicaliser.canonicalJson(
      version: version,
      placements: placements,
      sessionVersions: sessions,
      blocks: blocks,
    );
    return CompileResult(
      canonicalJson: json,
      sha256: canonicaliser.sha256Hex(json),
    );
  }

  ContentVersionDiff diffAgainstPrevious(String draftVersionId) {
    final draft = _requireVersion(draftVersionId);
    final priorId = draft.supersedesVersionId;
    if (priorId == null) {
      return ContentVersionDiff(
        fromVersionId: '',
        toVersionId: draft.id,
        entries: const [],
      );
    }
    final prior = _requireVersion(priorId);
    final fromBlocks = [
      for (final p in store.placementsForVersion(prior.id))
        ...store.blocksForSessionVersion(p.sessionTemplateVersionId),
    ];
    final toBlocks = [
      for (final p in store.placementsForVersion(draft.id))
        ...store.blocksForSessionVersion(p.sessionTemplateVersionId),
    ];
    return differ.diff(
      fromVersion: prior,
      toVersion: draft,
      fromPlacements: store.placementsForVersion(prior.id).toList(),
      toPlacements: store.placementsForVersion(draft.id).toList(),
      fromBlocks: fromBlocks,
      toBlocks: toBlocks,
    );
  }

  ProgrammeVersion publish({
    required ContentActor actor,
    required String programmeVersionId,
    bool setCatalogueDefault = false,
  }) {
    final version = _requireVersion(programmeVersionId);
    _requirePublisher(actor, programmeId: version.programmeId);
    if (version.lifecycle != ContentLifecycle.draft) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Only drafts may be published.',
      );
    }
    final issues = validateDraft(version.id);
    if (issues.isNotEmpty) {
      throw ContentGraphException(
        ContentGraphFailureCode.validationFailed,
        issues.join(','),
      );
    }
    final compiled = compileDraft(version.id);
    for (final other in store.versionsForProgramme(version.programmeId)) {
      if (other.lifecycle == ContentLifecycle.published &&
          other.canonicalHash == compiled.sha256) {
        throw const ContentGraphException(
          ContentGraphFailureCode.identicalCanonicalContent,
          'Identical canonical content is already published.',
        );
      }
    }
    final published = version.copyWith(
      lifecycle: ContentLifecycle.published,
      canonicalHash: compiled.sha256,
      catalogueDefault: setCatalogueDefault,
    );
    store.putProgrammeVersion(published);
    if (setCatalogueDefault) {
      setCatalogueDefaultVersion(
        actor: actor,
        programmeVersionId: published.id,
      );
    }
    return _requireVersion(published.id);
  }

  ProgrammeVersion retire({
    required ContentActor actor,
    required String programmeVersionId,
  }) {
    final version = _requireVersion(programmeVersionId);
    _requirePublisher(actor, programmeId: version.programmeId);
    if (version.lifecycle != ContentLifecycle.published) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Only published versions may be retired.',
      );
    }
    final retired = version.copyWith(
      lifecycle: ContentLifecycle.retired,
      catalogueDefault: false,
    );
    store.putProgrammeVersion(retired);
    return retired;
  }

  void setCatalogueDefaultVersion({
    required ContentActor actor,
    required String programmeVersionId,
  }) {
    final version = _requireVersion(programmeVersionId);
    _requirePublisher(actor, programmeId: version.programmeId);
    if (version.lifecycle != ContentLifecycle.published) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Catalogue default must be a published version.',
      );
    }
    for (final other in store.versionsForProgramme(version.programmeId).toList()) {
      if (other.catalogueDefault && other.id != version.id) {
        store.putProgrammeVersion(other.copyWith(catalogueDefault: false));
      }
    }
    store.putProgrammeVersion(version.copyWith(catalogueDefault: true));
  }

  ProgrammeVersion defaultPublishedVersion(String programmeId) {
    final defaults = store
        .versionsForProgramme(programmeId)
        .where(
          (v) =>
              v.catalogueDefault && v.lifecycle == ContentLifecycle.published,
        )
        .toList();
    if (defaults.length != 1) {
      throw const ContentGraphException(
        ContentGraphFailureCode.ambiguousReference,
        'Catalogue default version is not unique.',
      );
    }
    return defaults.single;
  }

  PinnedAssignment enrol({
    required String assignmentId,
    required String athleteId,
    required String programmeId,
  }) {
    final selected = defaultPublishedVersion(programmeId);
    final assignment = PinnedAssignment(
      id: assignmentId,
      athleteId: athleteId,
      programmeVersionId: selected.id,
      active: true,
    );
    store.putAssignment(assignment);
    return assignment;
  }

  PinnedAssignment resolveAssignment(String assignmentId) {
    final assignment = store.assignment(assignmentId);
    if (assignment == null) {
      throw const ContentGraphException(
        ContentGraphFailureCode.notFound,
        'Assignment not found.',
      );
    }
    return assignment;
  }

  UsedByProjection usedByExercise(String exerciseId) {
    final hits = <UsedByHit>[];
    final programmeIds = <String>{};
    for (final block in store.blocksUsingExercise(exerciseId)) {
      hits.add(
        UsedByHit(
          nodeId: block.id,
          nodeType: ContentNodeType.authoredBlock,
          scope: ContentUsageScope.published,
          direct: true,
          label: block.title,
        ),
      );
      final session = _requireSessionVersion(block.sessionTemplateVersionId);
      hits.add(
        UsedByHit(
          nodeId: session.id,
          nodeType: ContentNodeType.sessionTemplateVersion,
          scope: _scopeFor(session.lifecycle),
          direct: true,
        ),
      );
      for (final placement in store.placementsUsingSession(session.id)) {
        final version = _requireVersion(placement.programmeVersionId);
        hits.add(
          UsedByHit(
            nodeId: version.id,
            nodeType: ContentNodeType.programmeVersion,
            scope: _scopeFor(version.lifecycle),
            direct: false,
          ),
        );
        programmeIds.add(version.id);
      }
    }
    final active = programmeIds.fold<int>(
      0,
      (sum, id) =>
          sum + store.assignmentsForVersion(id).where((a) => a.active).length,
    );
    return UsedByProjection(
      subjectId: exerciseId,
      subjectType: ContentNodeType.exercise,
      hits: hits,
      activeAssignmentCount: active,
    );
  }

  UsedByProjection usedBySessionTemplateVersion(String sessionTemplateVersionId) {
    final hits = <UsedByHit>[];
    final programmeIds = <String>{};
    for (final placement in store.placementsUsingSession(
      sessionTemplateVersionId,
    )) {
      final version = _requireVersion(placement.programmeVersionId);
      hits.add(
        UsedByHit(
          nodeId: version.id,
          nodeType: ContentNodeType.programmeVersion,
          scope: _scopeFor(version.lifecycle),
          direct: true,
          label: '${placement.weekNumber}/${placement.dayKey}/${placement.slotOrder}',
        ),
      );
      programmeIds.add(version.id);
    }
    final active = programmeIds.fold<int>(
      0,
      (sum, id) =>
          sum + store.assignmentsForVersion(id).where((a) => a.active).length,
    );
    return UsedByProjection(
      subjectId: sessionTemplateVersionId,
      subjectType: ContentNodeType.sessionTemplateVersion,
      hits: hits,
      activeAssignmentCount: active,
    );
  }

  Map<String, Object?> programmeVersionContents(String programmeVersionId) {
    final version = _requireVersion(programmeVersionId);
    final placements = store.placementsForVersion(version.id).toList();
    final sessionIds = placements.map((p) => p.sessionTemplateVersionId).toSet();
    final exerciseIds = <String>{};
    final equipment = <String>{};
    for (final sessionId in sessionIds) {
      for (final block in store.blocksForSessionVersion(sessionId)) {
        exerciseIds.addAll(block.exerciseIds);
      }
    }
    return {
      'programme_version_id': version.id,
      'lifecycle': version.lifecycle.name,
      'session_template_version_ids': sessionIds.toList()..sort(),
      'exercise_ids': exerciseIds.toList()..sort(),
      'equipment': equipment.toList()..sort(),
      'assignment_ids': store
          .assignmentsForVersion(version.id)
          .map((a) => a.id)
          .toList()
        ..sort(),
      'placement_count': placements.length,
    };
  }

  ContentUsageScope _scopeFor(ContentLifecycle lifecycle) {
    switch (lifecycle) {
      case ContentLifecycle.draft:
        return ContentUsageScope.draft;
      case ContentLifecycle.published:
        return ContentUsageScope.published;
      case ContentLifecycle.retired:
        return ContentUsageScope.retired;
    }
  }

  int _nextVersionNumber(String programmeId) {
    var max = 0;
    for (final version in store.versionsForProgramme(programmeId)) {
      if (version.versionNumber > max) max = version.versionNumber;
    }
    return max + 1;
  }

  void _requirePublisher(ContentActor actor, {required String programmeId}) {
    if (actor.role == ContentAuthRole.reader) {
      throw const ContentGraphException(
        ContentGraphFailureCode.unauthorized,
        'Reader cannot mutate content.',
      );
    }
    final programme = _requireProgramme(programmeId);
    if (programme.ownerId != actor.publisherId) {
      throw const ContentGraphException(
        ContentGraphFailureCode.namespaceIsolation,
        'Publisher cannot mutate another namespace.',
      );
    }
  }

  ProgrammeIdentity _requireProgramme(String id) {
    final programme = store.programme(id);
    if (programme == null) {
      throw const ContentGraphException(
        ContentGraphFailureCode.notFound,
        'Programme not found.',
      );
    }
    return programme;
  }

  ProgrammeVersion _requireVersion(String id) {
    final version = store.programmeVersion(id);
    if (version == null) {
      throw const ContentGraphException(
        ContentGraphFailureCode.notFound,
        'Programme version not found.',
      );
    }
    return version;
  }

  SessionTemplateVersion _requireSessionVersion(String id) {
    final session = store.sessionTemplateVersion(id);
    if (session == null) {
      throw const ContentGraphException(
        ContentGraphFailureCode.unresolvedReference,
        'Session-template version not found.',
      );
    }
    return session;
  }
}
