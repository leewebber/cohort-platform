import '../../../core/persistence/athlete_local_repository.dart';
import '../../../core/persistence/session_execution_plan_codec.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../models/programme_assignment.dart';
import '../../adaptation/models/accepted_adaptation_decision.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../session/models/prepared_execution_package.dart';
import '../../session/services/session_execution_loader.dart';
import '../../workout_player/models/workout_session_brief.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../../../planning/models/planning_goal_context.dart';
import '../../../planning/models/planning_input.dart';
import '../../../planning/orchestration/models/planning_context.dart';
import '../../../knowledge/gap_analysis/capability_evidence_models.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/athlete_programme_prepared_session.dart';
import '../models/programme_execution_context.dart';
import 'athlete_programme_authored_slot_resolver.dart';

/// Sprint 1.4B: materialised assignment → deterministic PreparedExecutionPackage.
///
/// Uses authored-bank [SessionExecutionLoader] only. Does not invoke Coach Brain,
/// advance the cursor, or create completions.
class AthleteProgrammeSessionPrepareService {
  AthleteProgrammeSessionPrepareService({
    required ProgrammeAssignmentStore assignmentStore,
    required AthleteProgrammeAuthoredSlotResolver slotResolver,
    required SessionExecutionLoader sessionLoader,
    AthleteLocalRepository? localRepository,
  }) : _assignmentStore = assignmentStore,
       _slotResolver = slotResolver,
       _sessionLoader = sessionLoader,
       _localRepository = localRepository;

  final ProgrammeAssignmentStore _assignmentStore;
  final AthleteProgrammeAuthoredSlotResolver _slotResolver;
  final SessionExecutionLoader _sessionLoader;
  final AthleteLocalRepository? _localRepository;

  /// In-process idempotency cache keyed by programmed session key value.
  final Map<String, PreparedExecutionPackage> _memoryCache = {};

  Future<AthleteProgrammePrepareResult> prepareForAthlete(
    String athleteId, {
    bool allowReconstruct = true,
  }) async {
    final trimmed = athleteId.trim();
    if (trimmed.isEmpty) {
      return const AthleteProgrammePrepareResult(
        status: AthleteProgrammePrepareStatus.failure,
        code: 'invalid_athlete',
        message: 'Athlete id is required.',
      );
    }

    final assignment = await _assignmentStore.getActiveAssignment(trimmed);
    if (assignment == null) {
      return const AthleteProgrammePrepareResult(
        status: AthleteProgrammePrepareStatus.notMaterialised,
        code: 'no_active_assignment',
        message: 'No active programme assignment.',
      );
    }
    return prepareForAssignment(assignment, allowReconstruct: allowReconstruct);
  }

