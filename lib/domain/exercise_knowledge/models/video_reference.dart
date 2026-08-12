import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'knowledge_content_common.dart';
import 'knowledge_reference.dart';

/// Provider-neutral key. Provider support is a later application concern.
class VideoProviderKey {
  VideoProviderKey._(this.value);

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9_.-]{1,63}$');

  final String value;

  factory VideoProviderKey.parse(String raw) {
    final value = raw.trim().toLowerCase();
    if (!_pattern.hasMatch(value)) {
      throw FormatException('Malformed video provider key: $value');
    }
    return VideoProviderKey._(value);
  }

  @override
  bool operator ==(Object other) =>
      other is VideoProviderKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum VideoAvailabilityState { available, unavailable, removed }

extension VideoAvailabilityStateCodec on VideoAvailabilityState {
  String get wireValue => name;

  static VideoAvailabilityState? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in VideoAvailabilityState.values) {
      if (value.name == normalized) return value;
    }
    return null;
  }
}

enum AccessibilityAvailabilityState { available, unavailable, notProvided }

extension AccessibilityAvailabilityStateCodec
    on AccessibilityAvailabilityState {
  String get wireValue => switch (this) {
    AccessibilityAvailabilityState.available => 'available',
    AccessibilityAvailabilityState.unavailable => 'unavailable',
    AccessibilityAvailabilityState.notProvided => 'not_provided',
  };

  static AccessibilityAvailabilityState? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in AccessibilityAvailabilityState.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}

/// Governed metadata for a movement demonstration video.
///
/// Contains no uploaded media, provider SDK, playback, network, or hosting logic.
class VideoReference implements ExerciseKnowledgeContentRecord {
  const VideoReference({
    required this.id,
    required this.exerciseId,
    required this.version,
    required this.lifecycleStatus,
    required this.authorId,
    required this.purpose,
    required this.language,
    required this.availability,
    required this.captionsState,
    required this.transcriptState,
    required this.audioDescriptionState,
    required this.provenance,
    required this.authoredAt,
    this.reviewerId,
    this.providerKey,
    this.providerAssetId,
    this.canonicalUri,
    this.thumbnailReferenceId,
    this.durationSeconds,
    this.lastVerifiedAt,
    this.transcriptReferenceId,
    this.rightsBasis,
    this.ownerOrLicensor,
    this.attributionRequirements,
    this.reviewOrExpiryDate,
    this.reviewedAt,
    this.publishedAt,
    this.replacementId,
  });

  @override
  final KnowledgeReferenceId id;
  @override
  final ExerciseId exerciseId;
  @override
  final String version;
  @override
  final ExerciseLifecycleStatus lifecycleStatus;
  @override
  final KnowledgeActorId authorId;
  @override
  final KnowledgeActorId? reviewerId;
  final String purpose;
  final VideoProviderKey? providerKey;
  final String? providerAssetId;
  final String? canonicalUri;
  final KnowledgeReferenceId? thumbnailReferenceId;
  final String language;
  final int? durationSeconds;
  final VideoAvailabilityState availability;
  final DateTime? lastVerifiedAt;
  final AccessibilityAvailabilityState captionsState;
  final AccessibilityAvailabilityState transcriptState;
  final KnowledgeReferenceId? transcriptReferenceId;
  final AccessibilityAvailabilityState audioDescriptionState;
  @override
  final KnowledgeProvenance provenance;
  final String? rightsBasis;
  final String? ownerOrLicensor;
  final String? attributionRequirements;
  final DateTime? reviewOrExpiryDate;
  @override
  final DateTime authoredAt;
  @override
  final DateTime? reviewedAt;
  @override
  final DateTime? publishedAt;
  @override
  final KnowledgeReferenceId? replacementId;

  @override
  ExerciseKnowledgeContentKind get contentKind =>
      ExerciseKnowledgeContentKind.videoReference;

  bool get isPlayable =>
      lifecycleStatus == ExerciseLifecycleStatus.published &&
      availability == VideoAvailabilityState.available &&
      canonicalUri != null;

  VideoReference publish({
    required KnowledgeActorId reviewerId,
    required DateTime publishedAt,
  }) => VideoReference(
    id: id,
    exerciseId: exerciseId,
    version: version,
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: authorId,
    reviewerId: reviewerId,
    purpose: purpose,
    providerKey: providerKey,
    providerAssetId: providerAssetId,
    canonicalUri: canonicalUri,
    thumbnailReferenceId: thumbnailReferenceId,
    language: language,
    durationSeconds: durationSeconds,
    availability: availability,
    lastVerifiedAt: lastVerifiedAt,
    captionsState: captionsState,
    transcriptState: transcriptState,
    transcriptReferenceId: transcriptReferenceId,
    audioDescriptionState: audioDescriptionState,
    provenance: provenance,
    rightsBasis: rightsBasis,
    ownerOrLicensor: ownerOrLicensor,
    attributionRequirements: attributionRequirements,
    reviewOrExpiryDate: reviewOrExpiryDate,
    authoredAt: authoredAt,
    reviewedAt: reviewedAt ?? publishedAt,
    publishedAt: this.publishedAt ?? publishedAt,
    replacementId: replacementId,
  );

