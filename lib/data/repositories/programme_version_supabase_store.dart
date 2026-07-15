import '../../core/services/supabase_service.dart';
import '../../features/programme/models/programme_catalog_entry.dart';
import '../../features/programme/models/programme_template.dart';
import '../../models/programme_lineage.dart';
import '../../models/programme_version.dart';
import '../../models/programme_version_day.dart';
import '../../models/programme_version_phase.dart';
import '../../models/programme_version_session_slot.dart';
import '../../models/programme_version_week.dart';
import '../../models/programme_vocabulary.dart';
import 'programme_store_exception.dart';
import 'programme_template_tree_assembler.dart';
import 'programme_version_store.dart';

/// Supabase implementation of [ProgrammeVersionStore].
class ProgrammeVersionSupabaseStore implements ProgrammeVersionStore {
  const ProgrammeVersionSupabaseStore({
    this._assembler = const ProgrammeTemplateTreeAssembler(),
  });

  static const _lineagesTable = 'programme_lineages';
  static const _versionsTable = 'programme_versions';
  static const _phasesTable = 'programme_version_phases';
  static const _weeksTable = 'programme_version_weeks';
  static const _daysTable = 'programme_version_days';
  static const _slotsTable = 'programme_version_session_slots';

  final ProgrammeTemplateTreeAssembler _assembler;