  Future<AthleteProgrammePrepareResult> prepareForAssignment(
    ProgrammeAssignment assignment, {
    bool allowReconstruct = true,
  }) async {
    if (!assignment.isActive) {
      return const AthleteProgrammePrepareResult(
        status: AthleteProgrammePrepareStatus.inactive,
        code: 'inactive_assignment',
        message: 'Programme assignment is not active.',
      );
    }
    if (!assignment.isMaterialised) {
      return const AthleteProgrammePrepareResult(
        status: AthleteProgrammePrepareStatus.notMaterialised,
        code: 'enrolled_only',
        message: 'Programme is enrolled but not started.',
      );
    }

    try {
      final resolved = await _slotResolver.resolve(assignment);
      final key = resolved.programmedSessionKey;

      final cached = _memoryCache[key.value];
      if (cached != null && _packageMatchesAuthority(cached, resolved)) {
        return AthleteProgrammePrepareResult(
          status: AthleteProgrammePrepareStatus.restored,
          package: cached,
          executionContext: resolved.executionContext,
          programmedSessionKey: key,
        );
      }

      final local = await _readLocal(assignment.athleteId);
      if (local != null) {
        final restored = _packageFromRecord(local);
        if (restored != null &&
            _recordMatchesAuthority(local, resolved) &&
            restored.plan.hasExecutableBlocks) {
          _memoryCache[key.value] = restored;
          return AthleteProgrammePrepareResult(
            status: AthleteProgrammePrepareStatus.restored,
            package: restored,
            executionContext: resolved.executionContext,
            programmedSessionKey: key,
          );
        }
        if (!allowReconstruct) {
          return const AthleteProgrammePrepareResult(
            status: AthleteProgrammePrepareStatus.failure,
            code: 'restore_rejected',
            message: 'Stored preparation provenance is invalid.',
          );
        }
      }

      final loaded = await _sessionLoader.load(
        protocolId: resolved.executionContext.effectiveProtocolId,
        displayTitle: resolved.slot.displayTitle ?? resolved.version.name,
        programmeContextLabel: resolved.version.name,
      );
      if (!loaded.plan.hasExecutableBlocks) {
        return const AthleteProgrammePrepareResult(
          status: AthleteProgrammePrepareStatus.unresolvableSlot,
          code: 'empty_execution_plan',
          message: 'Authored session could not be compiled.',
        );
      }

      final brief = WorkoutSessionBrief(
        sessionName: loaded.plan.sessionTitle,
        objective: resolved.slot.displayTitle,
        estimatedDurationMinutes: loaded.plan.durationMin,
        coachNotes: loaded.plan.coachNotes,
      );
      final preparedAt = DateTime.now().toUtc();
      final package = PreparedExecutionPackage(
        programmedSessionKey: key,
        plan: loaded.plan,
        brief: brief,
        preparedAt: preparedAt,
        planId: assignment.lineageCode,
        planVersion: assignment.programmeVersionId,
        assignmentId: assignment.id,
        programmeVersionId: assignment.programmeVersionId,
        packageContentHash: assignment.materialisedPackageContentHash,
        dayKey: assignment.currentDayKey,
        slotOrder: assignment.currentSessionOrder,
        protocolId: resolved.executionContext.effectiveProtocolId,
        coachBrainPlan: null,
      );

      _memoryCache[key.value] = package;
      await _persist(assignment.athleteId, package, resolved.executionContext);

      final hadInvalidLocal = local != null;
      return AthleteProgrammePrepareResult(
        status: hadInvalidLocal
            ? AthleteProgrammePrepareStatus.reconstructed
            : AthleteProgrammePrepareStatus.prepared,
        package: package,
        executionContext: resolved.executionContext,
        programmedSessionKey: key,
      );
    } on ProgrammeScheduleException catch (error) {
      return AthleteProgrammePrepareResult(
        status: _statusForScheduleError(error.code),
        code: error.code.name,
        message: error.message,
      );
    } catch (error) {
      return AthleteProgrammePrepareResult(
        status: AthleteProgrammePrepareStatus.failure,
        code: 'prepare_failed',
        message: error.toString(),
      );
    }
  }

  /// Wraps a prepared package for Workout Overview without Coach Brain resolve.
  CoachBrainWorkoutPlan toOpenablePlan(PreparedExecutionPackage package) {
    final stamp = package.preparedAt;
    final input = PlanningInput(
      athleteId: '',
      goalContext: const PlanningGoalContext(
        goalId: 'programme.authored',
        goalLabel: 'Programme session',
      ),
      capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
      knowledgeOntologyVersion: 'programme.authored.v1',
      asOf: stamp,
    );
    final context = PlanningContext(
      orchestrationId:
          'programme.${package.assignmentId}.${stamp.millisecondsSinceEpoch}',
      startedAt: stamp,
      completedAt: stamp,
      orchestrationStatus: OrchestrationStatus.complete,
      input: input,
      sessionExecutionPlan: package.plan,
      diagnostics: const PipelineDiagnostics(outcome: PipelineOutcome.success),
    );
    return CoachBrainWorkoutPlan(
      planningContext: context,
      plan: package.plan,
      brief: package.brief,
    );
  }

