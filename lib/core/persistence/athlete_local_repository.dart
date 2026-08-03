import 'package:flutter/foundation.dart';

import '../../features/adaptive_progression/models/capability_timeline.dart';
import '../../features/adaptive_progression/models/session_completion.dart';
import '../../features/athlete_profile/models/athlete_profile.dart';
import '../../features/plans/models/plan_assignment.dart';
import '../../features/programme/models/programme_schedule_persistence.dart';
import '../../features/workout_player/models/previous_performance_snapshot.dart';
import 'local_kv_store.dart';
import 'models/execution_result_models.dart';
import 'persistence_envelope.dart';
import 'session_execution_plan_codec.dart';

/// Local athlete memory — repository contracts over [LocalKvStore].
///
/// Features depend on this type, not SharedPreferences.
class AthleteLocalRepository {
  AthleteLocalRepository(this._store);

  final LocalKvStore _store;

  // --- Profile ---

  Future<void> saveProfile(AthleteProfile profile) async {
    await _write(
      PersistenceKeys.profile(profile.athleteId),
      PersistenceSchemaVersions.athleteProfile,
      profile.toPersistenceMap(),
    );
    await _store.writeString(
      PersistenceKeys.lastLocalAthleteId,
      profile.athleteId,
    );
  }

  Future<AthleteProfile?> readProfile(String athleteId) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.profile(athleteId),
      expectedVersion: PersistenceSchemaVersions.athleteProfile,
      aggregate: 'athlete_profile',
    );
    if (envelope == null) return null;
    try {
      return AthleteProfile.fromPersistenceMap(envelope.payload);
    } catch (e, st) {
      _logCorrupt('athlete_profile', e, st);
      await _store.remove(PersistenceKeys.profile(athleteId));
      return null;
    }
  }

  // --- Plan assignment ---

  Future<void> savePlanAssignment(PlanAssignment assignment) async {
    await _write(
      PersistenceKeys.planAssignment(assignment.athleteId),
      PersistenceSchemaVersions.planAssignment,
      assignment.toPersistenceMap(),
    );
  }

  Future<PlanAssignment?> readPlanAssignment(String athleteId) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.planAssignment(athleteId),
      expectedVersion: PersistenceSchemaVersions.planAssignment,
      aggregate: 'plan_assignment',
    );
    if (envelope == null) return null;
    try {
      return PlanAssignment.fromPersistenceMap(envelope.payload);
    } catch (e, st) {
      _logCorrupt('plan_assignment', e, st);
      await _store.remove(PersistenceKeys.planAssignment(athleteId));
      return null;
    }
  }

  Future<void> clearPlanAssignment(String athleteId) async {
    await _store.remove(PersistenceKeys.planAssignment(athleteId));
  }

  // --- Generated session ---

  Future<void> saveGeneratedSession(GeneratedSessionRecord record) async {
    await _write(
      PersistenceKeys.generatedSession(record.athleteId),
      PersistenceSchemaVersions.generatedSession,
      record.toPersistenceMap(),
    );
  }

  Future<GeneratedSessionRecord?> readGeneratedSession(String athleteId) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.generatedSession(athleteId),
      expectedVersion: PersistenceSchemaVersions.generatedSession,
      aggregate: 'generated_session',
    );
    if (envelope == null) return null;
    try {
      return GeneratedSessionRecord.fromPersistenceMap(envelope.payload);
    } catch (e, st) {
      _logCorrupt('generated_session', e, st);
      await _store.remove(PersistenceKeys.generatedSession(athleteId));
      return null;
    }
  }

  Future<void> clearGeneratedSession(String athleteId) async {
    await _store.remove(PersistenceKeys.generatedSession(athleteId));
  }

  // --- Completions ---

  Future<void> saveCompletions(
    String athleteId,
    List<SessionCompletion> completions,
  ) async {
    final sorted = [...completions]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    await _write(
      PersistenceKeys.completions(athleteId),
      PersistenceSchemaVersions.sessionCompletions,
      {
        'items': sorted.map((c) => c.toPersistenceMap()).toList(),
      },
    );
  }

  Future<List<SessionCompletion>> readCompletions(String athleteId) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.completions(athleteId),
      expectedVersion: PersistenceSchemaVersions.sessionCompletions,
      aggregate: 'session_completions',
    );
    if (envelope == null) return const [];
    try {
      final items = envelope.payload['items'];
      if (items is! List) return const [];
      final out = <SessionCompletion>[];
      for (final item in items) {
        if (item is Map) {
          out.add(
            SessionCompletion.fromPersistenceMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
      out.sort((a, b) => a.completedAt.compareTo(b.completedAt));
      return out;
    } catch (e, st) {
      _logCorrupt('session_completions', e, st);
      await _store.remove(PersistenceKeys.completions(athleteId));
      return const [];
    }
  }

  // --- Capability timeline ---

  Future<void> saveCapabilityTimeline(
    String athleteId,
    List<CapabilityTimelineEvent> events,
  ) async {
    final byId = <String, CapabilityTimelineEvent>{};
    for (final e in events) {
      if (e.eventId.isEmpty) continue;
      byId[e.eventId] = e;
    }
    final deduped = byId.values.toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    await _write(
      PersistenceKeys.capabilityTimeline(athleteId),
      PersistenceSchemaVersions.capabilityTimeline,
      {
        'items': deduped.map((e) => e.toPersistenceMap()).toList(),
      },
    );
  }

  Future<List<CapabilityTimelineEvent>> readCapabilityTimeline(
    String athleteId,
  ) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.capabilityTimeline(athleteId),
      expectedVersion: PersistenceSchemaVersions.capabilityTimeline,
      aggregate: 'capability_timeline',
    );
    if (envelope == null) return const [];
    try {
      final items = envelope.payload['items'];
      if (items is! List) return const [];
      final byId = <String, CapabilityTimelineEvent>{};
      for (final item in items) {
        if (item is Map) {
          final event = CapabilityTimelineEvent.fromPersistenceMap(
            Map<String, dynamic>.from(item),
          );
          if (event.eventId.isNotEmpty) {
            byId[event.eventId] = event;
          }
        }
      }
      final out = byId.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      return out;
    } catch (e, st) {
      _logCorrupt('capability_timeline', e, st);
      await _store.remove(PersistenceKeys.capabilityTimeline(athleteId));
      return const [];
    }
  }

  // --- Previous performance ---

  Future<void> savePreviousPerformance(
    String athleteId,
    List<PreviousPerformanceSnapshot> snapshots,
  ) async {
    await _write(
      PersistenceKeys.previousPerformance(athleteId),
      PersistenceSchemaVersions.previousPerformance,
      {
        'items': snapshots.map(_encodePrevious).toList(),
      },
    );
  }

  Future<List<PreviousPerformanceSnapshot>> readPreviousPerformance(
    String athleteId,
  ) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.previousPerformance(athleteId),
      expectedVersion: PersistenceSchemaVersions.previousPerformance,
      aggregate: 'previous_performance',
    );
    if (envelope == null) return const [];
    try {
      final items = envelope.payload['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => _decodePrevious(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e, st) {
      _logCorrupt('previous_performance', e, st);
      await _store.remove(PersistenceKeys.previousPerformance(athleteId));
      return const [];
    }
  }

  // --- Exercise results ---

  Future<void> saveExerciseResults(
    String athleteId,
    List<ExerciseExecutionResult> results,
  ) async {
    await _write(
      PersistenceKeys.exerciseResults(athleteId),
      PersistenceSchemaVersions.exerciseResults,
      {
        'items': results.map((r) => r.toPersistenceMap()).toList(),
      },
    );
  }

  Future<List<ExerciseExecutionResult>> readExerciseResults(
    String athleteId,
  ) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.exerciseResults(athleteId),
      expectedVersion: PersistenceSchemaVersions.exerciseResults,
      aggregate: 'exercise_results',
    );
    if (envelope == null) return const [];
    try {
      final items = envelope.payload['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map(
            (e) => ExerciseExecutionResult.fromPersistenceMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } catch (e, st) {
      _logCorrupt('exercise_results', e, st);
      await _store.remove(PersistenceKeys.exerciseResults(athleteId));
      return const [];
    }
  }

  // --- Workout progress ---

  Future<void> saveWorkoutProgress(WorkoutProgressSnapshot snapshot) async {
    await _write(
      PersistenceKeys.workoutProgress(snapshot.athleteId),
      PersistenceSchemaVersions.workoutProgress,
      snapshot.toPersistenceMap(),
    );
  }

  Future<WorkoutProgressSnapshot?> readWorkoutProgress(
    String athleteId,
  ) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.workoutProgress(athleteId),
      expectedVersion: PersistenceSchemaVersions.workoutProgress,
      aggregate: 'workout_progress',
    );
    if (envelope == null) return null;
    try {
      return WorkoutProgressSnapshot.fromPersistenceMap(envelope.payload);
    } catch (e, st) {
      _logCorrupt('workout_progress', e, st);
      await _store.remove(PersistenceKeys.workoutProgress(athleteId));
      return null;
    }
  }

  Future<void> clearWorkoutProgress(String athleteId) async {
    await _store.remove(PersistenceKeys.workoutProgress(athleteId));
  }

  // --- Programme schedule projection (Sprint 1.7C; cache only) ---

  /// Persists server-authoritative projection after successful ensure/load.
  ///
  /// Never call this with a client-invented projection that has not been
  /// returned by the server ensure/load path.
  Future<void> saveProgrammeScheduleProjection({
    required String athleteId,
    required PersistedProgrammeScheduleProjection projection,
  }) async {
    if (projection.athleteId != athleteId) {
      throw ArgumentError(
        'Schedule cache athlete scope mismatch.',
      );
    }
    await _write(
      PersistenceKeys.programmeScheduleProjection(
        athleteId,
        projection.assignmentId,
      ),
      PersistenceSchemaVersions.programmeScheduleProjection,
      Map<String, dynamic>.from(projection.toPersistenceMap()),
    );
  }

  Future<PersistedProgrammeScheduleProjection?> readProgrammeScheduleProjection({
    required String athleteId,
    required String assignmentId,
  }) async {
    final envelope = await _readEnvelope(
      PersistenceKeys.programmeScheduleProjection(athleteId, assignmentId),
      expectedVersion: PersistenceSchemaVersions.programmeScheduleProjection,
      aggregate: 'programme_schedule_projection',
    );
    if (envelope == null) return null;
    try {
      final projection = PersistedProgrammeScheduleProjection.fromMap(
        envelope.payload,
      );
      if (projection.athleteId != athleteId ||
          projection.assignmentId != assignmentId) {
        await _store.remove(
          PersistenceKeys.programmeScheduleProjection(athleteId, assignmentId),
        );
        return null;
      }
      return projection;
    } catch (e, st) {
      _logCorrupt('programme_schedule_projection', e, st);
      await _store.remove(
        PersistenceKeys.programmeScheduleProjection(athleteId, assignmentId),
      );
      return null;
    }
  }

  Future<void> clearProgrammeScheduleProjection({
    required String athleteId,
    required String assignmentId,
  }) async {
    await _store.remove(
      PersistenceKeys.programmeScheduleProjection(athleteId, assignmentId),
    );
  }

  // --- Lifecycle ---

  Future<String?> readLastLocalAthleteId() =>
      _store.readString(PersistenceKeys.lastLocalAthleteId);

  /// Clears all local aggregates for [athleteId] (sign-out policy B).
  Future<void> clearAthlete(String athleteId) async {
    await _store.clearPrefix(PersistenceKeys.athleteRoot(athleteId));
    final last = await readLastLocalAthleteId();
    if (last == athleteId) {
      await _store.remove(PersistenceKeys.lastLocalAthleteId);
    }
  }

  Future<void> _write(
    String key,
    int schemaVersion,
    Map<String, dynamic> payload,
  ) async {
    final envelope = PersistenceEnvelope(
      schemaVersion: schemaVersion,
      savedAt: DateTime.now().toUtc(),
      payload: payload,
    );
    await _store.writeString(key, envelope.encode());
  }

  Future<PersistenceEnvelope?> _readEnvelope(
    String key, {
    required int expectedVersion,
    required String aggregate,
  }) async {
    final raw = await _store.readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PersistenceEnvelope.decode(
        raw,
        expectedVersion: expectedVersion,
        aggregate: aggregate,
      );
    } on PersistenceSchemaException catch (e, st) {
      _logCorrupt(aggregate, e, st);
      await _store.remove(key);
      return null;
    } catch (e, st) {
      _logCorrupt(aggregate, e, st);
      await _store.remove(key);
      return null;
    }
  }

  Map<String, dynamic> _encodePrevious(PreviousPerformanceSnapshot s) => {
    'exerciseId': s.exerciseId,
    'sessionType': s.sessionType.name,
    'performedAt': s.performedAt.toIso8601String(),
    'setSummary': s.setSummary,
    'loadSummary': s.loadSummary,
    'repSummary': s.repSummary,
    'paceSummary': s.paceSummary,
    'durationSummary': s.durationSummary,
    'distanceSummary': s.distanceSummary,
    'rpe': s.rpe,
    'coachNote': s.coachNote,
  };

  PreviousPerformanceSnapshot _decodePrevious(Map<String, dynamic> map) {
    final typeName = map['sessionType']?.toString() ?? 'other';
    final sessionType = PreviousPerformanceSessionType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => PreviousPerformanceSessionType.other,
    );
    return PreviousPerformanceSnapshot(
      exerciseId: map['exerciseId']?.toString() ?? '',
      sessionType: sessionType,
      performedAt: DateTime.parse(map['performedAt'].toString()).toUtc(),
      setSummary: map['setSummary']?.toString(),
      loadSummary: map['loadSummary']?.toString(),
      repSummary: map['repSummary']?.toString(),
      paceSummary: map['paceSummary']?.toString(),
      durationSummary: map['durationSummary']?.toString(),
      distanceSummary: map['distanceSummary']?.toString(),
      rpe: (map['rpe'] as num?)?.toInt(),
      coachNote: map['coachNote']?.toString(),
    );
  }

  void _logCorrupt(String aggregate, Object error, StackTrace st) {
    debugPrint('[AthleteLocalRepository] corrupt $aggregate: $error');
    debugPrint('$st');
  }
}
