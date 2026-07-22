import '../../core/services/supabase_service.dart';
import '../../features/performance/models/training_session_record.dart';
import '../../features/performance/models/training_session_record_status.dart';
import '../../features/programme_impact/models/programme_version_impact_models.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_version.dart';
import '../../models/programme_vocabulary.dart';
import '../../models/session_revision_vocabulary.dart';
import 'programme_version_impact_store.dart';

class ProgrammeVersionImpactSupabaseStore extends ProgrammeVersionImpactStore {
  const ProgrammeVersionImpactSupabaseStore();

  static const _versionsTable = 'programme_versions';
  static const _weeksTable = 'programme_version_weeks';
  static const _daysTable = 'programme_version_days';
  static const _slotsTable = 'programme_version_session_slots';
  static const _assignmentsTable = 'programme_assignments';
  static const _recordsTable = 'training_session_records';
  static const _outcomesTable = 'programme_slot_outcomes';
  static const _protocolsTable = 'performance_protocols';
  static const _blockExercisesTable = 'session_block_exercises';
  static const _blocksTable = 'session_blocks';
  static const _stepsTable = 'protocol_steps';
  static const _exercisesTable = 'exercises_v2';
  static const _blockResultsTable = 'training_block_results';
  static const _exerciseResultsTable = 'training_exercise_results';

