import '../../core/services/supabase_service.dart';
import '../../features/programme_comparison/models/programme_version_comparison_models.dart';
import '../../models/programme_version.dart';
import '../../models/session_revision_vocabulary.dart';
import 'programme_version_comparison_store.dart';
import 'programme_version_impact_store.dart';
import 'programme_version_impact_supabase_store.dart';

class ProgrammeVersionComparisonSupabaseStore
    extends ProgrammeVersionComparisonStore {
  const ProgrammeVersionComparisonSupabaseStore({
    ProgrammeVersionImpactStore? impactStore,
  }) : _impactStore = impactStore ?? const ProgrammeVersionImpactSupabaseStore();

  final ProgrammeVersionImpactStore _impactStore;

  static const _weeksTable = 'programme_version_weeks';
  static const _daysTable = 'programme_version_days';
  static const _slotsTable = 'programme_version_session_slots';
  static const _protocolsTable = 'performance_protocols';

  @override
  Future<ProgrammeVersion?> getVersionById(String programmeVersionId) async {
    return _impactStore.getVersionById(programmeVersionId);
  }

  @override
  Future<ProgrammeVersionComparisonSnapshot> loadSnapshot(
    String programmeVersionId, {
    bool exerciseEnrichmentAuthoritative = true,
    String? exerciseEnrichmentLimitation,
  }) async {
    final version = await getVersionById(programmeVersionId);
    if (version == null) {
      throw ProgrammeVersionComparisonStoreException(
        'Programme version $programmeVersionId was not found.',
      );
    }

    final weekRows = await SupabaseService.client
        .from(_weeksTable)
        .select('id, version_id, week_number, title')
        .eq('version_id', version.id)
        .order('week_number');

    final weeks = List<Map<String, dynamic>>.from(weekRows as List);
    final weekRefs = weeks
        .map(
          (row) => ProgrammeWeekReference(
            weekId: row['id']?.toString() ?? '',
            weekIndex: row['week_number'] ?? 1,
            title: row['title']?.toString(),
          ),
        )
        .toList();

    final weekById = {for (final row in weeks) row['id']?.toString(): row};
    final weekIds = weekById.keys.whereType<String>().toList();

    final dayRows = weekIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from(_daysTable)
                .select('id, week_id, day_key, day_order, title')
                .inFilter('week_id', weekIds)
                .order('day_order') as List,
          );

    final dayRefs = <ProgrammeDayReference>[];
    final slots = <ProgrammeSlotSnapshot>[];

    for (final dayRow in dayRows) {
      final week = weekById[dayRow['week_id']?.toString()];
      if (week == null) continue;

      dayRefs.add(
        ProgrammeDayReference(
          dayId: dayRow['id']?.toString() ?? '',
          weekIndex: week['week_number'] ?? 1,
          dayIndex: dayRow['day_order'] ?? 1,
          dayKey: dayRow['day_key']?.toString() ?? 'day_1',
          title: dayRow['day_title']?.toString() ?? dayRow['title']?.toString(),
        ),
      );
    }

    final dayIds = dayRows
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .toList();

    final slotRows = dayIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from(_slotsTable)
                .select(
                  'id, day_id, session_order, display_title, protocol_id, time_of_day, is_optional, completion_expectation, coach_note, athlete_note',
                )
                .inFilter('day_id', dayIds)
                .order('session_order') as List,
          );

    final dayById = {for (final row in dayRows) row['id']?.toString(): row};
    final protocolIds = slotRows
        .map((row) => row['protocol_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final protocolMetadata = await _loadProtocolMetadata(protocolIds);

    for (final slotRow in slotRows) {
      final day = dayById[slotRow['day_id']?.toString()];
      if (day == null) continue;
      final week = weekById[day['week_id']?.toString()];
      if (week == null) continue;

      final protocolId = slotRow['protocol_id']?.toString() ?? '';
      final metadata = protocolMetadata[protocolId];

      slots.add(
        ProgrammeSlotSnapshot(
          slotId: slotRow['id']?.toString() ?? '',
          weekId: week['id']?.toString() ?? '',
          dayId: day['id']?.toString() ?? '',
          weekIndex: week['week_number'] ?? 1,
          dayIndex: day['day_order'] ?? 1,
          slotIndex: slotRow['session_order'] ?? 1,
          dayKey: day['day_key']?.toString() ?? 'day_1',
          protocolId: protocolId,
          sessionLineageId: metadata?.sessionLineageId ?? 'unknown-lineage',
          sessionRevisionNumber: metadata?.revisionNumber ?? 1,
          sessionName: metadata?.sessionName ?? 'Session',
          sessionLifecycleStatus: metadata?.lifecycleStatus ??
              SessionRevisionLifecycleStatus.published,
          slotLabel: slotRow['display_title']?.toString(),
          timeOfDay: slotRow['time_of_day']?.toString(),
          isOptional: slotRow['is_optional'] == true,
          completionExpectation:
              slotRow['completion_expectation']?.toString(),
          coachNote: slotRow['coach_note']?.toString(),
          athleteNote: slotRow['athlete_note']?.toString(),
        ),
      );
    }

    List<ExerciseReferenceChange> exercises = const [];
    if (exerciseEnrichmentAuthoritative && protocolIds.isNotEmpty) {
      try {
        final impactExercises = await _impactStore.listExerciseReferences(
          version.id,
          protocolIds.toSet(),
        );
        exercises = impactExercises
            .map(
              (exercise) => ExerciseReferenceChange(
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.exerciseName,
                changeType: ProgrammeChangeType.unchanged,
                sourceSessionRevisionIds: exercise.sessionRevisionIds,
                targetSessionRevisionIds: const [],
                sourceBlockLinkCount: exercise.blockLinkCount,
                targetBlockLinkCount: 0,
              ),
            )
            .toList();
      } catch (error) {
        exerciseEnrichmentAuthoritative = false;
        exerciseEnrichmentLimitation ??= error.toString();
      }
    }

    return ProgrammeVersionComparisonSnapshot(
      versionId: version.id,
      lineageId: version.lineageId,
      versionNumber: version.versionNumber,
      lifecycleStatus: version.lifecycleStatus,
      programmeName: version.name,
      metadata: _metadataFromVersion(version),
      weeks: weekRefs,
      days: dayRefs,
      slots: slots,
      exercises: exercises,
      exerciseEnrichmentAuthoritative: exerciseEnrichmentAuthoritative,
      exerciseEnrichmentLimitation: exerciseEnrichmentLimitation,
    );
  }

  Map<String, String?> _metadataFromVersion(ProgrammeVersion version) {
    return {
      'name': version.name.trim(),
      'description': version.description?.trim(),
      'durationWeeks': version.durationWeeks?.toString(),
      'targetAthlete': version.targetAthlete?.trim(),
      'difficulty': version.difficulty?.trim(),
      'primaryGoal': version.primaryGoal?.trim(),
      'equipmentRequirements': version.equipmentRequirements?.trim(),
      'sessionsPerWeek': version.sessionsPerWeek?.toString(),
    };
  }

  Future<Map<String, _ProtocolMetadata>> _loadProtocolMetadata(
    List<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) return const {};

    final rows = await SupabaseService.client
        .from(_protocolsTable)
        .select(
          'protocol_id, name, session_lineage_id, revision_number, lifecycle_status',
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

Map<String, String?> extractComparableMetadata(ProgrammeVersion version) {
  return {
    'name': version.name.trim(),
    'description': version.description?.trim(),
    'durationWeeks': version.durationWeeks?.toString(),
    'targetAthlete': version.targetAthlete?.trim(),
    'difficulty': version.difficulty?.trim(),
    'primaryGoal': version.primaryGoal?.trim(),
    'equipmentRequirements': version.equipmentRequirements?.trim(),
    'sessionsPerWeek': version.sessionsPerWeek?.toString(),
  };
}
