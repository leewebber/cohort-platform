import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/database_uuid.dart';
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
  Future<ProgrammeLineage?> getLineageById(String lineageId) async {
    try {
      final response = await SupabaseService.client
          .from(_lineagesTable)
          .select()
          .eq('id', lineageId.trim())
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeLineage.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme lineage by id',
      );
    }
  }

  @override
  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
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
          .maybeSingle();

      if (response == null) return null;

      return ProgrammeVersion.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme version by lineage',
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
      final operation = version.id.isEmpty ? 'insert' : 'update';
      debugPrint(
        '[ProgrammeCreate] saveDraftVersion operation=$operation payload=$payload',
      );

      if (version.id.isEmpty) {
        _applyAuthenticatedCoachOwnership(payload);
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
    } catch (error, stackTrace) {
      _logStoreFailure('insert version', error, stackTrace);
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to save programme draft version',
        operation: 'saveDraftVersion',
        tableName: _versionsTable,
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
        final phasePayload = _phaseInsertMap(savedVersion.id, phase);
        _logTreeNodeInsert(
          kind: 'phase',
          localId: phase.id,
          payload: phasePayload,
        );

        final insertedPhase = await SupabaseService.client
            .from(_phasesTable)
            .insert(phasePayload)
            .select()
            .single();

        debugPrint(
          '[ProgrammeTreeSave] inserted phase id=${insertedPhase['id']}',
        );
      }

      for (final weekNode in tree.weekNodes) {
        final weekPayload = _weekInsertMap(savedVersion.id, weekNode.week);
        _logTreeNodeInsert(
          kind: 'week',
          localId: weekNode.week.id,
          payload: weekPayload,
        );

        final insertedWeek = await SupabaseService.client
            .from(_weeksTable)
            .insert(weekPayload)
            .select()
            .single();

        final weekId = insertedWeek['id']?.toString() ?? '';
        debugPrint('[ProgrammeTreeSave] inserted week id=$weekId');

        for (final dayNode in weekNode.sortedDays) {
          final dayPayload = _dayInsertMap(weekId, dayNode.day);
          _logTreeNodeInsert(
            kind: 'day',
            localId: dayNode.day.id,
            payload: dayPayload,
            parentLabel: 'parentWeek=$weekId',
          );

          final insertedDay = await SupabaseService.client
              .from(_daysTable)
              .insert(dayPayload)
              .select()
              .single();

          final dayId = insertedDay['id']?.toString() ?? '';
          debugPrint(
            '[ProgrammeTreeSave] inserted day id=$dayId parentWeek=$weekId',
          );

          for (final slot in dayNode.sortedSlots) {
            final slotPayload = _slotInsertMap(dayId, slot);
            _logTreeNodeInsert(
              kind: 'slot',
              localId: slot.id,
              payload: slotPayload,
              parentLabel: 'parentDay=$dayId',
            );

            final insertedSlot = await SupabaseService.client
                .from(_slotsTable)
                .insert(slotPayload)
                .select()
                .single();

            debugPrint(
              '[ProgrammeTreeSave] inserted slot id=${insertedSlot['id']} parentDay=$dayId',
            );
          }
        }
      }
    } catch (error, stackTrace) {
      _logStoreFailure('save template tree', error, stackTrace);
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to save programme template tree',
        operation: 'saveTemplateTree',
        tableName: _weeksTable,
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

      if (query.lifecycleStatus != null) {
        request = request.eq(
          'lifecycle_status',
          query.lifecycleStatus!.dbValue,
        );
      }

      if (query.primaryGoal != null && query.primaryGoal!.trim().isNotEmpty) {
        request = request.eq('primary_goal', query.primaryGoal!.trim());
      }

      final response = await request.order('updated_at', ascending: false);

      return response
          .map((row) => _catalogEntryFromRow(Map<String, dynamic>.from(row)))
          .where((entry) {
            final term = query.searchTerm?.trim().toLowerCase();
            if (term == null || term.isEmpty) return true;

            return entry.name.toLowerCase().contains(term) ||
                entry.lineageCode.toLowerCase().contains(term) ||
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
      updatedAt: _parseDateTime(row['updated_at']),
      publishedAt: _parseDateTime(row['published_at']),
      archivedAt: _parseDateTime(row['archived_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  Future<ProgrammeLineage> insertLineage(ProgrammeLineage lineage) async {
    try {
      final payload = lineage.toInsertMap();
      payload.remove('id');
      _applyAuthenticatedLineageOwnership(payload);
      debugPrint('[ProgrammeCreate] insertLineage payload=$payload');

      final response = await SupabaseService.client
          .from(_lineagesTable)
          .insert(payload)
          .select()
          .single();

      return ProgrammeLineage.fromMap(Map<String, dynamic>.from(response));
    } catch (error, stackTrace) {
      _logStoreFailure('insert lineage', error, stackTrace);
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to create programme lineage',
        operation: 'insertLineage',
        tableName: _lineagesTable,
      );
    }
  }

  @override
  Future<void> deleteDraftVersion(String versionId) async {
    try {
      await SupabaseService.client
          .from(_versionsTable)
          .delete()
          .eq('id', versionId.trim())
          .eq('lifecycle_status', ProgrammeLifecycleStatus.draft.dbValue);
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to delete programme draft version',
      );
    }
  }

  Map<String, dynamic> _phaseInsertMap(
    String versionId,
    ProgrammeVersionPhase phase,
  ) {
    return phase.toInsertMap()..['version_id'] = versionId;
  }

  Map<String, dynamic> _weekInsertMap(
    String versionId,
    ProgrammeVersionWeek week,
  ) {
    return week.toInsertMap()..['version_id'] = versionId;
  }

  Map<String, dynamic> _dayInsertMap(String weekId, ProgrammeVersionDay day) {
    return day.toInsertMap()..['week_id'] = weekId;
  }

  Map<String, dynamic> _slotInsertMap(
    String dayId,
    ProgrammeVersionSessionSlot slot,
  ) {
    return slot.toInsertMap()..['day_id'] = dayId;
  }

  static void _logTreeNodeInsert({
    required String kind,
    required String localId,
    required Map<String, dynamic> payload,
    String? parentLabel,
  }) {
    final persistedId = DatabaseUuid.persistedIdOrNull(localId);
    final sendsId = payload.containsKey('id');
    final suffix = parentLabel == null ? '' : ' $parentLabel';
    debugPrint(
      '[ProgrammeTreeSave] $kind localId=$localId '
      'persistedId=$persistedId sendsId=$sendsId$suffix',
    );
  }

  static void _logStoreFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('[ProgrammeCreate] store $stage exception=$error');
    debugPrint('[ProgrammeCreate] stackTrace=$stackTrace');
  }

  /// Binds lineage ownership to the active Supabase auth user for RLS INSERT checks.
  static void _applyAuthenticatedLineageOwnership(Map<String, dynamic> payload) {
    final authUserId = SupabaseService.client.auth.currentUser?.id?.trim();
    if (authUserId == null || authUserId.isEmpty) return;
    payload['created_by'] = authUserId;
  }

  /// Binds coach-private draft ownership to the active Supabase auth user.
  static void _applyAuthenticatedCoachOwnership(Map<String, dynamic> payload) {
    final authUserId = SupabaseService.client.auth.currentUser?.id?.trim();
    if (authUserId == null || authUserId.isEmpty) return;
    if (payload['owner_type'] == ProgrammeOwnerType.coach.dbValue) {
      payload['owner_id'] = authUserId;
    }
    payload.putIfAbsent('created_by', () => authUserId);
  }
}
