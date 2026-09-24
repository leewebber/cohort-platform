import '../data/repositories/programme_assignment_store.dart';
import '../data/repositories/programme_version_store.dart';
import '../features/plans/models/programmed_session_key.dart';
import '../features/programme/models/fixed_programme_occurrence_projection.dart';
import '../features/programme/models/future_programme_session_swap.dart';
import '../features/programme/models/programme_catalog_entry.dart';
import '../features/programme/models/programme_template.dart';
import '../features/programme/services/fixed_programme_occurrence_projection_store.dart';
import '../features/programme/services/future_programme_session_swap_store.dart';
import '../features/session/services/programme_training_session_start_store.dart';
import '../models/programme_assignment.dart';
import '../models/programme_lineage.dart';
import '../models/programme_version.dart';

class PreviewAssignmentStore implements ProgrammeAssignmentStore {
  PreviewAssignmentStore(this.assignment, {List<ProgrammeAssignment>? others})
    : others = others ?? <ProgrammeAssignment>[];

  ProgrammeAssignment assignment;
  final List<ProgrammeAssignment> others;

  List<ProgrammeAssignment> get _all => [assignment, ...others];

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) async {
    for (final row in _all) {
      if (row.athleteId == athleteId && row.isActive) return row;
    }
    return null;
  }

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async {
    for (final row in _all) {
      if (row.id == assignmentId) return row;
    }
    return null;
  }

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment next) async {
    assignment = next;
    return next;
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment next) async {
    assignment = next;
    return next;
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async {
    return _all.where((row) => row.athleteId == athleteId).toList();
  }

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async {
    return assignment.programmeVersionId == programmeVersionId ? 1 : 0;
  }
}

class PreviewVersionStore implements ProgrammeVersionStore {
  PreviewVersionStore({
    required this.lineage,
    required this.version,
    required this.tree,
    required this.catalogue,
  });

  final ProgrammeLineage lineage;
  final ProgrammeVersion version;
  final ProgrammeTemplateTree tree;
  final List<ProgrammeCatalogEntry> catalogue;

  @override
  Future<ProgrammeLineage?> getLineageByCode(String code) async {
    return lineage.code == code ? lineage : null;
  }

  @override
  Future<ProgrammeLineage?> getLineageByImportKey(String importKey) async {
    return lineage.importKey == importKey ? lineage : null;
  }

  @override
  Future<ProgrammeLineage?> getLineageById(String lineageId) async {
    return lineage.id == lineageId ? lineage : null;
  }

  @override
  Future<ProgrammeVersion?> getVersionById(String versionId) async {
    return version.id == versionId ? version : null;
  }

  @override
  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
    required String lineageCode,
    required int versionNumber,
  }) async {
    if (lineage.code != lineageCode || version.versionNumber != versionNumber) {
      return null;
    }
    return version;
  }

  @override
  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  }) {
    return getVersionByLineageAndNumber(
      lineageCode: lineageCode,
      versionNumber: versionNumber,
    );
  }

  @override
  Future<ProgrammeTemplateTree?> loadTemplateTree(String versionId) async {
    return version.id == versionId ? tree : null;
  }

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogueVersions(
    ProgrammeCatalogueQuery query,
  ) async {
    return catalogue;
  }

  @override
  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion next) {
    throw UnsupportedError('Preview catalogue is read-only.');
  }

  @override
  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplateTree tree,
  }) {
    throw UnsupportedError('Preview catalogue is read-only.');
  }

  @override
  Future<ProgrammeLineage> insertLineage(ProgrammeLineage lineage) {
    throw UnsupportedError('Preview catalogue is read-only.');
  }

  @override
  Future<void> deleteDraftVersion(String versionId) {
    throw UnsupportedError('Preview catalogue is read-only.');
  }
}

class PreviewProjectionStore implements FixedProgrammeOccurrenceProjectionStore {
  PreviewProjectionStore(this.projection);

  FixedProgrammeCalendarProjection? projection;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async =>
      projection?.isInspectionOnly == true ? null : projection;

  @override
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  ) async {
    final loaded = projection;
    if (loaded == null || loaded.assignmentId != assignmentId) {
      throw const FixedProgrammeCalendarUnavailableException(
        'assignment_not_found',
      );
    }
    return loaded;
  }
}

