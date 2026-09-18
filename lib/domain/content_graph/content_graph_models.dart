import 'content_graph_vocabulary.dart';

class ContentGraphException implements Exception {
  const ContentGraphException(this.code, this.message);

  final ContentGraphFailureCode code;
  final String message;

  @override
  String toString() => 'ContentGraphException($code): $message';
}

class ContentPublisher {
  const ContentPublisher({
    required this.id,
    required this.displayName,
    required this.namespace,
    required this.firstParty,
  });

  final String id;
  final String displayName;
  final String namespace;
  final bool firstParty;
}

class ContentExercise {
  const ContentExercise({
    required this.id,
    required this.displayName,
    this.aliases = const [],
    this.unresolvedLegacy = false,
  });

  /// Canonical `EX-*` identity.
  final String id;
  final String displayName;
  final List<String> aliases;
  final bool unresolvedLegacy;
}

class SessionTemplate {
  const SessionTemplate({
    required this.id,
    required this.displayName,
    required this.ownerId,
  });

  final String id;
  final String displayName;
  final String ownerId;
}

class SessionTemplateVersion {
  const SessionTemplateVersion({
    required this.id,
    required this.templateId,
    required this.revisionNumber,
    required this.lifecycle,
    required this.ownerId,
    this.sourceHash,
    this.label,
  });

  /// Immutable revision identity. Maps to production `protocol_id`.
  final String id;
  final String templateId;
  final int revisionNumber;
  final ContentLifecycle lifecycle;
  final String ownerId;
  final String? sourceHash;
  final String? label;

  SessionTemplateVersion copyWith({
    ContentLifecycle? lifecycle,
    String? sourceHash,
  }) {
    return SessionTemplateVersion(
      id: id,
      templateId: templateId,
      revisionNumber: revisionNumber,
      lifecycle: lifecycle ?? this.lifecycle,
      ownerId: ownerId,
      sourceHash: sourceHash ?? this.sourceHash,
      label: label,
    );
  }
}

class AuthoredBlock {
  const AuthoredBlock({
    required this.id,
    required this.sessionTemplateVersionId,
    required this.position,
    required this.title,
    required this.exerciseIds,
    this.prescriptionByExercise = const {},
  });

  final String id;
  final String sessionTemplateVersionId;
  final int position;
  final String title;
  final List<String> exerciseIds;
  final Map<String, String> prescriptionByExercise;

  AuthoredBlock copyWith({
    List<String>? exerciseIds,
    Map<String, String>? prescriptionByExercise,
    String? title,
  }) {
    return AuthoredBlock(
      id: id,
      sessionTemplateVersionId: sessionTemplateVersionId,
      position: position,
      title: title ?? this.title,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      prescriptionByExercise:
          prescriptionByExercise ?? this.prescriptionByExercise,
    );
  }
}

class ProgrammeIdentity {
  const ProgrammeIdentity({
    required this.id,
    required this.code,
    required this.displayName,
    required this.ownerId,
  });

  final String id;
  final String code;
  final String displayName;
  final String ownerId;
}

class ProgrammeVersion {
  const ProgrammeVersion({
    required this.id,
    required this.programmeId,
    required this.versionNumber,
    required this.lifecycle,
    required this.ownerId,
    this.label,
    this.supersedesVersionId,
    this.canonicalHash,
    this.compilerFormatVersion = 1,
    this.catalogueDefault = false,
    this.changeSummary,
    this.sourcePackageRef,
  });

  final String id;
  final String programmeId;
  final int versionNumber;
  final ContentLifecycle lifecycle;
  final String ownerId;
  final String? label;
  final String? supersedesVersionId;
  final String? canonicalHash;
  final int compilerFormatVersion;
  final bool catalogueDefault;
  final String? changeSummary;
  final String? sourcePackageRef;

