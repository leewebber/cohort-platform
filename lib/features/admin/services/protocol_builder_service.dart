import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/protocol_step_repository.dart';
import '../../../data/repositories/session_block_repository.dart';
import '../../../models/protocol_builder_save_result.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_draft_summary.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/session_block.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../session_builder/services/protocol_draft_block_resolver.dart';
import '../../session_builder/services/session_block_validation.dart';

/// Thrown when a draft fails validation or cannot be saved.
class ProtocolBuilderException implements Exception {
  const ProtocolBuilderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persists coach-authored [ProtocolDraft] rows to Supabase.
///
/// ## Transaction limitation
/// The Supabase Flutter client does not expose multi-table transactions here.
/// Saves run as: upsert protocol → delete existing steps → insert draft steps.
/// If step insertion fails after deletion, the protocol may temporarily have no
/// steps until the coach saves again.
class ProtocolBuilderService {
  ProtocolBuilderService({
    ProtocolRepository? protocolRepository,
    ProtocolStepRepository? protocolStepRepository,
    SessionBlockRepository? sessionBlockRepository,
    ProtocolDraftBlockResolver? blockResolver,
    SessionBlockValidation? blockValidation,
  })  : _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _protocolStepRepository =
            protocolStepRepository ?? const ProtocolStepRepository(),
        _sessionBlockRepository =
            sessionBlockRepository ?? const SessionBlockRepository(),
        _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver(),
        _blockValidation = blockValidation ?? const SessionBlockValidation();

  final ProtocolRepository _protocolRepository;
  final ProtocolStepRepository _protocolStepRepository;
  final SessionBlockRepository _sessionBlockRepository;
  final ProtocolDraftBlockResolver _blockResolver;
  final SessionBlockValidation _blockValidation;

  static const _sessionFormatToSessionType = {
    'circuit': 'Circuit',
    'structured_strength': 'Strength',
    'intervals': 'Running',
    'recovery_flow': 'Recovery',
  };

  static const _sessionTypeToSessionFormat = {
    'circuit': 'circuit',
    'strength': 'structured_strength',
    'running': 'intervals',
    'intervals': 'intervals',
    'recovery': 'recovery_flow',
  };

