import 'package:flutter/foundation.dart';

import '../auth/services/current_user_session.dart';
import '../programme/debug/programme_debug_identity.dart';
import '../../core/services/supabase_service.dart';
import '../../data/repositories/programme_version_supabase_store.dart';
import '../../data/repositories/programme_version_store.dart';
import '../../features/admin/services/protocol_builder_service.dart';
import '../../models/programme_lineage.dart';
import '../programme/models/programme_template.dart';
import '../../models/programme_version.dart';
import '../../models/programme_version_day.dart';
import '../../models/programme_version_session_slot.dart';
import '../../models/programme_version_week.dart';
import '../../models/programme_vocabulary.dart';
import 'founder_acceptance_content.dart';
import 'founder_acceptance_dev_fixtures.dart';
import 'founder_acceptance_install_result.dart';

/// Developer-only installer for the Founder Acceptance Programme.
///
/// Creates or updates the canonical programme and M8 Modern Capture Test session.
/// Never touches unrelated programmes or user-authored content.
class FounderAcceptanceInstaller {
  FounderAcceptanceInstaller({
    ProtocolBuilderService? protocolBuilderService,
    ProgrammeVersionStore? versionStore,
  })  : _protocolBuilderService =
            protocolBuilderService ?? ProtocolBuilderService(),
        _versionStore = versionStore ?? const ProgrammeVersionSupabaseStore();

  final ProtocolBuilderService _protocolBuilderService;
  final ProgrammeVersionStore _versionStore;

  String get _authoringCoachId {
    ProgrammeDebugIdentity.assertDebugMode();
    return CurrentUserSession.maybeInstance?.coachId ??
        ProgrammeDebugIdentity.coachId;
  }

  Future<FounderAcceptanceInstallResult> install() async {
    final existingLineage = await _versionStore.getLineageByCode(
      FounderAcceptanceContent.programmeLineageCode,
    );

    final lineage = await _loadOrCreateLineage();
    final version = await _loadOrCreateVersion(lineage.id);

    final draft = FounderAcceptanceContent.protocolDraft(
      programmeVersionId: version.id,
    );

    final hadSession = await _protocolExists();
    final saveResult = await _protocolBuilderService.saveDraft(draft);
    final sessionCreated = !hadSession || saveResult.created;

    final tree = _buildTemplateTree(version);
    await _versionStore.saveTemplateTree(version: version, tree: tree);

    final programmeCreated = existingLineage == null;
    final programmeUpdated = existingLineage != null;
    final sessionUpdated = hadSession && !sessionCreated;

    final summary = _buildSummary(
      programmeCreated: programmeCreated,
      programmeUpdated: programmeUpdated,
      sessionCreated: sessionCreated,
      sessionUpdated: sessionUpdated,
      blockCount: draft.blocks.length,
    );

    debugPrint('[FounderAcceptanceInstall] $summary');

    return FounderAcceptanceInstallResult(
      programmeCreated: programmeCreated,
      programmeUpdated: programmeUpdated,
      sessionCreated: sessionCreated,
      sessionUpdated: sessionUpdated,
      blockCount: draft.blocks.length,
      summaryMessage: summary,
    );
  }

  Future<bool> _protocolExists() async {
    try {
      await _protocolBuilderService.loadProtocol(FounderAcceptanceContent.protocolId);
      return true;
    } on ProtocolBuilderException {
      return false;
    }
  }

  Future<ProgrammeLineage> _loadOrCreateLineage() async {
    final existing = await _versionStore.getLineageByCode(
      FounderAcceptanceContent.programmeLineageCode,
    );
    if (existing != null) return existing;

    await _tryUpsertLineageRecord();

    final afterUpsert = await _versionStore.getLineageByCode(
      FounderAcceptanceContent.programmeLineageCode,
    );
    if (afterUpsert != null) return afterUpsert;

    return _versionStore.insertLineage(
      ProgrammeLineage(
        id: FounderAcceptanceDevFixtures.lineageId,
        code: FounderAcceptanceContent.programmeLineageCode,
        createdBy: _authoringCoachId,
      ),
    );
  }

