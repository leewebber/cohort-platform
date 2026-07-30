import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/workout_format.dart';
import '../../features/session/models/session_execution_plan.dart';
import '../../features/workout_player/models/workout_session_brief.dart';
import '../../features/workout_player/services/coach_brain_workout_plan_service.dart';

/// Serialises [SessionExecutionPlan] for local restore (no full Exercise models).
class SessionExecutionPlanCodec {
  const SessionExecutionPlanCodec();

  Map<String, dynamic> encodePlan(SessionExecutionPlan plan) {
    return {
      'sessionId': plan.sessionId,
      'sessionTitle': plan.sessionTitle,
      'durationMin': plan.durationMin,
      'coachNotes': plan.coachNotes,
      'programmeContextLabel': plan.programmeContextLabel,
      'prescriptionLoadOverrides': plan.prescriptionLoadOverrides,
      'blocks': plan.blocks.map(_encodeBlock).toList(),
    };
  }

  SessionExecutionPlan decodePlan(Map<String, dynamic> map) {
    final blocksRaw = map['blocks'];
    final blocks = <SessionExecutionBlock>[];
    if (blocksRaw is List) {
      for (final item in blocksRaw) {
        if (item is Map) {
          blocks.add(_decodeBlock(Map<String, dynamic>.from(item)));
        }
      }
    }
    final overridesRaw = map['prescriptionLoadOverrides'];
    final overrides = <String, String>{};
    if (overridesRaw is Map) {
      overridesRaw.forEach((k, v) => overrides[k.toString()] = v.toString());
    }
    return SessionExecutionPlan(
      sessionId: map['sessionId']?.toString() ?? '',
      sessionTitle: map['sessionTitle']?.toString() ?? "Today's Training",
      blocks: blocks,
      durationMin: (map['durationMin'] as num?)?.toInt(),
      coachNotes: map['coachNotes']?.toString(),
      programmeContextLabel: map['programmeContextLabel']?.toString(),
      prescriptionLoadOverrides: overrides,
    );
  }

  Map<String, dynamic> encodeBrief(WorkoutSessionBrief brief) => {
    'sessionName': brief.sessionName,
    'objective': brief.objective,
    'estimatedDurationMinutes': brief.estimatedDurationMinutes,
    'primaryFocus': brief.primaryFocus,
    'trainingIntent': brief.trainingIntent,
    'sessionDifficulty': brief.sessionDifficulty,
    'sessionNotes': brief.sessionNotes,
    'coachNotes': brief.coachNotes,
  };

  WorkoutSessionBrief decodeBrief(Map<String, dynamic> map) {
    return WorkoutSessionBrief(
      sessionName: map['sessionName']?.toString() ?? "Today's Training",
      objective: map['objective']?.toString(),
      estimatedDurationMinutes:
          (map['estimatedDurationMinutes'] as num?)?.toInt(),
      primaryFocus: map['primaryFocus']?.toString(),
      trainingIntent: map['trainingIntent']?.toString(),
      sessionDifficulty: map['sessionDifficulty']?.toString(),
      sessionNotes: map['sessionNotes']?.toString(),
      coachNotes: map['coachNotes']?.toString(),
    );
  }

  Map<String, dynamic> _encodeBlock(SessionExecutionBlock block) {
    return {
      'blockId': block.blockId,
      'title': block.title,
      'blockType': block.blockType.name,
      'content': block.content,
      'workoutFormat': block.workoutFormat.name,
      'position': block.position,
      'timerSummary': block.timerSummary,
      'coachNotes': block.coachNotes,
      'linkedExercises': block.linkedExercises.map((e) {
        return {
          'exerciseId': e.exerciseId,
          'displayName': e.displayName,
          'displayLabelOverride': e.displayLabelOverride,
          if (e.prescription != null) 'prescription': e.prescription!.toJson(),
        };
      }).toList(),
    };
  }

  SessionExecutionBlock _decodeBlock(Map<String, dynamic> map) {
    final typeName = map['blockType']?.toString() ?? 'strength';
    final blockType = SessionBlockType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => SessionBlockType.strength,
    );
    final formatName = map['workoutFormat']?.toString() ?? 'none';
    final format = WorkoutFormat.values.firstWhere(
      (f) => f.name == formatName,
      orElse: () => WorkoutFormat.none,
    );
    final exercisesRaw = map['linkedExercises'];
    final exercises = <SessionExecutionExerciseSummary>[];
    if (exercisesRaw is List) {
      for (final item in exercisesRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final rx = m['prescription'];
        exercises.add(
          SessionExecutionExerciseSummary(
            exerciseId: m['exerciseId']?.toString() ?? '',
            displayName: m['displayName']?.toString() ?? 'Movement',
            displayLabelOverride: m['displayLabelOverride']?.toString(),
            prescription: rx is Map
                ? StrengthExercisePrescription.fromJson(
                    Map<String, dynamic>.from(rx),
                  )
                : null,
          ),
        );
      }
    }
    return SessionExecutionBlock(
      blockId: map['blockId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Block',
      blockType: blockType,
      content: map['content']?.toString() ?? '',
      workoutFormat: format,
      position: (map['position'] as num?)?.toInt() ?? 0,
      timerSummary: map['timerSummary']?.toString(),
      linkedExercises: exercises,
      coachNotes: map['coachNotes']?.toString(),
    );
  }
}