  @override
  Future<ProgrammeLineage?> getLineageByCode(String code) async {
    try {
      final response = await SupabaseService.client
          .from(_lineagesTable)
          .select()
          .eq('code', code.trim())
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeLineage.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme lineage by code',
      );
    }
  }

  @override
  Future<ProgrammeVersion?> getVersionById(String versionId) async {
    try {
      final response = await SupabaseService.client
          .from(_versionsTable)
          .select()
          .eq('id', versionId.trim())
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme version',
      );
    }
  }

  @override
  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  }) async {
    final lineage = await getLineageByCode(lineageCode);
    if (lineage == null) return null;

    try {
      final response = await SupabaseService.client
          .from(_versionsTable)
          .select()
          .eq('lineage_id', lineage.id)
          .eq('version_number', versionNumber)
          .eq('lifecycle_status', ProgrammeLifecycleStatus.published.dbValue)
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch published programme version',
      );
    }
  }

  @override
  Future<ProgrammeTemplateTree?> loadTemplateTree(String versionId) async {
    final version = await getVersionById(versionId);
    if (version == null) return null;

    try {
      final phasesResponse = await SupabaseService.client
          .from(_phasesTable)
          .select()
          .eq('version_id', version.id)
          .order('phase_order', ascending: true);

      final weeksResponse = await SupabaseService.client
          .from(_weeksTable)
          .select()
          .eq('version_id', version.id)
          .order('week_number', ascending: true);

      final weekIds = weeksResponse
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final daysResponse = weekIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await SupabaseService.client
              .from(_daysTable)
              .select()
              .inFilter('week_id', weekIds)
              .order('day_order', ascending: true);

      final dayIds = daysResponse
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      final slotsResponse = dayIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await SupabaseService.client
              .from(_slotsTable)
              .select()
              .inFilter('day_id', dayIds)
              .order('session_order', ascending: true);

      return _assembler.assemble(
        version: version,
        phases: phasesResponse
            .map(
              (row) => ProgrammeVersionPhase.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
        weeks: weeksResponse
            .map(
              (row) => ProgrammeVersionWeek.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
        days: daysResponse
            .map(
              (row) => ProgrammeVersionDay.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
        slots: slotsResponse
            .map(
              (row) => ProgrammeVersionSessionSlot.fromMap(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
      );
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to load programme template tree',
      );
    }
  }

  @override
  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion version) async {
    try {
      final payload = version.toInsertMap();

      if (version.id.isEmpty) {
        final response = await SupabaseService.client
            .from(_versionsTable)
            .insert(payload)
            .select()
            .single();

        return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
      }

      final response = await SupabaseService.client
          .from(_versionsTable)
          .update(payload)
          .eq('id', version.id)
          .select()
          .single();

      return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to save programme draft version',
      );
    }
  }

  @override
  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplateTree tree,
  }) async {
    final savedVersion = await saveDraftVersion(version);

    try {
      await SupabaseService.client
          .from(_weeksTable)
          .delete()
          .eq('version_id', savedVersion.id);

      await SupabaseService.client
          .from(_phasesTable)
          .delete()
          .eq('version_id', savedVersion.id);

      for (final phase in tree.template.phases) {
        await SupabaseService.client
            .from(_phasesTable)
            .insert(_phaseInsertMap(savedVersion.id, phase));
      }

      for (final weekNode in tree.weekNodes) {
        final insertedWeek = await SupabaseService.client
            .from(_weeksTable)
            .insert(_weekInsertMap(savedVersion.id, weekNode.week))
            .select()
            .single();

        final weekId = insertedWeek['id']?.toString() ?? '';
        for (final dayNode in weekNode.sortedDays) {
          final insertedDay = await SupabaseService.client
              .from(_daysTable)
              .insert(_dayInsertMap(weekId, dayNode.day))
              .select()
              .single();

          final dayId = insertedDay['id']?.toString() ?? '';
          for (final slot in dayNode.sortedSlots) {
            await SupabaseService.client
                .from(_slotsTable)
                .insert(_slotInsertMap(dayId, slot));
          }
        }
      }
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to save programme template tree',
      );
    }
  }

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogueVersions(
    ProgrammeCatalogueQuery query,
  ) async {
    try {
      var request = SupabaseService.client
          .from(_versionsTable)
          .select('*, programme_lineages!inner(code)');

      if (query.libraryScope != null) {
        request = request.eq('library_scope', query.libraryScope!.dbValue);
      }

      if (query.ownerType != null) {
        request = request.eq('owner_type', query.ownerType!.dbValue);
      }

      if (query.ownerId != null && query.ownerId!.trim().isNotEmpty) {
        request = request.eq('owner_id', query.ownerId!.trim());
      }

      if (query.includeGlobalApprovedOnly) {
        request = request.eq('approved_for_global', true);
      }

      final response = await request.order('name', ascending: true);

      return response
          .map((row) => _catalogEntryFromRow(Map<String, dynamic>.from(row)))
          .where((entry) {
            final term = query.searchTerm?.trim().toLowerCase();
            if (term == null || term.isEmpty) return true;

            return entry.name.toLowerCase().contains(term) ||
                (entry.description?.toLowerCase().contains(term) ?? false);
          })
          .toList();
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to list programme catalogue versions',
      );
    }
  }

  ProgrammeCatalogEntry _catalogEntryFromRow(Map<String, dynamic> row) {
    final lineage = row['programme_lineages'];
    final lineageCode = lineage is Map<String, dynamic>
        ? lineage['code']?.toString() ?? ''
        : '';

    return ProgrammeCatalogEntry(
      versionId: row['id']?.toString() ?? '',
      lineageCode: lineageCode,
      versionNumber: row['version_number'] ?? 1,
      name: row['name']?.toString() ?? '',
      lifecycleStatus: ProgrammeLifecycleStatusDb.fromDb(
        row['lifecycle_status']?.toString(),
      ),
      libraryScope: ProgrammeLibraryScopeDb.fromDb(
        row['library_scope']?.toString(),
      ),
      ownerType: ProgrammeOwnerTypeDb.fromDb(row['owner_type']?.toString()),
      ownerId: row['owner_id']?.toString(),
      description: row['description']?.toString(),
      durationWeeks: row['duration_weeks'],
      difficulty: row['difficulty']?.toString(),
      primaryGoal: row['primary_goal']?.toString(),
      sessionsPerWeek: row['sessions_per_week'],
      approvedForGlobal: row['approved_for_global'] == true,
    );
  }

  Map<String, dynamic> _phaseInsertMap(
    String versionId,
    ProgrammeVersionPhase phase,
  ) {
    return {
      if (phase.id.isNotEmpty) 'id': phase.id,
      'version_id': versionId,
      'phase_order': phase.phaseOrder,
      'title': phase.title,
      if (phase.intent != null) 'intent': phase.intent!.dbValue,
      if (phase.coachNote != null) 'coach_note': phase.coachNote,
    };
  }

  Map<String, dynamic> _weekInsertMap(
    String versionId,
    ProgrammeVersionWeek week,
  ) {
    return {
      if (week.id.isNotEmpty) 'id': week.id,
      'version_id': versionId,
      if (week.phaseId != null) 'phase_id': week.phaseId,
      'week_number': week.weekNumber,
      if (week.title != null) 'title': week.title,
      if (week.intent != null) 'intent': week.intent!.dbValue,
      if (week.coachNote != null) 'coach_note': week.coachNote,
      if (week.athleteNote != null) 'athlete_note': week.athleteNote,
    };
  }

  Map<String, dynamic> _dayInsertMap(String weekId, ProgrammeVersionDay day) {
    return {
      if (day.id.isNotEmpty) 'id': day.id,
      'week_id': weekId,
      'day_key': day.dayKey,
      'day_order': day.dayOrder,
      if (day.title != null) 'title': day.title,
      'day_type': day.dayType.dbValue,
      if (day.intent != null) 'intent': day.intent!.dbValue,
      if (day.coachNote != null) 'coach_note': day.coachNote,
      if (day.athleteNote != null) 'athlete_note': day.athleteNote,
    };
  }

  Map<String, dynamic> _slotInsertMap(
    String dayId,
    ProgrammeVersionSessionSlot slot,
  ) {
    return {
      if (slot.id.isNotEmpty) 'id': slot.id,
      'day_id': dayId,
      'session_order': slot.sessionOrder,
      'protocol_id': slot.protocolId,
      if (slot.displayTitle != null) 'display_title': slot.displayTitle,
      'time_of_day': slot.timeOfDay.dbValue,
      'is_optional': slot.isOptional,
      'completion_expectation': slot.completionExpectation.dbValue,
      if (slot.coachNote != null) 'coach_note': slot.coachNote,
      if (slot.athleteNote != null) 'athlete_note': slot.athleteNote,
    };
  }
}