  @override
  Future<ProgrammeVersion?> getVersionById(String programmeVersionId) async {
    final response = await SupabaseService.client
        .from(_versionsTable)
        .select()
        .eq('id', programmeVersionId.trim())
        .maybeSingle();

    if (response == null) return null;
    return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<List<ProgrammeVersion>> listVersionsForLineage(String lineageId) async {
    final rows = await SupabaseService.client
        .from(_versionsTable)
        .select()
        .eq('lineage_id', lineageId.trim())
        .order('version_number');

    return List<Map<String, dynamic>>.from(rows as List)
        .map(ProgrammeVersion.fromMap)
        .toList();
  }

  @override
  Future<List<ProgrammeVersionSessionReference>> listSessionReferences(
    String programmeVersionId,
  ) async {
    final version = await getVersionById(programmeVersionId);
    if (version == null) return const [];

    final weekRows = await SupabaseService.client
        .from(_weeksTable)
        .select('id, version_id, week_number')
        .eq('version_id', version.id)
        .order('week_number');

    final weeks = List<Map<String, dynamic>>.from(weekRows as List);
    if (weeks.isEmpty) return const [];

    final weekById = {for (final row in weeks) row['id']?.toString(): row};
    final weekIds = weekById.keys.whereType<String>().toList();

    final dayRows = await SupabaseService.client
        .from(_daysTable)
        .select('id, week_id, day_key, day_order')
        .inFilter('week_id', weekIds)
        .order('day_order');

    final days = List<Map<String, dynamic>>.from(dayRows as List);
    if (days.isEmpty) return const [];

    final dayById = {for (final row in days) row['id']?.toString(): row};
    final dayIds = dayById.keys.whereType<String>().toList();

    final slotRows = await SupabaseService.client
        .from(_slotsTable)
        .select('id, day_id, session_order, display_title, protocol_id')
        .inFilter('day_id', dayIds)
        .order('session_order');

    final slots = List<Map<String, dynamic>>.from(slotRows as List);
    if (slots.isEmpty) return const [];

    final protocolIds = slots
        .map((row) => row['protocol_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final protocolMetadata = await _loadProtocolMetadata(protocolIds);

    final references = <ProgrammeVersionSessionReference>[];
    for (final slotRow in slots) {
      final day = dayById[slotRow['day_id']?.toString()];
      if (day == null) continue;
      final week = weekById[day['week_id']?.toString()];
      if (week == null) continue;

      final protocolId = slotRow['protocol_id']?.toString() ?? '';
      final metadata = protocolMetadata[protocolId];

      references.add(
        ProgrammeVersionSessionReference(
          programmeVersionId: version.id,
          slotId: slotRow['id']?.toString() ?? '',
          protocolId: protocolId,
          sessionLineageId: metadata?.sessionLineageId ?? 'unknown-lineage',
          sessionRevisionNumber: metadata?.revisionNumber ?? 1,
          sessionName: metadata?.sessionName ?? 'Session',
          sessionLifecycleStatus: metadata?.lifecycleStatus ??
              SessionRevisionLifecycleStatus.published,
          weekNumber: week['week_number'] ?? 1,
          dayKey: day['day_key']?.toString() ?? 'day_1',
          dayOrder: day['day_order'] ?? 1,
          slotOrder: slotRow['session_order'] ?? 1,
          slotLabel: slotRow['display_title']?.toString(),
        ),
      );
    }

    references.sort(compareProgrammeVersionSessionReferences);
    return references;
  }

  @override
  Future<List<ProgrammeVersionAssignmentImpact>> listAssignmentImpact(
    String programmeVersionId,
  ) async {
    final rows = await SupabaseService.client
        .from(_assignmentsTable)
        .select()
        .eq('programme_version_id', programmeVersionId.trim())
        .eq('status', ProgrammeAssignmentStatus.active.dbValue);

    final assignments = List<Map<String, dynamic>>.from(rows as List)
        .map(ProgrammeAssignment.fromMap)
        .toList();

    return buildActiveAssignmentImpact(
      assignments: assignments,
      programmeVersionId: programmeVersionId.trim(),
    );
  }

  @override
  Future<ProgrammeVersionHistoricalImpactResult> getHistoricalImpact(
    String programmeVersionId,
  ) async {
    try {
      final normalizedVersionId = programmeVersionId.trim();

      final assignmentRows = await SupabaseService.client
          .from(_assignmentsTable)
          .select('id, programme_version_id')
          .eq('programme_version_id', normalizedVersionId);

      final assignmentVersionById = {
        for (final row in List<Map<String, dynamic>>.from(assignmentRows as List))
          row['id']?.toString(): row['programme_version_id']?.toString(),
      };

      final slotVersionById = await _loadSlotVersionIndex(normalizedVersionId);

      final assignmentRecordRows = assignmentVersionById.keys.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from(_recordsTable)
                  .select(
                    'record_id, athlete_id, assignment_id, programme_session_id, source_protocol_id, status, started_at, completed_at',
                  )
                  .inFilter('assignment_id', assignmentVersionById.keys.toList())
                  .neq('status', TrainingSessionRecordStatus.inProgress.dbValue)
                  as List,
            );

      final slotIds = slotVersionById.keys.toList();
      final slotRecordRows = slotIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from(_recordsTable)
                  .select(
                    'record_id, athlete_id, assignment_id, programme_session_id, source_protocol_id, status, started_at, completed_at',
                  )
                  .inFilter('programme_session_id', slotIds)
                  .neq('status', TrainingSessionRecordStatus.inProgress.dbValue)
                  as List,
            );

      final recordsById = <String, TrainingSessionRecord>{};

      void addRecord(Map<String, dynamic> row) {
        final record = TrainingSessionRecord.fromMap(row);
        if (!isRecordAttributableToProgrammeVersion(
          record: record,
          programmeVersionId: normalizedVersionId,
          assignmentVersionById: assignmentVersionById.map(
            (key, value) => MapEntry(key ?? '', value ?? ''),
          ),
          slotVersionById: slotVersionById,
        )) {
          return;
        }
        recordsById[record.recordId] = record;
      }

      for (final row in assignmentRecordRows) {
        addRecord(row);
      }
      for (final row in slotRecordRows) {
        addRecord(row);
      }

      final outcomeRows = assignmentVersionById.keys.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await SupabaseService.client
                  .from(_outcomesTable)
                  .select('assignment_id, outcome_status')
                  .inFilter('assignment_id', assignmentVersionById.keys.toList())
                  .eq('outcome_status', ProgrammeSlotOutcomeStatus.skipped.dbValue)
                  as List,
            );

      final skippedCount = outcomeRows.length;

      final recordIds = recordsById.keys.toList();
      var exerciseResultCount = 0;
      if (recordIds.isNotEmpty) {
        final blockRows = List<Map<String, dynamic>>.from(
          await SupabaseService.client
              .from(_blockResultsTable)
              .select('block_result_id, session_record_id')
              .inFilter('session_record_id', recordIds) as List,
        );

        final blockIds = blockRows
            .map((row) => row['block_result_id']?.toString())
            .whereType<String>()
            .toList();

        if (blockIds.isNotEmpty) {
          final exerciseRows = await SupabaseService.client
              .from(_exerciseResultsTable)
              .select('exercise_result_id')
              .inFilter('block_result_id', blockIds);
          exerciseResultCount =
              List<Map<String, dynamic>>.from(exerciseRows as List).length;
        }
      }

      return ProgrammeVersionHistoricalImpactResult(
        impact: buildHistoricalImpactFromRecords(
          terminalRecords: recordsById.values,
          skippedSessionCount: skippedCount,
          exerciseResultCount: exerciseResultCount,
          isAuthoritative: true,
        ),
      );
    } catch (error) {
      return ProgrammeVersionHistoricalImpactResult(
        impact: ProgrammeVersionHistoricalImpact(
          terminalRecordCount: 0,
          completedSessionCount: 0,
          skippedSessionCount: 0,
          athleteCount: 0,
          sessionRevisionCount: 0,
          exerciseResultCount: 0,
          isAuthoritative: false,
          limitationNote: error.toString(),
        ),
        lookupFailed: true,
        failureMessage: error.toString(),
      );
    }
  }

