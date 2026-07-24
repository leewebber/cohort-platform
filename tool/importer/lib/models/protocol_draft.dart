import 'package:founder_importer/models/protocol_step_draft.dart';
import 'package:founder_importer/models/session_block.dart';
import 'package:founder_importer/models/session_revision_vocabulary.dart';
import 'package:founder_importer/models/training_content_vocabulary.dart';

/// Editable in-memory representation of a protocol before save.
///
/// Maps to `performance_protocols` and a list of [ProtocolStepDraft] rows.
/// See `07 Documentation/34_Protocol_Builder.md`.
class ProtocolDraft {
  const ProtocolDraft({
    required this.protocolId,
    required this.name,
    required this.steps,
    this.blocks = const [],
    this.published = false,
    this.contentKind = TrainingContentKind.cohortProtocol,
    this.authoringScope = TrainingAuthoringScope.cohortGlobal,
    this.endorsementStatus = TrainingEndorsementStatus.cohortEndorsed,
    this.ownerId,
    this.organisationId,
    this.programmeVersionId,
    this.sourceContentId,
    this.sourceContentKind,
    this.sourceVersionId,
    this.sessionLineageId,
    this.revisionNumber = 1,
    this.lifecycleStatus = SessionRevisionLifecycleStatus.draft,
    this.publishedAt,
    this.archivedAt,
    this.primaryCapability,
    this.secondaryCapability,
    this.sessionType,
    this.sessionFormat,
    this.durationMin,
    this.durationCategory,
    this.physiologicalDemand,
    this.recoveryCost,
    this.technicalComplexity,
    this.environment,
    this.requiredEquipment,
    this.optionalEquipment,
    this.suitableFor,
    this.adaptability,
    this.runningRequired,
    this.runningReplaceable,
    this.hotelFriendly,
    this.indoorFriendly,
    this.noiseFriendly,
    this.coachingNotes,
    this.purpose,
  });

  final String protocolId;
  final String name;
  final List<ProtocolStepDraft> steps;
  /// Modular Session blocks (M6). Authoring source of truth when non-empty.
  final List<SessionBlock> blocks;
  final bool published;

  final TrainingContentKind contentKind;
  final TrainingAuthoringScope authoringScope;
  final TrainingEndorsementStatus endorsementStatus;
  final String? ownerId;
  final String? organisationId;
  final String? programmeVersionId;
  final String? sourceContentId;
  final TrainingContentKind? sourceContentKind;
  final String? sourceVersionId;
  final String? sessionLineageId;
  final int revisionNumber;
  final SessionRevisionLifecycleStatus lifecycleStatus;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  final String? primaryCapability;
  final String? secondaryCapability;
  final String? sessionType;
  final String? sessionFormat;
  final int? durationMin;
  final String? durationCategory;
  final String? physiologicalDemand;
  final String? recoveryCost;
  final String? technicalComplexity;
  final String? environment;
  final String? requiredEquipment;
  final String? optionalEquipment;
  final String? suitableFor;
  final int? adaptability;
  final bool? runningRequired;
  final bool? runningReplaceable;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final bool? noiseFriendly;
  final String? coachingNotes;
  final String? purpose;

  bool get isRevisionEditable =>
      lifecycleStatus == SessionRevisionLifecycleStatus.draft;

  bool get isRevisionPublished =>
      lifecycleStatus == SessionRevisionLifecycleStatus.published;

  ProtocolDraft copyWith({
    String? protocolId,
    String? name,
    List<ProtocolStepDraft>? steps,
    List<SessionBlock>? blocks,
    bool? published,
    TrainingContentKind? contentKind,
    TrainingAuthoringScope? authoringScope,
    TrainingEndorsementStatus? endorsementStatus,
    String? ownerId,
    String? organisationId,
    String? programmeVersionId,
    String? sourceContentId,
    TrainingContentKind? sourceContentKind,
    String? sourceVersionId,
    String? sessionLineageId,
    int? revisionNumber,
    SessionRevisionLifecycleStatus? lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
    bool clearPublishedAt = false,
    bool clearArchivedAt = false,
    String? primaryCapability,
    String? secondaryCapability,
    String? sessionType,
    String? sessionFormat,
    int? durationMin,
    String? durationCategory,
    String? physiologicalDemand,
    String? recoveryCost,
    String? technicalComplexity,
    String? environment,
    String? requiredEquipment,
    String? optionalEquipment,
    String? suitableFor,
    int? adaptability,
    bool? runningRequired,
    bool? runningReplaceable,
    bool? hotelFriendly,
    bool? indoorFriendly,
    bool? noiseFriendly,
    String? coachingNotes,
    String? purpose,
  }) {
    return ProtocolDraft(
      protocolId: protocolId ?? this.protocolId,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      blocks: blocks ?? this.blocks,
      published: published ?? this.published,
      contentKind: contentKind ?? this.contentKind,
      authoringScope: authoringScope ?? this.authoringScope,
      endorsementStatus: endorsementStatus ?? this.endorsementStatus,
      ownerId: ownerId ?? this.ownerId,
      organisationId: organisationId ?? this.organisationId,
      programmeVersionId: programmeVersionId ?? this.programmeVersionId,
      sourceContentId: sourceContentId ?? this.sourceContentId,
      sourceContentKind: sourceContentKind ?? this.sourceContentKind,
      sourceVersionId: sourceVersionId ?? this.sourceVersionId,
      sessionLineageId: sessionLineageId ?? this.sessionLineageId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      publishedAt:
          clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      primaryCapability: primaryCapability ?? this.primaryCapability,
      secondaryCapability: secondaryCapability ?? this.secondaryCapability,
      sessionType: sessionType ?? this.sessionType,
      sessionFormat: sessionFormat ?? this.sessionFormat,
      durationMin: durationMin ?? this.durationMin,
      durationCategory: durationCategory ?? this.durationCategory,
      physiologicalDemand: physiologicalDemand ?? this.physiologicalDemand,
      recoveryCost: recoveryCost ?? this.recoveryCost,
      technicalComplexity: technicalComplexity ?? this.technicalComplexity,
      environment: environment ?? this.environment,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      optionalEquipment: optionalEquipment ?? this.optionalEquipment,
      suitableFor: suitableFor ?? this.suitableFor,
      adaptability: adaptability ?? this.adaptability,
      runningRequired: runningRequired ?? this.runningRequired,
      runningReplaceable: runningReplaceable ?? this.runningReplaceable,
      hotelFriendly: hotelFriendly ?? this.hotelFriendly,
      indoorFriendly: indoorFriendly ?? this.indoorFriendly,
      noiseFriendly: noiseFriendly ?? this.noiseFriendly,
      coachingNotes: coachingNotes ?? this.coachingNotes,
      purpose: purpose ?? this.purpose,
    );
  }