/// Persisted prepared execution for restore / reconstruct.
class GeneratedSessionRecord {
  const GeneratedSessionRecord({
    required this.athleteId,
    required this.intendedTrainingDate,
    required this.generatedAt,
    required this.plan,
    required this.brief,
    this.planId,
    this.assignmentId,
    this.orchestrationId,
    this.ontologyVersion,
    this.phaseLabel = 'Foundation',
    this.programmeName,
    this.programmedSessionKey,
    this.planVersion,
    this.week,
    this.day,
    this.acceptedAdaptation,
  });

  final String athleteId;
  final String? planId;
  final String? assignmentId;
  final DateTime intendedTrainingDate;
  final DateTime generatedAt;
  final SessionExecutionPlan plan;
  final WorkoutSessionBrief brief;
  final String? orchestrationId;
  final String? ontologyVersion;
  final String phaseLabel;
  final String? programmeName;
  final String? programmedSessionKey;
  final String? planVersion;
  final int? week;
  final int? day;
  final Map<String, dynamic>? acceptedAdaptation;

  /// Calendar-day match in local time.
  bool isIntendedForToday([DateTime? now]) {
    final n = now ?? DateTime.now();
    final d = intendedTrainingDate.toLocal();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Map<String, dynamic> toPersistenceMap() {
    const codec = SessionExecutionPlanCodec();
    return {
      'athleteId': athleteId,
      'planId': planId,
      'assignmentId': assignmentId,
      'intendedTrainingDate': intendedTrainingDate.toUtc().toIso8601String(),
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'orchestrationId': orchestrationId,
      'ontologyVersion': ontologyVersion,
      'phaseLabel': phaseLabel,
      'programmeName': programmeName,
      'programmedSessionKey': programmedSessionKey,
      'planVersion': planVersion,
      'week': week,
      'day': day,
      'acceptedAdaptation': acceptedAdaptation,
      'plan': codec.encodePlan(plan),
      'brief': codec.encodeBrief(brief),
    };
  }

  factory GeneratedSessionRecord.fromPersistenceMap(Map<String, dynamic> map) {
    const codec = SessionExecutionPlanCodec();
    DateTime requireDate(String key) {
      final raw = map[key]?.toString();
      final parsed = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
      if (parsed == null) throw FormatException('Invalid $key');
      return parsed;
    }

    final planRaw = map['plan'];
    final briefRaw = map['brief'];
    if (planRaw is! Map || briefRaw is! Map) {
      throw const FormatException('Missing plan or brief');
    }

    String? optionalId(String key) {
      final v = map[key]?.toString();
      if (v == null || v.isEmpty) return null;
      return v;
    }

    final adaptationRaw = map['acceptedAdaptation'];
    return GeneratedSessionRecord(
      athleteId: map['athleteId']?.toString() ?? '',
      planId: optionalId('planId'),
      assignmentId: optionalId('assignmentId'),
      intendedTrainingDate: requireDate('intendedTrainingDate'),
      generatedAt: requireDate('generatedAt'),
      orchestrationId: map['orchestrationId']?.toString(),
      ontologyVersion: map['ontologyVersion']?.toString(),
      phaseLabel: map['phaseLabel']?.toString() ?? 'Foundation',
      programmeName: map['programmeName']?.toString(),
      programmedSessionKey: optionalId('programmedSessionKey'),
      planVersion: optionalId('planVersion'),
      week: (map['week'] as num?)?.toInt(),
      day: (map['day'] as num?)?.toInt(),
      acceptedAdaptation: adaptationRaw is Map
          ? Map<String, dynamic>.from(adaptationRaw)
          : null,
      plan: codec.decodePlan(Map<String, dynamic>.from(planRaw)),
      brief: codec.decodeBrief(Map<String, dynamic>.from(briefRaw)),
    );
  }

  CoachBrainWorkoutPlan toCoachBrainPlan() {
    throw UnsupportedError(
      'Use RestoredSessionFactory for player restore; '
      'reconstruct programmed session when engine context is required.',
    );
  }
}
