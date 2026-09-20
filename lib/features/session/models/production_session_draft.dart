/// Versioned production workout draft identity. Actuals live in the performance draft.
class ProductionSessionDraft {
  const ProductionSessionDraft({
    required this.schemaVersion,
    required this.athleteId,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.programmedSessionKey,
    required this.packageContentHash,
    required this.trainingSessionId,
    required this.entryMode,
    this.occurrenceId,
    this.scheduledDate,
    this.startedAt,
    this.lastDurableSaveAt,
    this.finalisationKey,
    this.acceptedAdaptationId,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String athleteId;
  final String assignmentId;
  final String programmeVersionId;
  final String programmedSessionKey;
  final String packageContentHash;
  final int trainingSessionId;
  final String entryMode;
  final String? occurrenceId;
  final String? scheduledDate;
  final DateTime? startedAt;
  final DateTime? lastDurableSaveAt;
  final String? finalisationKey;
  final String? acceptedAdaptationId;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'athlete_id': athleteId,
      'assignment_id': assignmentId,
      'programme_version_id': programmeVersionId,
      'programmed_session_key': programmedSessionKey,
      'package_content_hash': packageContentHash,
      'training_session_id': trainingSessionId,
      'entry_mode': entryMode,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (startedAt != null) 'started_at': startedAt!.toUtc().toIso8601String(),
      if (lastDurableSaveAt != null)
        'last_durable_save_at': lastDurableSaveAt!.toUtc().toIso8601String(),
      if (finalisationKey != null) 'finalisation_key': finalisationKey,
      if (acceptedAdaptationId != null)
        'accepted_adaptation_id': acceptedAdaptationId,
    };
  }

  factory ProductionSessionDraft.fromJson(Map<String, dynamic> json) {
    return ProductionSessionDraft(
      schemaVersion: json['schema_version'] as int? ?? 0,
      athleteId: json['athlete_id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      programmeVersionId: json['programme_version_id'] as String? ?? '',
      programmedSessionKey: json['programmed_session_key'] as String? ?? '',
      packageContentHash: json['package_content_hash'] as String? ?? '',
      trainingSessionId: json['training_session_id'] as int? ?? 0,
      entryMode: json['entry_mode'] as String? ?? 'live',
      occurrenceId: json['occurrence_id'] as String?,
      scheduledDate: json['scheduled_date'] as String?,
      startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
      lastDurableSaveAt: DateTime.tryParse(
        json['last_durable_save_at'] as String? ?? '',
      ),
      finalisationKey: json['finalisation_key'] as String?,
      acceptedAdaptationId: json['accepted_adaptation_id'] as String?,
    );
  }
}

enum ProductionDraftRestoreClass {
  compatible,
  legacyPartial,
  staleOccurrence,
  staleProgrammeVersion,
  completedHosted,
  foreignAthlete,
  corrupt,
  unsupportedFutureVersion,
}
