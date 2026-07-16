import 'programme_publish_readiness.dart';
import 'programme_template_draft.dart';
import 'programme_validation_result.dart';
import 'programme_version_draft_metadata.dart';

/// Root authoring document for Programme Builder.
///
/// Client dirty/save metadata is separate from persisted programme rows.
/// See `44_Programme_Builder.md`.
class ProgrammeBuilderDocument {
  const ProgrammeBuilderDocument({
    required this.metadata,
    required this.template,
    this.isDirty = false,
    this.hasUnsavedChanges = false,
    this.lastSavedAt,
    this.saveGeneration = 0,
    this.lastValidation,
    this.publishReadiness,
  });

  final ProgrammeVersionDraftMetadata metadata;
  final ProgrammeTemplateDraft template;
  final bool isDirty;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedAt;
  final int saveGeneration;
  final ProgrammeValidationResult? lastValidation;
  final ProgrammePublishReadiness? publishReadiness;

  bool get isPersisted => metadata.isPersisted;

  bool get isEditable => metadata.isEditable;

  /// Marks the document as edited since last save/load.
  ProgrammeBuilderDocument markDirty() {
    return copyWith(isDirty: true, hasUnsavedChanges: true);
  }

  /// Clears dirty flags after a successful save.
  ProgrammeBuilderDocument markSaved({
    required DateTime savedAt,
    int? saveGeneration,
  }) {
    return copyWith(
      isDirty: false,
      hasUnsavedChanges: false,
      lastSavedAt: savedAt,
      saveGeneration: saveGeneration ?? this.saveGeneration + 1,
      clearLastValidation: true,
      clearPublishReadiness: true,
    );
  }

  /// Clean document as loaded from persistence.
  factory ProgrammeBuilderDocument.clean({
    required ProgrammeVersionDraftMetadata metadata,
    required ProgrammeTemplateDraft template,
    DateTime? lastSavedAt,
    int saveGeneration = 0,
  }) {
    return ProgrammeBuilderDocument(
      metadata: metadata,
      template: template,
      isDirty: false,
      hasUnsavedChanges: false,
      lastSavedAt: lastSavedAt,
      saveGeneration: saveGeneration,
    );
  }

  ProgrammeBuilderDocument copyWith({
    ProgrammeVersionDraftMetadata? metadata,
    ProgrammeTemplateDraft? template,
    bool? isDirty,
    bool? hasUnsavedChanges,
    DateTime? lastSavedAt,
    int? saveGeneration,
    ProgrammeValidationResult? lastValidation,
    ProgrammePublishReadiness? publishReadiness,
    bool clearLastValidation = false,
    bool clearPublishReadiness = false,
    bool clearLastSavedAt = false,
  }) {
    return ProgrammeBuilderDocument(
      metadata: metadata ?? this.metadata,
      template: template ?? this.template,
      isDirty: isDirty ?? this.isDirty,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedAt:
          clearLastSavedAt ? null : (lastSavedAt ?? this.lastSavedAt),
      saveGeneration: saveGeneration ?? this.saveGeneration,
      lastValidation: clearLastValidation
          ? null
          : (lastValidation ?? this.lastValidation),
      publishReadiness: clearPublishReadiness
          ? null
          : (publishReadiness ?? this.publishReadiness),
    );
  }
}
