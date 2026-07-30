import 'package:flutter/foundation.dart';

import '../../features/adaptive_progression/models/capability_timeline.dart';
import '../../features/adaptive_progression/models/session_completion.dart';
import '../../features/athlete_profile/services/athlete_profile_session.dart';
import '../../features/athlete_profile/services/athlete_programme_generation_service.dart';
import '../../features/plans/data/plan_catalog.dart';
import '../../features/plans/models/plan_assignment.dart';
import '../../features/plans/models/plan_definition.dart';
import '../../features/plans/models/programmed_session_key.dart';
import '../../features/plans/services/plan_assignment_service.dart';
import '../../features/workout_player/models/previous_performance_snapshot.dart';
import 'athlete_local_repository.dart';
import 'models/execution_result_models.dart';
import 'restored_session_factory.dart';
import 'session_execution_plan_codec.dart';

/// Outcome of athlete-state hydration.
enum AthleteHydrationStatus {
  empty,
  restored,
  planDefinitionMissing,
  partialCorruption,
}

class AthleteHydrationResult {
  const AthleteHydrationResult({
    required this.status,
    this.athleteId,
    this.planDefinitionMissing = false,
    this.pendingWorkoutProgress,
    this.reconstructedSession = false,
  });

  final AthleteHydrationStatus status;
  final String? athleteId;
  final bool planDefinitionMissing;
  final WorkoutProgressSnapshot? pendingWorkoutProgress;

  /// True when prepared execution was reconstructed from the programmed session.
  final bool reconstructedSession;

  /// Compatibility alias for Sprint 3 tests.
  bool get regeneratedSession => reconstructedSession;

  bool get hasAthleteMemory =>
      status == AthleteHydrationStatus.restored ||
      status == AthleteHydrationStatus.planDefinitionMissing ||
      status == AthleteHydrationStatus.partialCorruption;
}

/// Single hydration sequence for local athlete memory.
///
/// UI must not load persistence directly — call [hydrate] once at bootstrap.
class AthleteStateHydrator {
  AthleteStateHydrator({
    required AthleteLocalRepository repository,
    PlanAssignmentService? assignmentService,
    AthleteProgrammeGenerationService? generationService,
    this.restorePolicy = const GeneratedSessionRestorePolicy(),
    this.sessionFactory = const RestoredSessionFactory(),
  }) : _repository = repository,
       _assignments = assignmentService ?? PlanAssignmentService(),
       _generation = generationService ?? AthleteProgrammeGenerationService();

  final AthleteLocalRepository _repository;
  final PlanAssignmentService _assignments;
  final AthleteProgrammeGenerationService _generation;
  final GeneratedSessionRestorePolicy restorePolicy;
  final RestoredSessionFactory sessionFactory;

  AthleteLocalRepository get repository => _repository;
  PlanAssignmentService get assignmentService => _assignments;

  /// Clears in-memory coaching state then restores from [repository].
  Future<AthleteHydrationResult> hydrate({
    String? preferredAthleteId,
    DateTime? now,
    bool allowRegenerate = true,
    bool allowReconstruct = true,
  }) async {
    final mayReconstruct = allowReconstruct && allowRegenerate;
    _clearMemoryStores();

    final athleteId = preferredAthleteId ??
        await _repository.readLastLocalAthleteId();
    if (athleteId == null || athleteId.isEmpty) {
      return const AthleteHydrationResult(status: AthleteHydrationStatus.empty);
    }

    final profile = await _repository.readProfile(athleteId);
    if (profile == null) {
      return const AthleteHydrationResult(status: AthleteHydrationStatus.empty);
    }

    final assignment = await _repository.readPlanAssignment(athleteId);
    PlanDefinition? plan;
    var planMissing = false;
    ProgrammedSessionKey? expectedKey;
    if (assignment != null && assignment.isActive) {
      plan = PlanCatalog.byId(assignment.planId);
      if (plan == null) {
        planMissing = true;
        debugPrint(
          '[AthleteStateHydrator] PlanDefinition unavailable for '
          'planId=${assignment.planId} — not substituting.',
        );
      } else {
        expectedKey = ProgrammedSessionKey.fromPlan(
          plan: plan,
          assignment: assignment,
        );
        _assignments.restoreActive(
          assignment: assignment,
          plan: plan,
        );
      }
    }

    final completions = await _repository.readCompletions(athleteId);
    SessionCompletionStore.replaceAll(completions);

    final timeline = await _repository.readCapabilityTimeline(athleteId);
    CapabilityTimelineStore.replaceAll(timeline);

    final previous = await _repository.readPreviousPerformance(athleteId);
    PreviousPerformanceStore.replaceAll(previous);

    final generated = await _repository.readGeneratedSession(athleteId);
    final shouldRestore = !planMissing &&
        restorePolicy.shouldRestore(
          record: generated,
          activePlanId: assignment?.planId,
          activeAssignmentId: assignment?.assignmentId,
          expectedProgrammedSessionKey: expectedKey?.value,
          now: now,
        );

    AthleteGeneratedProgramme? programme;
    var reconstructed = false;
    if (shouldRestore && generated != null) {
      programme = sessionFactory.toProgramme(
        record: generated,
        profile: profile,
      );
    } else if (mayReconstruct &&
        !planMissing &&
        plan != null &&
        assignment != null &&
        assignment.isActive) {
      try {
        // Reconstruct from the same programmed session key (plan-canonical).
        programme = await _generation.prepareExecution(
          profile,
          activePlan: plan,
          assignment: assignment,
        );
        reconstructed = true;
        await persistGeneratedSession(
          athleteId: athleteId,
          planId: plan.planId,
          assignment: assignment,
          programme: programme,
          now: now,
        );
      } catch (e, st) {
        debugPrint('[AthleteStateHydrator] reconstruct failed: $e');
        debugPrint('$st');
      }
    }

    // Bind even when plan definition is missing so profile/history remain.
    AthleteProfileSession.bind(
      profile: profile,
      programme: programme,
      activePlan: planMissing ? null : plan,
      assignment: planMissing ? null : assignment,
    );

    final progress = await _repository.readWorkoutProgress(athleteId);

    return AthleteHydrationResult(
      status: planMissing
          ? AthleteHydrationStatus.planDefinitionMissing
          : AthleteHydrationStatus.restored,
      athleteId: athleteId,
      planDefinitionMissing: planMissing,
      pendingWorkoutProgress: progress,
      reconstructedSession: reconstructed,
    );
  }