  AthleteProgrammePrepareStatus _statusForScheduleError(
    ProgrammeScheduleErrorCode code,
  ) {
    return switch (code) {
      ProgrammeScheduleErrorCode.assignmentNotMaterialised =>
        AthleteProgrammePrepareStatus.notMaterialised,
      ProgrammeScheduleErrorCode.assignmentNotActive =>
        AthleteProgrammePrepareStatus.inactive,
      ProgrammeScheduleErrorCode.missingProgrammeVersion =>
        AthleteProgrammePrepareStatus.versionMismatch,
      ProgrammeScheduleErrorCode.packageHashMismatch =>
        AthleteProgrammePrepareStatus.hashMismatch,
      ProgrammeScheduleErrorCode.missingCurrentWeek ||
      ProgrammeScheduleErrorCode.missingCurrentDay ||
      ProgrammeScheduleErrorCode.missingCurrentSlot ||
      ProgrammeScheduleErrorCode.malformedAssignmentCursor =>
        AthleteProgrammePrepareStatus.invalidCursor,
      ProgrammeScheduleErrorCode.unresolvableAuthoredSlot ||
      ProgrammeScheduleErrorCode.emptyProgrammeStructure =>
        AthleteProgrammePrepareStatus.unresolvableSlot,
      _ => AthleteProgrammePrepareStatus.failure,
    };
  }

  bool _packageMatchesAuthority(
    PreparedExecutionPackage package,
    AuthoredProgrammeSlotResolution resolved,
  ) {
    return package.assignmentId == resolved.assignment.id &&
        package.programmeVersionId == resolved.assignment.programmeVersionId &&
        package.packageContentHash ==
            resolved.assignment.materialisedPackageContentHash &&
        package.programmedSessionKey.value ==
            resolved.programmedSessionKey.value &&
        package.dayKey == resolved.assignment.currentDayKey &&
        package.slotOrder == resolved.assignment.currentSessionOrder;
  }

  bool _recordMatchesAuthority(
    GeneratedSessionRecord record,
    AuthoredProgrammeSlotResolution resolved,
  ) {
    if (record.athleteId != resolved.assignment.athleteId) return false;
    if (record.assignmentId != resolved.assignment.id) return false;
    if (record.programmeVersionId != resolved.assignment.programmeVersionId) {
      return false;
    }
    if (record.packageContentHash !=
        resolved.assignment.materialisedPackageContentHash) {
      return false;
    }
    if (record.programmedSessionKey != resolved.programmedSessionKey.value) {
      return false;
    }
    if (record.dayKey != resolved.assignment.currentDayKey) return false;
    if (record.slotOrder != resolved.assignment.currentSessionOrder) {
      return false;
    }
    return true;
  }