  ProgrammeVersion copyWith({
    ContentLifecycle? lifecycle,
    String? canonicalHash,
    bool? catalogueDefault,
    String? changeSummary,
    String? supersedesVersionId,
  }) {
    return ProgrammeVersion(
      id: id,
      programmeId: programmeId,
      versionNumber: versionNumber,
      lifecycle: lifecycle ?? this.lifecycle,
      ownerId: ownerId,
      label: label,
      supersedesVersionId: supersedesVersionId ?? this.supersedesVersionId,
      canonicalHash: canonicalHash ?? this.canonicalHash,
      compilerFormatVersion: compilerFormatVersion,
      catalogueDefault: catalogueDefault ?? this.catalogueDefault,
      changeSummary: changeSummary ?? this.changeSummary,
      sourcePackageRef: sourcePackageRef,
    );
  }
}

class ProgrammePlacement {
  const ProgrammePlacement({
    required this.id,
    required this.programmeVersionId,
    required this.sessionTemplateVersionId,
    required this.weekNumber,
    required this.dayKey,
    required this.slotOrder,
    this.titleOverride,
    this.progressionParameters = const {},
    this.adaptationPermission = 'default',
    this.optional = false,
  });

  final String id;
  final String programmeVersionId;
  final String sessionTemplateVersionId;
  final int weekNumber;
  final String dayKey;
  final int slotOrder;
  final String? titleOverride;
  final Map<String, String> progressionParameters;
  final String adaptationPermission;
  final bool optional;

  ProgrammePlacement copyWith({
    String? sessionTemplateVersionId,
    int? weekNumber,
    String? dayKey,
    int? slotOrder,
    Map<String, String>? progressionParameters,
    String? adaptationPermission,
    String? titleOverride,
  }) {
    return ProgrammePlacement(
      id: id,
      programmeVersionId: programmeVersionId,
      sessionTemplateVersionId:
          sessionTemplateVersionId ?? this.sessionTemplateVersionId,
      weekNumber: weekNumber ?? this.weekNumber,
      dayKey: dayKey ?? this.dayKey,
      slotOrder: slotOrder ?? this.slotOrder,
      titleOverride: titleOverride ?? this.titleOverride,
      progressionParameters:
          progressionParameters ?? this.progressionParameters,
      adaptationPermission: adaptationPermission ?? this.adaptationPermission,
      optional: optional,
    );
  }
}

class PinnedAssignment {
  const PinnedAssignment({
    required this.id,
    required this.athleteId,
    required this.programmeVersionId,
    required this.active,
  });

  final String id;
  final String athleteId;
  final String programmeVersionId;
  final bool active;
}

class DerivedOccurrence {
  const DerivedOccurrence({
    required this.id,
    required this.assignmentId,
    required this.placementId,
    required this.programmeVersionId,
  });

  final String id;
  final String assignmentId;
  final String placementId;
  final String programmeVersionId;
}

class ContentActor {
  const ContentActor({
    required this.publisherId,
    required this.role,
  });

  final String publisherId;
  final ContentAuthRole role;
}

class UsedByHit {
  const UsedByHit({
    required this.nodeId,
    required this.nodeType,
    required this.scope,
    required this.direct,
    this.label,
  });

  final String nodeId;
  final ContentNodeType nodeType;
  final ContentUsageScope scope;
  final bool direct;
  final String? label;
}

class UsedByProjection {
  const UsedByProjection({
    required this.subjectId,
    required this.subjectType,
    required this.hits,
    required this.activeAssignmentCount,
  });

  final String subjectId;
  final ContentNodeType subjectType;
  final List<UsedByHit> hits;
  final int activeAssignmentCount;
}

class ContentDiffEntry {
  const ContentDiffEntry({
    required this.path,
    required this.classification,
    required this.summary,
  });

  final String path;
  final ContentDiffClass classification;
  final String summary;
}

class ContentVersionDiff {
  const ContentVersionDiff({
    required this.fromVersionId,
    required this.toVersionId,
    required this.entries,
  });

  final String fromVersionId;
  final String toVersionId;
  final List<ContentDiffEntry> entries;

  bool get hasBreaking =>
      entries.any((e) => e.classification == ContentDiffClass.breakingExecution);
  bool get hasMaterial =>
      entries.any((e) => e.classification == ContentDiffClass.materialTraining);
}