  @override
  Future<List<ProgrammeVersionExerciseReference>> listExerciseReferences(
    String programmeVersionId,
    Set<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) return const [];

    final normalizedProtocolIds = protocolIds.toList();

    final linkRows = await SupabaseService.client
        .from(_blockExercisesTable)
        .select('id, exercise_id, block_id');

    final links = List<Map<String, dynamic>>.from(linkRows as List);
    if (links.isEmpty) {
      return _listLegacyExerciseReferences(normalizedProtocolIds, const {});
    }

    final blockIds = links
        .map((row) => row['block_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final blockRows = await SupabaseService.client
        .from(_blocksTable)
        .select('block_id, session_id')
        .inFilter('block_id', blockIds);

    final blocks = {
      for (final row in List<Map<String, dynamic>>.from(blockRows as List))
        row['block_id']?.toString(): row['session_id']?.toString(),
    };

    final byExercise = <String, _ExerciseAccumulator>{};
    final protocolsWithBlockLinks = <String>{};

    for (final link in links) {
      final blockId = link['block_id']?.toString();
      final protocolId = blocks[blockId];
      if (protocolId == null || !protocolIds.contains(protocolId)) continue;

      protocolsWithBlockLinks.add(protocolId);
      final exerciseId = link['exercise_id']?.toString() ?? '';
      if (exerciseId.isEmpty) continue;

      final accumulator = byExercise.putIfAbsent(
        exerciseId,
        () => _ExerciseAccumulator(exerciseId: exerciseId),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(protocolId);
    }

    final exerciseIds = byExercise.keys.toList();
    if (exerciseIds.isNotEmpty) {
      final exerciseRows = await SupabaseService.client
          .from(_exercisesTable)
          .select('exercise_id, name')
          .inFilter('exercise_id', exerciseIds);

      for (final row in List<Map<String, dynamic>>.from(exerciseRows as List)) {
        final exerciseId = row['exercise_id']?.toString();
        final name = row['name']?.toString();
        if (exerciseId == null || name == null) continue;
        byExercise[exerciseId]?.exerciseName = name;
      }
    }

    final legacyReferences = await _listLegacyExerciseReferences(
      normalizedProtocolIds,
      protocolsWithBlockLinks,
    );

    for (final legacy in legacyReferences) {
      final accumulator = byExercise.putIfAbsent(
        legacy.exerciseId,
        () => _ExerciseAccumulator(
          exerciseId: legacy.exerciseId,
          exerciseName: legacy.exerciseName,
        ),
      );
      accumulator.blockLinkCount += legacy.blockLinkCount;
      accumulator.sessionRevisionIds.addAll(legacy.sessionRevisionIds);
      accumulator.isLegacyReference = true;
    }

    final results = byExercise.values
        .map(
          (accumulator) => ProgrammeVersionExerciseReference(
            exerciseId: accumulator.exerciseId,
            exerciseName: accumulator.exerciseName ?? accumulator.exerciseId,
            sessionRevisionIds: accumulator.sessionRevisionIds.toList()..sort(),
            sessionCount: accumulator.sessionRevisionIds.length,
            blockLinkCount: accumulator.blockLinkCount,
            isLegacyReference: accumulator.isLegacyReference,
          ),
        )
        .toList()
      ..sort(compareProgrammeVersionExerciseReferences);

    return results;
  }

  Future<Map<String, _ProtocolMetadata>> _loadProtocolMetadata(
    List<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) return const {};

    final rows = await SupabaseService.client
        .from(_protocolsTable)
        .select(
          'protocol_id, name, published, session_lineage_id, revision_number, lifecycle_status',
        )
        .inFilter('protocol_id', protocolIds);

    final metadata = <String, _ProtocolMetadata>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final protocolId = row['protocol_id']?.toString();
      if (protocolId == null || protocolId.isEmpty) continue;
      metadata[protocolId] = _ProtocolMetadata(
        sessionLineageId:
            row['session_lineage_id']?.toString() ?? 'unknown-lineage',
        revisionNumber: row['revision_number'] ?? 1,
        sessionName: row['name']?.toString() ?? 'Session',
        lifecycleStatus: SessionRevisionLifecycleStatusDb.fromDb(
          row['lifecycle_status']?.toString(),
        ),
      );
    }
    return metadata;
  }