  Future<List<ProtocolDraftSummary>> getPublishedProtocols() async {
    try {
      final response = await SupabaseService.client
          .from('performance_protocols')
          .select('protocol_id, name, session_type, duration_min')
          .eq('published', true)
          .order('name');

      return response
          .map<ProtocolDraftSummary>(
            (row) => ProtocolDraftSummary.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw ProtocolBuilderException(_friendlyDatabaseMessage(error));
    } catch (error) {
      throw ProtocolBuilderException(
        'We could not load published protocols right now. Please try again.',
      );
    }
  }

  Future<List<ProtocolDraftSummary>> getDraftProtocols() async {
    try {
      final response = await SupabaseService.client
          .from('performance_protocols')
          .select('protocol_id, name, session_type, duration_min')
          .eq('published', false)
          .order('name');

      return response
          .map<ProtocolDraftSummary>(
            (row) => ProtocolDraftSummary.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      throw ProtocolBuilderException(_friendlyDatabaseMessage(error));
    } catch (error) {
      throw ProtocolBuilderException(
        'We could not load draft protocols right now. Please try again.',
      );
    }
  }

  Future<ProtocolDraft> loadProtocol(String protocolId) async {
    final trimmedId = protocolId.trim();
    if (trimmedId.isEmpty) {
      throw const ProtocolBuilderException('Protocol ID is required.');
    }

    try {
      final protocolRow = await SupabaseService.client
          .from('performance_protocols')
          .select()
          .eq('protocol_id', trimmedId)
          .maybeSingle();

      if (protocolRow == null) {
        throw ProtocolBuilderException(
          'Protocol $trimmedId could not be found.',
        );
      }

      final steps = await _protocolStepRepository.getProtocolSteps(trimmedId);
      final blocks = await _sessionBlockRepository.getSessionBlocks(trimmedId);

      final draft = _draftFromProtocolRow(
        Map<String, dynamic>.from(protocolRow),
        steps
            .map(ProtocolStepDraft.fromProtocolStep)
            .toList(growable: false),
        blocks: blocks,
      );

      return _blockResolver.withResolvedBlocks(draft);

      if (kDebugMode) {
        debugPrint(
          '[ProtocolBuilderService] loaded contentKind=${draft.contentKind.dbValue} '
          'scope=${draft.authoringScope.dbValue} '
          'endorsement=${draft.endorsementStatus.dbValue}',
        );
      }

      return draft;
    } on ProtocolBuilderException {
      rethrow;
    } on PostgrestException catch (error) {
      throw ProtocolBuilderException(_friendlyDatabaseMessage(error));
    } catch (error) {
      throw ProtocolBuilderException(
        'We could not open this protocol right now. Please try again.',
      );
    }
  }

  /// Loads a draft or published protocol. Prefer [loadProtocol].
  Future<ProtocolDraft> loadDraft(String protocolId) {
    return loadProtocol(protocolId);
  }

  /// Loads a published official Cohort Protocol eligible for coach copy (M5).
  Future<ProtocolDraft> loadCohortProtocolForCopy(String protocolId) async {
    final draft = await loadProtocol(protocolId);
    if (draft.contentKind != TrainingContentKind.cohortProtocol ||
        draft.authoringScope != TrainingAuthoringScope.cohortGlobal ||
        draft.endorsementStatus != TrainingEndorsementStatus.cohortEndorsed ||
        !draft.published) {
      throw ProtocolBuilderException(
        'Only published official Cohort Protocols can be copied.',
      );
    }
    return draft;
  }

  Future<ProtocolBuilderSaveResult> saveDraft(ProtocolDraft draft) {
    return _persistDraft(draft, published: false);
  }

  /// Persists a reusable coach Session available in Session Library.
  ///
  /// `published=true` means library-available for the owning coach — not
  /// Cohort endorsement or athlete catalogue publication.
  Future<ProtocolBuilderSaveResult> saveCoachLibrarySession(
    ProtocolDraft draft,
  ) {
    return _persistDraft(draft, published: true);
  }

  Future<ProtocolBuilderSaveResult> savePublishedChanges(ProtocolDraft draft) {
    return _persistDraft(
      draft,
      published: true,
      resultKind: _PersistResultKind.savedChanges,
    );
  }

  Future<ProtocolBuilderSaveResult> unpublishDraft(ProtocolDraft draft) {
    return _persistDraft(
      draft,
      published: false,
      resultKind: _PersistResultKind.unpublished,
    );
  }

  Future<ProtocolBuilderSaveResult> publishDraft(ProtocolDraft draft) {
    return _persistDraft(
      draft,
      published: true,
      resultKind: _PersistResultKind.published,
    );
  }

  Future<ProtocolBuilderSaveResult> _persistDraft(
    ProtocolDraft draft, {
    required bool published,
    _PersistResultKind resultKind = _PersistResultKind.draft,
  }) async {
    _validateDraft(draft);

    final syncedDraft = _blockResolver.withSyncedStepsFromBlocks(draft);
    final protocolId = syncedDraft.protocolId.trim();
    final existingProtocol =
        await _protocolRepository.getProtocolById(protocolId);
    final created = existingProtocol == null;

    final protocolMap = _buildProtocolUpsertMap(
      syncedDraft,
      published: published,
    );
    final orderedSteps = _orderedSteps(syncedDraft.steps);
    final orderedBlocks = _orderedBlocks(_blockResolver.resolveBlocks(syncedDraft));
    final stepMaps = orderedSteps
        .map((step) {
          final map = step.toStepMap(protocolId: protocolId);
          map.remove('id');
          return map;
        })
        .toList();

    try {
      await SupabaseService.client
          .from('performance_protocols')
          .upsert(
            protocolMap,
            onConflict: 'protocol_id',
          );

      await SupabaseService.client
          .from('protocol_steps')
          .delete()
          .eq('protocol_id', protocolId);

      if (stepMaps.isNotEmpty) {
        await SupabaseService.client.from('protocol_steps').insert(stepMaps);
      }

      await _sessionBlockRepository.replaceSessionBlocks(
        sessionId: protocolId,
        blocks: orderedBlocks,
      );
    } on PostgrestException catch (error) {
      throw ProtocolBuilderException(_friendlyDatabaseMessage(error));
    } catch (error) {
      throw ProtocolBuilderException(
        _failureMessageFor(resultKind),
      );
    }

    return _resultFor(
      resultKind: resultKind,
      protocolId: protocolId,
      created: created,
      stepCount: orderedSteps.length,
    );
  }

  String _failureMessageFor(_PersistResultKind resultKind) {
    switch (resultKind) {
      case _PersistResultKind.published:
        return 'We could not publish your protocol right now. Please try again.';
      case _PersistResultKind.savedChanges:
        return 'We could not save your changes right now. Please try again.';
      case _PersistResultKind.unpublished:
        return 'We could not unpublish your protocol right now. Please try again.';
      case _PersistResultKind.draft:
        return 'We could not save your protocol right now. Please try again.';
    }
  }

  ProtocolBuilderSaveResult _resultFor({
    required _PersistResultKind resultKind,
    required String protocolId,
    required bool created,
    required int stepCount,
  }) {
    switch (resultKind) {
      case _PersistResultKind.published:
        return ProtocolBuilderSaveResult.published(
          protocolId: protocolId,
          created: created,
          stepCount: stepCount,
        );
      case _PersistResultKind.savedChanges:
        return ProtocolBuilderSaveResult.savedChanges(
          protocolId: protocolId,
          stepCount: stepCount,
        );
      case _PersistResultKind.unpublished:
        return ProtocolBuilderSaveResult.unpublished(
          protocolId: protocolId,
          stepCount: stepCount,
        );
      case _PersistResultKind.draft:
        return ProtocolBuilderSaveResult.draft(
          protocolId: protocolId,
          created: created,
          stepCount: stepCount,
        );
    }
  }

  void _validateDraft(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.protocolId.trim().isEmpty) {
      messages.add('Protocol ID is required.');
    }

    if (draft.name.trim().isEmpty) {
      messages.add('Protocol name is required.');
    }

    if (draft.sessionFormat == null || draft.sessionFormat!.trim().isEmpty) {
      messages.add('Session format is required.');
    }

    final blocks = _blockResolver.resolveBlocks(draft);
    messages.addAll(
      _blockValidation.validateSession(
        name: draft.name,
        blocks: blocks,
      ),
    );

    if (messages.isNotEmpty) {
      throw ProtocolBuilderException(messages.join(' '));
    }
  }

  List<SessionBlock> _orderedBlocks(List<SessionBlock> blocks) {
    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));
    return ordered;
  }

