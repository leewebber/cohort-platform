import 'content_graph_models.dart';

abstract class ContentGraphStore {
  ContentPublisher? publisher(String id);
  ProgrammeIdentity? programme(String id);
  ProgrammeVersion? programmeVersion(String id);
  SessionTemplate? sessionTemplate(String id);
  SessionTemplateVersion? sessionTemplateVersion(String id);
  ContentExercise? exercise(String id);
  AuthoredBlock? block(String id);
  PinnedAssignment? assignment(String id);

  Iterable<ProgrammeVersion> versionsForProgramme(String programmeId);
  Iterable<ProgrammePlacement> placementsForVersion(String programmeVersionId);
  Iterable<AuthoredBlock> blocksForSessionVersion(String sessionTemplateVersionId);
  Iterable<PinnedAssignment> assignmentsForVersion(String programmeVersionId);
  Iterable<DerivedOccurrence> occurrencesForAssignment(String assignmentId);
  Iterable<ProgrammePlacement> placementsUsingSession(String sessionTemplateVersionId);
  Iterable<AuthoredBlock> blocksUsingExercise(String exerciseId);

  void putPublisher(ContentPublisher publisher);
  void putExercise(ContentExercise exercise);
  void putSessionTemplate(SessionTemplate template);
  void putSessionTemplateVersion(SessionTemplateVersion version);
  void putBlock(AuthoredBlock block);
  void putProgramme(ProgrammeIdentity programme);
  void putProgrammeVersion(ProgrammeVersion version);
  void putPlacement(ProgrammePlacement placement);
  void putAssignment(PinnedAssignment assignment);
  void putOccurrence(DerivedOccurrence occurrence);
  void removeDraftVersion(String programmeVersionId);
}