  PreparedExecutionPackage? _packageFromRecord(GeneratedSessionRecord record) {
    try {
      final keyRaw = record.programmedSessionKey;
      if (keyRaw == null || keyRaw.isEmpty) return null;
      final key = ProgrammedSessionKey.parse(keyRaw);
      return PreparedExecutionPackage(
        programmedSessionKey: ProgrammedSessionKey(
          planId: record.planId ?? key.planId,
          planVersion: key.planVersion,
          week: key.week,
          day: key.day,
          dayKey: record.dayKey ?? key.dayKey,
          slotOrder: record.slotOrder ?? key.slotOrder,
          protocolId: record.protocolId ?? key.protocolId,
          programmeAssignmentId:
              record.assignmentId ?? key.programmeAssignmentId,
          packageContentHash:
              record.packageContentHash ?? key.packageContentHash,
          scheduleDate: key.scheduleDate,
        ),
        plan: record.plan,
        brief: record.brief,
        preparedAt: record.generatedAt,
        planId: record.planId,
        planVersion: record.planVersion,
        assignmentId: record.assignmentId,
        programmeVersionId: record.programmeVersionId,
        packageContentHash: record.packageContentHash,
        dayKey: record.dayKey,
        slotOrder: record.slotOrder,
        protocolId: record.protocolId,
        acceptedAdaptation: record.acceptedAdaptation == null
            ? null
            : AcceptedAdaptationDecision.fromPersistenceMap(
                record.acceptedAdaptation!,
              ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<GeneratedSessionRecord?> _readLocal(String athleteId) async {
    final repo = _localRepository;
    if (repo == null) return null;
    try {
      return await repo.readGeneratedSession(athleteId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(
    String athleteId,
    PreparedExecutionPackage package,
    ProgrammeExecutionContext context,
  ) async {
    final repo = _localRepository;
    if (repo == null) return;
    final record = GeneratedSessionRecord(
      athleteId: athleteId,
      intendedTrainingDate:
          package.programmedSessionKey.scheduleDate ?? package.preparedAt,
      generatedAt: package.preparedAt,
      plan: package.plan,
      brief: package.brief,
      planId: package.planId,
      assignmentId: package.assignmentId,
      programmeName: context.programmeName,
      programmedSessionKey: package.programmedSessionKey.value,
      planVersion: package.planVersion,
      week: package.programmedSessionKey.week,
      day: package.programmedSessionKey.day,
      programmeVersionId: package.programmeVersionId,
      packageContentHash: package.packageContentHash,
      dayKey: package.dayKey,
      slotOrder: package.slotOrder,
      protocolId: package.protocolId,
      phaseLabel: 'Programme',
      ontologyVersion: 'programme.authored.v1',
      acceptedAdaptation: package.acceptedAdaptation?.toPersistenceMap(),
    );
    await repo.saveGeneratedSession(record);
  }

  /// Atomically replaces the current prepared package in memory + local store.
  ///
  /// Used by Sprint 1.6C acceptance and Sprint 1.6D reversion. Does not change
  /// assignment cursor.
  Future<void> replacePreparedPackage({
    required String athleteId,
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext executionContext,
  }) async {
    final trimmed = athleteId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(athleteId, 'athleteId', 'Required');
    }
    // Persist first so a store failure leaves the previous prepared state as
    // the authoritative in-memory package for the caller.
    await _persist(trimmed, package, executionContext);
    _memoryCache[package.programmedSessionKey.value] = package;
  }

  /// Deterministic authored executable plan for [package] via the bank/compiler
  /// path. Does not mutate cache or local persistence.
  ///
  /// Sprint 1.6D reversion authority — not adaptation planning.
  Future<SessionExecutionLoadResult?> loadAuthoredExecutablePlan(
    PreparedExecutionPackage package, {
    String? programmeContextLabel,
  }) async {
    final protocolId = package.protocolId?.trim();
    if (protocolId == null || protocolId.isEmpty) return null;
    final loaded = await _sessionLoader.load(
      protocolId: protocolId,
      displayTitle: package.brief.sessionName,
      programmeContextLabel: programmeContextLabel,
    );
    if (!loaded.plan.hasExecutableBlocks) return null;
    return loaded;
  }

  /// Returns the in-memory prepared package for [programmedSessionKey], if any.
  PreparedExecutionPackage? cachedPackageForKey(String programmedSessionKey) {
    return _memoryCache[programmedSessionKey];
  }

  /// Clears local prepared execution for keys affected by a schedule Move/Swap.
  ///
  /// Prepared state is athlete-local only. Called after successful authoritative
  /// apply using keys returned by the RPC. Does not regenerate prepare, invoke
  /// adaptation, or revive consumed proposal IDs.
  Future<void> clearPreparedForProgrammedSessionKeys({
    required String athleteId,
    required Iterable<String> programmedSessionKeys,
  }) async {
    final trimmedAthlete = athleteId.trim();
    if (trimmedAthlete.isEmpty) return;
    final keys = programmedSessionKeys
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet();
    if (keys.isEmpty) return;

    for (final key in keys) {
      _memoryCache.remove(key);
    }

    final repo = _localRepository;
    if (repo == null) return;
    final local = await _readLocal(trimmedAthlete);
    if (local == null) return;
    final localKey = local.programmedSessionKey?.trim() ?? '';
    if (localKey.isNotEmpty && keys.contains(localKey)) {
      await repo.clearGeneratedSession(trimmedAthlete);
    }
  }
}