  List<ProtocolStepDraft> _orderedSteps(List<ProtocolStepDraft> steps) {
    final ordered = List<ProtocolStepDraft>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return ordered;
  }

  Map<String, dynamic> _buildProtocolUpsertMap(
    ProtocolDraft draft, {
    required bool published,
  }) {
    final map = Map<String, dynamic>.from(draft.toProtocolMap());
    map['published'] = published;
    _applySessionFormatFallback(map, draft.sessionFormat);
    return map;
  }

  ProtocolDraft _draftFromProtocolRow(
    Map<String, dynamic> row,
    List<ProtocolStepDraft> steps, {
    List<SessionBlock> blocks = const [],
  }) {
    final base = ProtocolDraft(
      protocolId: row['protocol_id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      steps: steps,
      blocks: blocks,
      published: row['published'] == true,
      primaryCapability: row['primary_capability']?.toString(),
      secondaryCapability: row['secondary_capability']?.toString(),
      sessionType: row['session_type']?.toString(),
      sessionFormat: _deriveSessionFormat(row['session_type']?.toString()),
      durationMin: _nullableInt(row['duration_min']),
      durationCategory: row['duration_category']?.toString(),
      physiologicalDemand: row['physiological_demand']?.toString(),
      recoveryCost: row['recovery_cost']?.toString(),
      technicalComplexity: row['technical_complexity']?.toString(),
      environment: row['environment']?.toString(),
      requiredEquipment: row['required_equipment']?.toString(),
      optionalEquipment: row['optional_equipment']?.toString(),
      suitableFor: row['suitable_for']?.toString(),
      adaptability: _nullableInt(row['adaptability']),
      runningRequired: _nullableBool(row['running_required']),
      runningReplaceable: _nullableBool(row['running_replaceable']),
      hotelFriendly: _nullableBool(row['hotel_friendly']),
      indoorFriendly: _nullableBool(row['indoor_friendly']),
      noiseFriendly: _nullableBool(row['noise_friendly']),
      coachingNotes: row['coaching_notes']?.toString(),
      purpose: row['purpose']?.toString(),
    );

    return ProtocolDraft.applyTrainingContentMetadata(
      draft: base,
      row: row,
    );
  }

  /// `session_format` is validated in the builder but not yet a DB column.
  /// When `session_type` is empty, map format to a vocabulary session type
  /// so execution routing can resolve after save.
  void _applySessionFormatFallback(
    Map<String, dynamic> map,
    String? sessionFormat,
  ) {
    final currentSessionType = map['session_type']?.toString().trim();
    if (currentSessionType != null && currentSessionType.isNotEmpty) {
      return;
    }

    final mappedType = _sessionFormatToSessionType[sessionFormat?.trim()];
    if (mappedType != null) {
      map['session_type'] = mappedType;
    }
  }

  String? _deriveSessionFormat(String? sessionType) {
    final normalized = sessionType?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return _sessionTypeToSessionFormat[normalized];
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool? _nullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == 't' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'f' || normalized == '0') {
      return false;
    }
    return null;
  }

  String _friendlyDatabaseMessage(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    if (code == '23503' || message.contains('foreign key')) {
      if (message.contains('exercise')) {
        return 'One of the selected exercises could not be found. Check exercise links and try again.';
      }

      return 'A linked record could not be found. Check your entries and try again.';
    }

    if (code == '23505' || message.contains('duplicate key')) {
      return 'A protocol with this ID already exists. Use a different protocol ID or save again to update it.';
    }

    if (code == '42501' || message.contains('permission denied')) {
      return 'You do not have permission to save protocols right now.';
    }

    return 'We could not save your protocol right now. Please try again.';
  }
}

enum _PersistResultKind {
  draft,
  published,
  savedChanges,
  unpublished,
}
