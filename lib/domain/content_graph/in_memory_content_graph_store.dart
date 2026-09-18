import 'content_graph_models.dart';
import 'content_graph_store.dart';
import 'content_graph_vocabulary.dart';

class InMemoryContentGraphStore implements ContentGraphStore {
  final publishers = <String, ContentPublisher>{};
  final exercises = <String, ContentExercise>{};
  final sessionTemplates = <String, SessionTemplate>{};
  final sessionTemplateVersions = <String, SessionTemplateVersion>{};
  final blocks = <String, AuthoredBlock>{};
  final programmes = <String, ProgrammeIdentity>{};
  final programmeVersions = <String, ProgrammeVersion>{};
  final placements = <String, ProgrammePlacement>{};
  final assignments = <String, PinnedAssignment>{};
  final occurrences = <String, DerivedOccurrence>{};

  @override
  ContentPublisher? publisher(String id) => publishers[id];
  @override
  ProgrammeIdentity? programme(String id) => programmes[id];
  @override
  ProgrammeVersion? programmeVersion(String id) => programmeVersions[id];
  @override
  SessionTemplate? sessionTemplate(String id) => sessionTemplates[id];
  @override
  SessionTemplateVersion? sessionTemplateVersion(String id) =>
      sessionTemplateVersions[id];
  @override
  ContentExercise? exercise(String id) => exercises[id];
  @override
  AuthoredBlock? block(String id) => blocks[id];
  @override
  PinnedAssignment? assignment(String id) => assignments[id];

  @override
  Iterable<ProgrammeVersion> versionsForProgramme(String programmeId) {
    return programmeVersions.values.where((v) => v.programmeId == programmeId);
  }

  @override
  Iterable<ProgrammePlacement> placementsForVersion(String programmeVersionId) {
    return placements.values.where(
      (p) => p.programmeVersionId == programmeVersionId,
    );
  }

  @override
  Iterable<AuthoredBlock> blocksForSessionVersion(
    String sessionTemplateVersionId,
  ) {
    return blocks.values.where(
      (b) => b.sessionTemplateVersionId == sessionTemplateVersionId,
    );
  }

  @override
  Iterable<PinnedAssignment> assignmentsForVersion(String programmeVersionId) {
    return assignments.values.where(
      (a) => a.programmeVersionId == programmeVersionId,
    );
  }

  @override
  Iterable<DerivedOccurrence> occurrencesForAssignment(String assignmentId) {
    return occurrences.values.where((o) => o.assignmentId == assignmentId);
  }

  @override
  Iterable<ProgrammePlacement> placementsUsingSession(
    String sessionTemplateVersionId,
  ) {
    return placements.values.where(
      (p) => p.sessionTemplateVersionId == sessionTemplateVersionId,
    );
  }

  @override
  Iterable<AuthoredBlock> blocksUsingExercise(String exerciseId) {
    return blocks.values.where((b) => b.exerciseIds.contains(exerciseId));
  }

  @override
  void putPublisher(ContentPublisher publisher) =>
      publishers[publisher.id] = publisher;
  @override
  void putExercise(ContentExercise exercise) => exercises[exercise.id] = exercise;
  @override
  void putSessionTemplate(SessionTemplate template) =>
      sessionTemplates[template.id] = template;
  @override
  void putSessionTemplateVersion(SessionTemplateVersion version) {
    final existing = sessionTemplateVersions[version.id];
    if (existing?.lifecycle == ContentLifecycle.published &&
        version.lifecycle == ContentLifecycle.draft) {
      throw const ContentGraphException(
        ContentGraphFailureCode.publishedImmutable,
        'Cannot edit a published session-template version in place.',
      );
    }
    sessionTemplateVersions[version.id] = version;
  }

  @override
  void putBlock(AuthoredBlock block) {
    final session = sessionTemplateVersions[block.sessionTemplateVersionId];
    if (session?.lifecycle == ContentLifecycle.published) {
      throw const ContentGraphException(
        ContentGraphFailureCode.publishedImmutable,
        'Cannot mutate a published session-template version.',
      );
    }
    blocks[block.id] = block;
  }

  @override
  void putProgramme(ProgrammeIdentity programme) =>
      programmes[programme.id] = programme;

  @override
  void putProgrammeVersion(ProgrammeVersion version) {
    final existing = programmeVersions[version.id];
    if (existing?.lifecycle == ContentLifecycle.published &&
        version.lifecycle == ContentLifecycle.draft) {
      throw const ContentGraphException(
        ContentGraphFailureCode.publishedImmutable,
        'Cannot reopen a published programme version as a draft.',
      );
    }
    if (existing?.lifecycle == ContentLifecycle.published &&
        version.lifecycle == ContentLifecycle.published &&
        _publishedContentChanged(existing!, version)) {
      throw const ContentGraphException(
        ContentGraphFailureCode.publishedImmutable,
        'Cannot edit a published programme version in place.',
      );
    }
    programmeVersions[version.id] = version;
  }

  @override
  void putPlacement(ProgrammePlacement placement) {
    final version = programmeVersions[placement.programmeVersionId];
    if (version?.lifecycle == ContentLifecycle.published) {
      throw const ContentGraphException(
        ContentGraphFailureCode.publishedImmutable,
        'Cannot mutate placements of a published programme version.',
      );
    }
    placements[placement.id] = placement;
  }

  @override
  void putAssignment(PinnedAssignment assignment) =>
      assignments[assignment.id] = assignment;
  @override
  void putOccurrence(DerivedOccurrence occurrence) =>
      occurrences[occurrence.id] = occurrence;

  @override
  void removeDraftVersion(String programmeVersionId) {
    final version = programmeVersions[programmeVersionId];
    if (version == null) return;
    if (version.lifecycle != ContentLifecycle.draft) {
      throw const ContentGraphException(
        ContentGraphFailureCode.illegalLifecycle,
        'Only unreferenced drafts may be deleted.',
      );
    }
    if (assignmentsForVersion(programmeVersionId).isNotEmpty) {
      throw const ContentGraphException(
        ContentGraphFailureCode.assignmentPinned,
        'Draft is referenced by an assignment.',
      );
    }
    placements.removeWhere((_, p) => p.programmeVersionId == programmeVersionId);
    programmeVersions.remove(programmeVersionId);
  }

  bool _publishedContentChanged(ProgrammeVersion before, ProgrammeVersion after) {
    return before.canonicalHash != after.canonicalHash ||
        before.versionNumber != after.versionNumber ||
        before.programmeId != after.programmeId;
  }
}