  /// Persists the full bound athlete session after mutation.
  Future<void> persistBoundSession({DateTime? now}) async {
    final profile = AthleteProfileSession.profile;
    if (profile == null) return;
    final athleteId = profile.athleteId;
    await _repository.saveProfile(profile);

    final assignment = AthleteProfileSession.activeAssignment;
    if (assignment != null) {
      await _repository.savePlanAssignment(assignment);
      _assignments.restoreActive(
        assignment: assignment,
        plan: AthleteProfileSession.activePlan ??
            PlanCatalog.byId(assignment.planId),
      );
    } else {
      await _repository.clearPlanAssignment(athleteId);
    }

    final programme = AthleteProfileSession.programme;
    final plan = AthleteProfileSession.activePlan;
    if (programme != null) {
      await persistGeneratedSession(
        athleteId: athleteId,
        planId: plan?.planId,
        assignment: assignment,
        programme: programme,
        now: now,
      );
    }

    await _repository.saveCompletions(athleteId, SessionCompletionStore.all);
    await _repository.saveCapabilityTimeline(
      athleteId,
      CapabilityTimelineStore.all,
    );
    await _repository.savePreviousPerformance(
      athleteId,
      PreviousPerformanceStore.all,
    );
  }

  Future<void> persistGeneratedSession({
    required String athleteId,
    required AthleteGeneratedProgramme programme,
    String? planId,
    PlanAssignment? assignment,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now().toUtc();
    final localDay = (now ?? DateTime.now()).toLocal();
    final intended = DateTime(localDay.year, localDay.month, localDay.day);
    final key = programme.programmedSessionKey;
    final record = GeneratedSessionRecord(
      athleteId: athleteId,
      planId: planId ?? assignment?.planId,
      assignmentId: assignment?.assignmentId,
      intendedTrainingDate: intended,
      generatedAt: stamp,
      plan: programme.planBundle.plan,
      brief: programme.planBundle.brief,
      orchestrationId:
          programme.planBundle.planningContext.orchestrationId,
      ontologyVersion: programme
          .planBundle.planningContext.input.knowledgeOntologyVersion,
      phaseLabel: programme.phaseLabel,
      programmeName: programme.programmeName,
      programmedSessionKey: key?.value,
      planVersion: key?.planVersion,
      week: key?.week ?? assignment?.currentWeek,
      day: key?.day ?? assignment?.currentDay,
      acceptedAdaptation:
          programme.acceptedAdaptation?.toPersistenceMap(),
    );
    await _repository.saveGeneratedSession(record);
  }

  Future<void> persistCompletions(String athleteId) async {
    await _repository.saveCompletions(athleteId, SessionCompletionStore.all);
  }

  Future<void> persistTimeline(String athleteId) async {
    await _repository.saveCapabilityTimeline(
      athleteId,
      CapabilityTimelineStore.all,
    );
  }

  Future<void> persistPreviousPerformance(String athleteId) async {
    await _repository.savePreviousPerformance(
      athleteId,
      PreviousPerformanceStore.all,
    );
  }

  Future<void> persistExerciseResults(
    String athleteId,
    List<ExerciseExecutionResult> results,
  ) async {
    final existing = await _repository.readExerciseResults(athleteId);
    final byId = <String, ExerciseExecutionResult>{
      for (final r in existing) r.resultId: r,
      for (final r in results) r.resultId: r,
    };
    await _repository.saveExerciseResults(athleteId, byId.values.toList());
  }

  Future<void> saveWorkoutProgress(WorkoutProgressSnapshot snapshot) =>
      _repository.saveWorkoutProgress(snapshot);

  Future<void> discardWorkoutProgress(String athleteId) =>
      _repository.clearWorkoutProgress(athleteId);

  /// Sign-out policy B: clear local aggregates + memory.
  Future<void> clearForSignOut({String? athleteId}) async {
    final id = athleteId ??
        AthleteProfileSession.profile?.athleteId ??
        await _repository.readLastLocalAthleteId();
    if (id != null && id.isNotEmpty) {
      await _repository.clearAthlete(id);
    }
    _clearMemoryStores();
    _assignments.resetForTests();
  }

  void _clearMemoryStores() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
    CapabilityTimelineStore.clear();
    PreviousPerformanceStore.clear();
  }
}