class PreviewSwapStore implements FutureProgrammeSessionSwapStore {
  PreviewSwapStore({
    required this.assignmentStore,
    required this.projectionStore,
    required this.packageContentHash,
  });

  final PreviewAssignmentStore assignmentStore;
  final PreviewProjectionStore projectionStore;
  final String packageContentHash;

  @override
  Future<FutureProgrammeSessionSwapResult> swapAndBegin(
    FutureProgrammeSessionSwapCommand command,
  ) async {
    final calendar = projectionStore.projection;
    if (calendar == null) {
      return const FutureProgrammeSessionSwapResult(
        status: FutureProgrammeSessionSwapStatus.failed,
        message: 'No preview calendar is loaded.',
      );
    }
    FixedProgrammeOccurrenceProjection? today;
    FixedProgrammeOccurrenceProjection? selected;
    for (final occurrence in calendar.occurrences) {
      if (occurrence.occurrenceId == command.todayOccurrenceId) {
        today = occurrence;
      }
      if (occurrence.occurrenceId == command.selectedOccurrenceId) {
        selected = occurrence;
      }
    }
    if (today == null || selected == null) {
      return const FutureProgrammeSessionSwapResult(
        status: FutureProgrammeSessionSwapStatus.rejected,
        code: 'swap_not_offered',
      );
    }

    FixedProgrammeOccurrenceProjection relocate(
      FixedProgrammeOccurrenceProjection source,
      String scheduledDate,
      FixedProgrammeOccurrenceState state,
    ) {
      return FixedProgrammeOccurrenceProjection(
        assignmentId: source.assignmentId,
        occurrenceId: source.occurrenceId,
        sessionSlotId: source.sessionSlotId,
        programmeVersionId: source.programmeVersionId,
        protocolId: source.protocolId,
        programmedSessionKey: ProgrammedSessionKey.fromMaterialisedProgramme(
          assignment: assignmentStore.assignment.copyWith(
            currentWeek: source.weekNumber,
            currentDayKey: source.dayKey,
            currentSessionOrder: source.sessionOrder,
          ),
          protocolId: source.protocolId,
          packageContentHash: packageContentHash,
          scheduleDate: DateTime.parse(scheduledDate),
        ).value,
        weekNumber: source.weekNumber,
        dayKey: source.dayKey,
        sessionOrder: source.sessionOrder,
        scheduledDate: scheduledDate,
        originalScheduledDate: source.originalScheduledDate,
        state: state,
        sessionTitle: source.sessionTitle,
        sessionType: source.sessionType,
      );
    }

    final movedToday = relocate(
      selected,
      today.scheduledDate,
      FixedProgrammeOccurrenceState.today,
    );
    final displaced = relocate(
      today,
      selected.scheduledDate,
      FixedProgrammeOccurrenceState.planned,
    );
    projectionStore.projection = calendar.copyWith(
      occurrences: [
        for (final occurrence in calendar.occurrences)
          if (occurrence.occurrenceId == today.occurrenceId)
            movedToday
          else if (occurrence.occurrenceId == selected.occurrenceId)
            displaced
          else
            occurrence,
      ],
    );
    return FutureProgrammeSessionSwapResult(
      status: FutureProgrammeSessionSwapStatus.created,
      assignmentId: assignmentStore.assignment.id,
      selectedOccurrenceId: selected.occurrenceId,
      todayScheduledDate: today.scheduledDate,
      displacedScheduledDate: selected.scheduledDate,
      programmedSessionKey: movedToday.programmedSessionKey,
    );
  }
}

class PreviewStartStore implements ProgrammeTrainingSessionStartStore {
  int _nextId = 1;
  final ids = <String, int>{};

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    final key = '${payload['assignment_id']}:${payload['session_slot_id']}';
    final existing = ids[key];
    final id = existing ?? _nextId++;
    ids[key] = id;
    return {
      'status': existing == null ? 'created' : 'resumed',
      'code': existing == null ? 'session_created' : 'existing_session',
      'training_session': {
        'id': id,
        'athlete_id': payload['athlete_id'] ?? 'athlete.preview.lee',
        'protocol_id': payload['effective_protocol_id'],
        'status': 'in_progress',
        'programme_id': 'APOLLO-V2',
        'week_number': payload['expected_week'],
        'day': payload['expected_day_key'],
        'started_at': DateTime.utc(2026, 9, 10, 10).toIso8601String(),
      },
    };
  }
}