  Future<Map<String, String>> _loadSlotVersionIndex(String versionId) async {
    final weekRows = await SupabaseService.client
        .from(_weeksTable)
        .select('id')
        .eq('version_id', versionId);

    final weekIds = List<Map<String, dynamic>>.from(weekRows as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    if (weekIds.isEmpty) return const {};

    final dayRows = await SupabaseService.client
        .from(_daysTable)
        .select('id, week_id')
        .inFilter('week_id', weekIds);

    final dayById = {
      for (final row in List<Map<String, dynamic>>.from(dayRows as List))
        row['id']?.toString(): row['week_id']?.toString(),
    };

    final slotRows = await SupabaseService.client
        .from(_slotsTable)
        .select('id, day_id')
        .inFilter('day_id', dayById.keys.whereType<String>().toList());

    final weekVersionById = {for (final weekId in weekIds) weekId: versionId};

    final slotVersionById = <String, String>{};
    for (final row in List<Map<String, dynamic>>.from(slotRows as List)) {
      final slotId = row['id']?.toString();
      if (slotId == null || slotId.isEmpty) continue;
      final weekId = dayById[row['day_id']?.toString()];
      slotVersionById[slotId] = weekVersionById[weekId] ?? versionId;
    }
    return slotVersionById;
  }

  Future<List<ProgrammeVersionExerciseReference>> _listLegacyExerciseReferences(
    List<String> protocolIds,
    Set<String> excludeProtocolIds,
  ) async {
    final targetProtocolIds = protocolIds
        .where((protocolId) => !excludeProtocolIds.contains(protocolId))
        .toList();

    if (targetProtocolIds.isEmpty) return const [];

    final stepRows = await SupabaseService.client
        .from(_stepsTable)
        .select('id, exercise_id, protocol_id')
        .inFilter('protocol_id', targetProtocolIds)
        .not('exercise_id', 'is', null);

    final byExercise = <String, _ExerciseAccumulator>{};
    for (final row in List<Map<String, dynamic>>.from(stepRows as List)) {
      final exerciseId = row['exercise_id']?.toString();
      final protocolId = row['protocol_id']?.toString();
      if (exerciseId == null || protocolId == null) continue;

      final accumulator = byExercise.putIfAbsent(
        exerciseId,
        () => _ExerciseAccumulator(exerciseId: exerciseId),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(protocolId);
      accumulator.isLegacyReference = true;
    }

    return byExercise.values
        .map(
          (accumulator) => ProgrammeVersionExerciseReference(
            exerciseId: accumulator.exerciseId,
            exerciseName: accumulator.exerciseName ?? accumulator.exerciseId,
            sessionRevisionIds: accumulator.sessionRevisionIds.toList(),
            sessionCount: accumulator.sessionRevisionIds.length,
            blockLinkCount: accumulator.blockLinkCount,
            isLegacyReference: true,
          ),
        )
        .toList();
  }
}

class _ProtocolMetadata {
  const _ProtocolMetadata({
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.sessionName,
    required this.lifecycleStatus,
  });

  final String sessionLineageId;
  final int revisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus lifecycleStatus;
}

class _ExerciseAccumulator {
  _ExerciseAccumulator({
    required this.exerciseId,
    this.exerciseName,
  });

  final String exerciseId;
  String? exerciseName;
  final Set<String> sessionRevisionIds = {};
  var blockLinkCount = 0;
  var isLegacyReference = false;
}