  @override
  Map<String, Object?> toJson() => {
    ...KnowledgeContentCodec.commonJson(
      id: id,
      exerciseId: exerciseId,
      version: version,
      lifecycleStatus: lifecycleStatus,
      authorId: authorId,
      reviewerId: reviewerId,
      provenance: provenance,
      authoredAt: authoredAt,
      reviewedAt: reviewedAt,
      publishedAt: publishedAt,
      replacementId: replacementId,
    ),
    'purpose': purpose,
    if (providerKey != null) 'provider_key': providerKey!.value,
    if (providerAssetId != null) 'provider_asset_id': providerAssetId,
    if (canonicalUri != null) 'canonical_uri': canonicalUri,
    if (thumbnailReferenceId != null)
      'thumbnail_reference_id': thumbnailReferenceId!.value,
    'language': language,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    'availability': availability.wireValue,
    if (lastVerifiedAt != null)
      'last_verified_at': lastVerifiedAt!.toUtc().toIso8601String(),
    'captions_state': captionsState.wireValue,
    'transcript_state': transcriptState.wireValue,
    if (transcriptReferenceId != null)
      'transcript_reference_id': transcriptReferenceId!.value,
    'audio_description_state': audioDescriptionState.wireValue,
    if (rightsBasis != null) 'rights_basis': rightsBasis,
    if (ownerOrLicensor != null) 'owner_or_licensor': ownerOrLicensor,
    if (attributionRequirements != null)
      'attribution_requirements': attributionRequirements,
    if (reviewOrExpiryDate != null)
      'review_or_expiry_date': reviewOrExpiryDate!.toUtc().toIso8601String(),
  };

  factory VideoReference.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, _keys, 'video_reference');
    KnowledgeContentCodec.requireSchemaVersion(json, 'video_reference');
    final provider = json['provider_key']?.toString();
    final availability = VideoAvailabilityStateCodec.tryParse(
      json['availability']?.toString(),
    );
    final captions = AccessibilityAvailabilityStateCodec.tryParse(
      json['captions_state']?.toString(),
    );
    final transcript = AccessibilityAvailabilityStateCodec.tryParse(
      json['transcript_state']?.toString(),
    );
    final audioDescription = AccessibilityAvailabilityStateCodec.tryParse(
      json['audio_description_state']?.toString(),
    );
    if (availability == null ||
        captions == null ||
        transcript == null ||
        audioDescription == null) {
      throw const FormatException(
        'Video availability and accessibility states must be explicit.',
      );
    }
    return VideoReference(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      exerciseId: ExerciseId.parse(json['exercise_id']?.toString() ?? ''),
      version: json['version']?.toString() ?? '',
      lifecycleStatus: KnowledgeContentCodec.lifecycle(
        json['lifecycle_status'],
        'video_reference.lifecycle_status',
      ),
      authorId: KnowledgeContentCodec.actor(
        json['author'],
        'video_reference.author',
      ),
      reviewerId: KnowledgeContentCodec.optionalActor(
        json['reviewer'],
        'video_reference.reviewer',
      ),
      purpose: json['purpose']?.toString() ?? '',
      providerKey: provider == null ? null : VideoProviderKey.parse(provider),
      providerAssetId: json['provider_asset_id']?.toString(),
      canonicalUri: json['canonical_uri']?.toString(),
      thumbnailReferenceId: json['thumbnail_reference_id'] == null
          ? null
          : KnowledgeReferenceId.parse(
              json['thumbnail_reference_id'].toString(),
            ),
      language: json['language']?.toString() ?? '',
      durationSeconds: _int(json['duration_seconds']),
      availability: availability,
      lastVerifiedAt: KnowledgeContentCodec.optionalDate(
        json['last_verified_at'],
        'video_reference.last_verified_at',
      ),
      captionsState: captions,
      transcriptState: transcript,
      transcriptReferenceId: json['transcript_reference_id'] == null
          ? null
          : KnowledgeReferenceId.parse(
              json['transcript_reference_id'].toString(),
            ),
      audioDescriptionState: audioDescription,
      provenance: KnowledgeContentCodec.provenance(
        json['provenance'],
        'video_reference.provenance',
      ),
      rightsBasis: json['rights_basis']?.toString(),
      ownerOrLicensor: json['owner_or_licensor']?.toString(),
      attributionRequirements: json['attribution_requirements']?.toString(),
      reviewOrExpiryDate: KnowledgeContentCodec.optionalDate(
        json['review_or_expiry_date'],
        'video_reference.review_or_expiry_date',
      ),
      authoredAt: KnowledgeContentCodec.requireDate(
        json['authored_at'],
        'video_reference.authored_at',
      ),
      reviewedAt: KnowledgeContentCodec.optionalDate(
        json['reviewed_at'],
        'video_reference.reviewed_at',
      ),
      publishedAt: KnowledgeContentCodec.optionalDate(
        json['published_at'],
        'video_reference.published_at',
      ),
      replacementId: json['replacement_id'] == null
          ? null
          : KnowledgeReferenceId.parse(json['replacement_id'].toString()),
    );
  }

  static const _keys = {
    'schema_version',
    'id',
    'exercise_id',
    'version',
    'lifecycle_status',
    'author',
    'reviewer',
    'purpose',
    'provider_key',
    'provider_asset_id',
    'canonical_uri',
    'thumbnail_reference_id',
    'language',
    'duration_seconds',
    'availability',
    'last_verified_at',
    'captions_state',
    'transcript_state',
    'transcript_reference_id',
    'audio_description_state',
    'provenance',
    'rights_basis',
    'owner_or_licensor',
    'attribution_requirements',
    'review_or_expiry_date',
    'authored_at',
    'reviewed_at',
    'published_at',
    'replacement_id',
  };
}

int? _int(Object? raw) {
  if (raw == null) return null;
  final parsed = raw is int ? raw : int.tryParse(raw.toString());
  if (parsed == null) {
    throw const FormatException('duration_seconds must be an integer.');
  }
  return parsed;
}
