import '../../core/services/supabase_service.dart';
import '../../features/exercise_relationship/models/exercise_usage_models.dart';
import '../../features/performance/models/training_session_record_status.dart';
import '../../models/exercise.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_vocabulary.dart';
import '../../models/session_revision_vocabulary.dart';
import 'exercise_relationship_store.dart';

class ExerciseRelationshipSupabaseStore extends ExerciseRelationshipStore {
  const ExerciseRelationshipSupabaseStore();

  static const _exercisesTable = 'exercises_v2';
  static const _blockExercisesTable = 'session_block_exercises';
  static const _blocksTable = 'session_blocks';
  static const _protocolsTable = 'performance_protocols';
  static const _stepsTable = 'protocol_steps';
  static const _slotsTable = 'programme_version_session_slots';
  static const _daysTable = 'programme_version_days';
  static const _weeksTable = 'programme_version_weeks';
  static const _versionsTable = 'programme_versions';
  static const _lineagesTable = 'programme_lineages';
  static const _assignmentsTable = 'programme_assignments';
  static const _exerciseResultsTable = 'training_exercise_results';
  static const _blockResultsTable = 'training_block_results';
  static const _recordsTable = 'training_session_records';

  @override
  Future<Exercise?> getExerciseById(String exerciseId) async {
    final response = await SupabaseService.client
        .from(_exercisesTable)
        .select()
        .eq('exercise_id', exerciseId.trim())
        .maybeSingle();

    if (response == null) return null;
    return Exercise.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<ExerciseRevisionReference>> listSessionRevisionReferences(
    String exerciseId,
  ) async {
    final normalizedExerciseId = exerciseId.trim();
    if (normalizedExerciseId.isEmpty) return const [];

    final blockLinkReferences =
        await _listBlockLinkSessionReferences(normalizedExerciseId);
    final protocolsWithBlockLinks = blockLinkReferences
        .map((reference) => reference.protocolId)
        .toSet();
    final legacyReferences = await _listLegacyStepSessionReferences(
      normalizedExerciseId,
      excludeProtocolIds: protocolsWithBlockLinks,
    );

    final references = [...blockLinkReferences, ...legacyReferences]
      ..sort(compareExerciseRevisionReferences);
    return references;
  }

  Future<List<ExerciseRevisionReference>> _listBlockLinkSessionReferences(
    String exerciseId,
  ) async {
    final linkRows = await SupabaseService.client
        .from(_blockExercisesTable)
        .select('id, block_id, position, display_label_override, exercise_id')
        .eq('exercise_id', exerciseId);

    if (linkRows.isEmpty) return const [];

    final links = List<Map<String, dynamic>>.from(linkRows as List);
    final blockIds = links
        .map((row) => row['block_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (blockIds.isEmpty) return const [];

    final blockRows = await SupabaseService.client
        .from(_blocksTable)
        .select('block_id, session_id, title, position')
        .inFilter('block_id', blockIds);

    final blocks = {
      for (final row in List<Map<String, dynamic>>.from(blockRows as List))
        row['block_id']?.toString(): row,
    };

    final protocolIds = blocks.values
        .map((row) => row['session_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (protocolIds.isEmpty) return const [];

    final protocolRows = await SupabaseService.client
        .from(_protocolsTable)
        .select(
          'protocol_id, name, session_lineage_id, revision_number, lifecycle_status',
        )
        .inFilter('protocol_id', protocolIds);

    final protocols = {
      for (final row in List<Map<String, dynamic>>.from(protocolRows as List))
        row['protocol_id']?.toString(): row,
    };

    final references = <ExerciseRevisionReference>[];
    for (final link in links) {
      final block = blocks[link['block_id']?.toString()];
      if (block == null) continue;

      final protocol = protocols[block['session_id']?.toString()];
      if (protocol == null) continue;

      final lineageId = protocol['session_lineage_id']?.toString();
      if (lineageId == null || lineageId.isEmpty) continue;

      references.add(
        ExerciseRevisionReference(
          protocolId: protocol['protocol_id']?.toString() ?? '',
          sessionLineageId: lineageId,
          sessionRevisionNumber: protocol['revision_number'] is int
              ? protocol['revision_number'] as int
              : int.tryParse(protocol['revision_number']?.toString() ?? '') ??
                  1,
          sessionName: protocol['name']?.toString() ?? '',
          sessionLifecycleStatus: SessionRevisionLifecycleStatusDb.fromDb(
            protocol['lifecycle_status']?.toString(),
          ),
          blockId: block['block_id']?.toString() ?? '',
          blockTitle: block['title']?.toString() ?? '',
          blockOrder: block['position'] is int
              ? block['position'] as int
              : int.tryParse(block['position']?.toString() ?? '') ?? 1,
          relationshipSource: ExerciseRelationshipSource.sessionBlockLink,
          exerciseLinkId: link['id']?.toString(),
          displayLabelOverride: _nullableTrimmedString(
            link['display_label_override'],
          ),
        ),
      );
    }

    return references;
  }

  Future<List<ExerciseRevisionReference>> _listLegacyStepSessionReferences(
    String exerciseId, {
    required Set<String> excludeProtocolIds,
  }) async {
    final stepRows = await SupabaseService.client
        .from(_stepsTable)
        .select('id, protocol_id, title, step_order, exercise_id')
        .eq('exercise_id', exerciseId);

    if (stepRows.isEmpty) return const [];

    final steps = List<Map<String, dynamic>>.from(stepRows as List)
        .where(
          (row) =>
              !excludeProtocolIds.contains(row['protocol_id']?.toString()),
        )
        .toList();

    if (steps.isEmpty) return const [];

    final protocolIds = steps
        .map((row) => row['protocol_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final protocolRows = await SupabaseService.client
        .from(_protocolsTable)
        .select(
          'protocol_id, name, session_lineage_id, revision_number, lifecycle_status',
        )
        .inFilter('protocol_id', protocolIds);

    final protocols = {
      for (final row in List<Map<String, dynamic>>.from(protocolRows as List))
        row['protocol_id']?.toString(): row,
    };

    final references = <ExerciseRevisionReference>[];
    for (final step in steps) {
      final protocol = protocols[step['protocol_id']?.toString()];
      if (protocol == null) continue;

      final lineageId = protocol['session_lineage_id']?.toString();
      if (lineageId == null || lineageId.isEmpty) continue;

      references.add(
        ExerciseRevisionReference(
          protocolId: protocol['protocol_id']?.toString() ?? '',
          sessionLineageId: lineageId,
          sessionRevisionNumber: protocol['revision_number'] is int
              ? protocol['revision_number'] as int
              : int.tryParse(protocol['revision_number']?.toString() ?? '') ??
                  1,
          sessionName: protocol['name']?.toString() ?? '',
          sessionLifecycleStatus: SessionRevisionLifecycleStatusDb.fromDb(
            protocol['lifecycle_status']?.toString(),
          ),
          blockId: 'legacy-step-${step['id']}',
          blockTitle: step['title']?.toString() ?? 'Legacy step',
          blockOrder: step['step_order'] is int
              ? step['step_order'] as int
              : int.tryParse(step['step_order']?.toString() ?? '') ?? 1,
          relationshipSource: ExerciseRelationshipSource.legacyProtocolStep,
          exerciseLinkId: step['id']?.toString(),
        ),
      );
    }

    return references;
  }

  @override
  Future<List<ExerciseProgrammeReference>> listProgrammeReferences(
    String exerciseId,
    Set<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) return const [];

    final slotRows = await SupabaseService.client
        .from(_slotsTable)
        .select('id, day_id, session_order, display_title, protocol_id')
        .inFilter('protocol_id', protocolIds.toList());

    if (slotRows.isEmpty) return const [];

    final slots = List<Map<String, dynamic>>.from(slotRows as List);
    final sessionReferences = await listSessionRevisionReferences(exerciseId);
    final revisionByProtocol = {
      for (final reference in sessionReferences)
        reference.protocolId: reference,
    };

    final dayIds = slots
        .map((row) => row['day_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final dayRows = await SupabaseService.client
        .from(_daysTable)
        .select('id, week_id, day_key, day_order')
        .inFilter('id', dayIds);

    final days = {
      for (final row in List<Map<String, dynamic>>.from(dayRows as List))
        row['id']?.toString(): row,
    };

    final weekIds = days.values
        .map((row) => row['week_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final weekRows = await SupabaseService.client
        .from(_weeksTable)
        .select('id, version_id, week_number')
        .inFilter('id', weekIds);

    final weeks = {
      for (final row in List<Map<String, dynamic>>.from(weekRows as List))
        row['id']?.toString(): row,
    };

    final versionIds = weeks.values
        .map((row) => row['version_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final versionRows = await SupabaseService.client
        .from(_versionsTable)
        .select('id, lineage_id, version_number, name, lifecycle_status')
        .inFilter('id', versionIds);

    final versions = {
      for (final row in List<Map<String, dynamic>>.from(versionRows as List))
        row['id']?.toString(): row,
    };

    final lineageIds = versions.values
        .map((row) => row['lineage_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final lineageRows = lineageIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from(_lineagesTable)
                .select('id, code')
                .inFilter('id', lineageIds) as List,
          );

    final lineages = {
      for (final row in lineageRows) row['id']?.toString(): row,
    };

    final references = <ExerciseProgrammeReference>[];
    for (final slot in slots) {
      final protocolId = slot['protocol_id']?.toString() ?? '';
      final sessionReference = revisionByProtocol[protocolId];
      if (sessionReference == null) continue;

      final day = days[slot['day_id']?.toString()];
      if (day == null) continue;

      final week = weeks[day['week_id']?.toString()];
      if (week == null) continue;

      final version = versions[week['version_id']?.toString()];
      if (version == null) continue;

      final lineage = lineages[version['lineage_id']?.toString()];
      if (lineage == null) continue;

      references.add(
        ExerciseProgrammeReference(
          programmeLineageId: lineage['id']?.toString() ?? '',
          programmeLineageCode: lineage['code']?.toString() ?? '',
          programmeVersionId: version['id']?.toString() ?? '',
          programmeVersionNumber: version['version_number'] is int
              ? version['version_number'] as int
              : int.tryParse(version['version_number']?.toString() ?? '') ?? 1,
          programmeName: version['name']?.toString() ?? '',
          programmeLifecycleStatus: ProgrammeLifecycleStatusDb.fromDb(
            version['lifecycle_status']?.toString(),
          ),
          protocolId: protocolId,
          sessionRevisionNumber: sessionReference.sessionRevisionNumber,
          slotId: slot['id']?.toString() ?? '',
          weekNumber: week['week_number'] is int
              ? week['week_number'] as int
              : int.tryParse(week['week_number']?.toString() ?? '') ?? 1,
          dayKey: day['day_key']?.toString() ?? '',
          dayOrder: day['day_order'] is int
              ? day['day_order'] as int
              : int.tryParse(day['day_order']?.toString() ?? '') ?? 1,
          slotOrder: slot['session_order'] is int
              ? slot['session_order'] as int
              : int.tryParse(slot['session_order']?.toString() ?? '') ?? 1,
          slotLabel: _nullableTrimmedString(slot['display_title']),
        ),
      );
    }

    references.sort(compareExerciseProgrammeReferences);
    return references;
  }

  @override
  Future<List<ExerciseAssignmentReference>> listActiveAssignmentReferences(
    String exerciseId,
    Set<String> programmeVersionIds,
  ) async {
    if (programmeVersionIds.isEmpty) return const [];

    final assignmentRows = await SupabaseService.client
        .from(_assignmentsTable)
        .select()
        .inFilter('programme_version_id', programmeVersionIds.toList())
        .eq('status', ProgrammeAssignmentStatus.active.dbValue);

    final assignments = List<Map<String, dynamic>>.from(
      assignmentRows as List,
    ).map(ProgrammeAssignment.fromMap);

    return buildExerciseActiveAssignmentReferences(
      assignments: assignments,
      referencingVersionIds: programmeVersionIds,
    );
  }

  @override
  Future<ExerciseHistoricalUsage> getHistoricalUsage(String exerciseId) async {
    final normalizedExerciseId = exerciseId.trim();
    if (normalizedExerciseId.isEmpty) {
      return const ExerciseHistoricalUsage(
        recordCount: 0,
        performanceOccurrenceCount: 0,
        isAuthoritative: true,
      );
    }

    final exerciseResultRows = await SupabaseService.client
        .from(_exerciseResultsTable)
        .select('exercise_result_id, source_exercise_id, block_result_id')
        .eq('source_exercise_id', normalizedExerciseId);

    final exerciseResults =
        List<Map<String, dynamic>>.from(exerciseResultRows as List);
    if (exerciseResults.isEmpty) {
      return const ExerciseHistoricalUsage(
        recordCount: 0,
        performanceOccurrenceCount: 0,
        isAuthoritative: true,
        limitationNote:
            'Counts terminal records with structured source_exercise_id only.',
      );
    }

    final blockResultIds = exerciseResults
        .map((row) => row['block_result_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final blockRows = await SupabaseService.client
        .from(_blockResultsTable)
        .select('block_result_id, session_record_id')
        .inFilter('block_result_id', blockResultIds);

    final blockToRecord = {
      for (final row in List<Map<String, dynamic>>.from(blockRows as List))
        row['block_result_id']?.toString(): row['session_record_id']?.toString(),
    };

    final recordIds = blockToRecord.values
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (recordIds.isEmpty) {
      return ExerciseHistoricalUsage(
        recordCount: 0,
        performanceOccurrenceCount: exerciseResults.length,
        isAuthoritative: true,
        limitationNote:
            'Counts terminal records with structured source_exercise_id only.',
      );
    }

    final recordRows = await SupabaseService.client
        .from(_recordsTable)
        .select(
          'record_id, source_protocol_id, started_at, completed_at, status',
        )
        .inFilter('record_id', recordIds)
        .neq('status', TrainingSessionRecordStatus.inProgress.dbValue);

    final terminalRecords = {
      for (final row in List<Map<String, dynamic>>.from(recordRows as List))
        row['record_id']?.toString(): row,
    };

    DateTime? earliest;
    DateTime? latest;
    final matchedRecordIds = <String>{};
    final matchedProtocolIds = <String>{};
    var occurrenceCount = 0;

    for (final result in exerciseResults) {
      final recordId = blockToRecord[result['block_result_id']?.toString()];
      if (recordId == null) continue;

      final record = terminalRecords[recordId];
      if (record == null) continue;

      occurrenceCount++;
      matchedRecordIds.add(recordId);

      final protocolId = record['source_protocol_id']?.toString();
      if (protocolId != null && protocolId.isNotEmpty) {
        matchedProtocolIds.add(protocolId);
      }

      final performedAt = _parseDateTime(record['completed_at']) ??
          _parseDateTime(record['started_at']);
      if (performedAt == null) continue;

      if (earliest == null || performedAt.isBefore(earliest)) {
        earliest = performedAt;
      }
      if (latest == null || performedAt.isAfter(latest)) {
        latest = performedAt;
      }
    }

    return ExerciseHistoricalUsage(
      recordCount: matchedRecordIds.length,
      performanceOccurrenceCount: occurrenceCount,
      earliestPerformedAt: earliest,
      latestPerformedAt: latest,
      sessionRevisionCount: matchedProtocolIds.length,
      isAuthoritative: true,
      limitationNote:
          'Counts terminal records with structured source_exercise_id only.',
    );
  }

  static String? _nullableTrimmedString(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