  Future<ProgrammeVersion> _loadOrCreateVersion(String lineageId) async {
    var version = await _versionStore.getVersionByLineageAndNumber(
      lineageCode: FounderAcceptanceContent.programmeLineageCode,
      versionNumber: 1,
    );

    if (version == null) {
      await _tryUpsertVersionRecord(lineageId);
      version = await _versionStore.getVersionByLineageAndNumber(
        lineageCode: FounderAcceptanceContent.programmeLineageCode,
        versionNumber: 1,
      );
    }

    if (version == null) {
      version = await _versionStore.saveDraftVersion(
        ProgrammeVersion(
          id: FounderAcceptanceDevFixtures.versionId,
          lineageId: lineageId,
          versionNumber: 1,
          lifecycleStatus: ProgrammeLifecycleStatus.draft,
          libraryScope: ProgrammeLibraryScope.cohortGlobal,
          ownerType: ProgrammeOwnerType.global,
          name: FounderAcceptanceContent.programmeName,
          description: FounderAcceptanceContent.programmeDescription,
          durationWeeks: 1,
          sessionsPerWeek: 1,
          createdBy: _authoringCoachId,
        ),
      );
    } else {
      version = await _versionStore.saveDraftVersion(
        version.copyWith(
          name: FounderAcceptanceContent.programmeName,
          description: FounderAcceptanceContent.programmeDescription,
          durationWeeks: 1,
          sessionsPerWeek: 1,
        ),
      );
    }

    return version;
  }

  Future<void> _tryUpsertLineageRecord() async {
    try {
      await SupabaseService.client.from('programme_lineages').upsert(
        {
          'id': FounderAcceptanceDevFixtures.lineageId,
          'code': FounderAcceptanceContent.programmeLineageCode,
          'created_by': _authoringCoachId,
        },
        onConflict: 'code',
      );
    } catch (error) {
      debugPrint(
        '[FounderAcceptanceInstall] lineage upsert skipped: $error',
      );
    }
  }

  Future<void> _tryUpsertVersionRecord(String lineageId) async {
    try {
      final version = ProgrammeVersion(
        id: FounderAcceptanceDevFixtures.versionId,
        lineageId: lineageId,
        versionNumber: 1,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
        name: FounderAcceptanceContent.programmeName,
        description: FounderAcceptanceContent.programmeDescription,
        durationWeeks: 1,
        sessionsPerWeek: 1,
        createdBy: _authoringCoachId,
      );

      await SupabaseService.client.from('programme_versions').upsert(
        version.toInsertMap(),
        onConflict: 'lineage_id,version_number',
      );
    } catch (error) {
      debugPrint(
        '[FounderAcceptanceInstall] version upsert skipped: $error',
      );
    }
  }

  ProgrammeTemplateTree _buildTemplateTree(ProgrammeVersion version) {
    const weekId = FounderAcceptanceDevFixtures.weekId;
    const dayId = FounderAcceptanceDevFixtures.dayId;
    const slotId = FounderAcceptanceDevFixtures.slotId;

    final week = ProgrammeVersionWeek(
      id: weekId,
      versionId: version.id,
      weekNumber: 1,
      title: 'Week 1',
    );
    final day = ProgrammeVersionDay(
      id: dayId,
      weekId: weekId,
      dayKey: 'day_1',
      dayOrder: 1,
      title: 'Founder Acceptance',
    );
    final slot = ProgrammeVersionSessionSlot(
      id: slotId,
      dayId: dayId,
      sessionOrder: 1,
      protocolId: FounderAcceptanceContent.protocolId,
      displayTitle: FounderAcceptanceContent.sessionTitle,
    );

    return ProgrammeTemplateTree(
      template: ProgrammeTemplate(version: version, weeks: [week]),
      weekNodes: [
        ProgrammeTemplateWeekNode(
          week: week,
          days: [
            ProgrammeTemplateDayNode(day: day, slots: [slot]),
          ],
        ),
      ],
    );
  }

  static String _buildSummary({
    required bool programmeCreated,
    required bool programmeUpdated,
    required bool sessionCreated,
    required bool sessionUpdated,
    required int blockCount,
  }) {
    final programmeAction = programmeCreated ? 'created' : 'updated';
    final sessionAction = sessionCreated
        ? 'created'
        : sessionUpdated
            ? 'updated'
            : 'verified';
    return 'Programme $programmeAction · Session $sessionAction · '
        '$blockCount blocks installed · Ready for assignment';
  }
}