  /// Maps coach-editable protocol fields to `performance_protocols` columns.
  Map<String, dynamic> toProtocolMap() {
    return {
      'protocol_id': protocolId,
      'name': name,
      'content_kind': contentKind.dbValue,
      'authoring_scope': authoringScope.dbValue,
      'endorsement_status': endorsementStatus.dbValue,
      'owner_id': _nullableString(ownerId),
      'organisation_id': _nullableString(organisationId),
      'programme_version_id': _nullableString(programmeVersionId),
      'source_content_id': _nullableString(sourceContentId),
      'source_content_kind': sourceContentKind?.dbValue,
      'source_version_id': _nullableString(sourceVersionId),
      'session_lineage_id': _nullableString(sessionLineageId),
      'revision_number': revisionNumber,
      'lifecycle_status': lifecycleStatus.dbValue,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
      'primary_capability': _nullableString(primaryCapability),
      'secondary_capability': _nullableString(secondaryCapability),
      'session_type': _nullableString(sessionType),
      'duration_min': durationMin,
      'duration_category': _nullableString(durationCategory),
      'physiological_demand': _nullableString(physiologicalDemand),
      'recovery_cost': _nullableString(recoveryCost),
      'technical_complexity': _nullableString(technicalComplexity),
      'environment': _nullableString(environment),
      'required_equipment': _nullableString(requiredEquipment),
      'optional_equipment': _nullableString(optionalEquipment),
      'suitable_for': _nullableString(suitableFor),
      'adaptability': adaptability,
      'running_required': runningRequired,
      'running_replaceable': runningReplaceable,
      'hotel_friendly': hotelFriendly,
      'indoor_friendly': indoorFriendly,
      'noise_friendly': noiseFriendly,
      'coaching_notes': _nullableString(coachingNotes),
      'purpose': _nullableString(purpose),
    };
  }

  /// Parses training content metadata from a `performance_protocols` row.
  static ProtocolDraft applyTrainingContentMetadata({
    required ProtocolDraft draft,
    required Map<String, dynamic> row,
  }) {
    return draft.copyWith(
      contentKind: TrainingContentKindDb.fromDb(row['content_kind']?.toString()),
      authoringScope:
          TrainingAuthoringScopeDb.fromDb(row['authoring_scope']?.toString()),
      endorsementStatus: TrainingEndorsementStatusDb.fromDb(
        row['endorsement_status']?.toString(),
      ),
      ownerId: row['owner_id']?.toString(),
      organisationId: row['organisation_id']?.toString(),
      programmeVersionId: row['programme_version_id']?.toString(),
      sourceContentId: row['source_content_id']?.toString(),
      sourceContentKind: _parseSourceContentKind(row['source_content_kind']),
      sourceVersionId: row['source_version_id']?.toString(),
      sessionLineageId: row['session_lineage_id']?.toString(),
      revisionNumber: row['revision_number'] is int
          ? row['revision_number'] as int
          : int.tryParse(row['revision_number']?.toString() ?? '') ?? 1,
      lifecycleStatus: row['lifecycle_status'] != null
          ? SessionRevisionLifecycleStatusDb.fromDb(
              row['lifecycle_status']?.toString(),
            )
          : SessionRevisionLifecycleStatusDb.fromPublishedBoolean(
              row['published'] == true,
            ),
      publishedAt: _parseDateTime(row['published_at']),
      archivedAt: _parseDateTime(row['archived_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static TrainingContentKind? _parseSourceContentKind(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;

    return TrainingContentKindDb.fromDb(normalized);
  }

  static String? _nullableString(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
