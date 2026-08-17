import 'package:founder_importer/models/exercise.dart';
import 'package:founder_importer/models/strength_exercise_prescription.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_identity_resolution.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';

/// Maps importer YAML prescription maps to [StrengthExercisePrescription].
class FounderProgrammePrescriptionMapper {
  const FounderProgrammePrescriptionMapper();

  StrengthExercisePrescription? mapPrescription(Map<String, dynamic>? yaml) {
    if (yaml == null || yaml.isEmpty) return null;

    final sets = _parseInt(yaml['sets']) ?? 0;
    final reps = _mapReps(yaml['reps']);
    final load = _mapLoad(yaml['load'], yaml['target_rpe']);
    final restSeconds = _parseInt(yaml['rest_seconds']);
    final tempo = yaml['tempo']?.toString();
    final coachCue = yaml['notes']?.toString();
    final performanceCapture = _mapPerformanceCapture(
      yaml['performance_capture'],
    );

    final prescription = StrengthExercisePrescription(
      sets: sets,
      reps: reps,
      load: load,
      restSeconds: restSeconds,
      tempo: tempo,
      coachCue: coachCue,
      performanceCapture: performanceCapture,
    );

    if (!prescription.hasStructuredData) return null;
    return prescription;
  }

  List<String> validatePrescription(Map<String, dynamic>? yaml) {
    if (yaml == null || yaml.isEmpty) return const [];

    final prescription = mapPrescription(yaml);
    if (prescription == null) {
      return const [
        'prescription must include structured sets/reps/load data.',
      ];
    }

    return prescription.validate(requireComplete: true);
  }

  StrengthRepPrescription _mapReps(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final type = map['type']?.toString().trim().toLowerCase();
      if (type == 'range') {
        return StrengthRepPrescription.range(
          min: _parseInt(map['min']) ?? 0,
          max: _parseInt(map['max']) ?? 0,
        );
      }
      if (type == 'duration') {
        return StrengthRepPrescription(
          type: StrengthRepType.duration,
          text: map['text']?.toString(),
        );
      }
      if (type == 'distance') {
        return StrengthRepPrescription(
          type: StrengthRepType.distance,
          text: map['text']?.toString(),
        );
      }
      if (type == 'max_effort' || type == 'maxeffort') {
        return StrengthRepPrescription(
          type: StrengthRepType.maxEffort,
          text: map['text']?.toString() ?? 'AMRAP',
        );
      }
      if (type == 'exact' && map['exact_reps'] != null) {
        return StrengthRepPrescription.exact(_parseInt(map['exact_reps']) ?? 0);
      }
    }

    if (raw is String) {
      final trimmed = raw.trim();
      final rangeMatch = RegExp(r'^(\d+)\s*[–-]\s*(\d+)$').firstMatch(trimmed);
      if (rangeMatch != null) {
        return StrengthRepPrescription.range(
          min: int.parse(rangeMatch.group(1)!),
          max: int.parse(rangeMatch.group(2)!),
        );
      }
      if (trimmed.toUpperCase() == 'AMRAP') {
        return StrengthRepPrescription(
          type: StrengthRepType.maxEffort,
          text: 'AMRAP',
        );
      }
    }

    final repsValue = _parseInt(raw);
    if (repsValue != null && repsValue > 0) {
      return StrengthRepPrescription.exact(repsValue);
    }

    return const StrengthRepPrescription(
      type: StrengthRepType.exact,
      exactReps: null,
    );
  }

  StrengthLoadPrescription? _mapLoad(dynamic loadRaw, dynamic targetRpeRaw) {
    if (loadRaw is Map) {
      final map = Map<String, dynamic>.from(loadRaw);
      final unit = map['unit']?.toString().trim().toLowerCase();
      final value = map['value'];

      if (unit == 'kg') {
        final kg = _parseDouble(value);
        if (kg != null && kg > 0) {
          return StrengthLoadPrescription(
            type: StrengthLoadType.fixedKg,
            kg: kg,
          );
        }
      }
      if (unit == 'percent_1rm' || unit == '%1rm' || unit == '1rm') {
        final percent = _parseDouble(value);
        if (percent != null && percent > 0) {
          return StrengthLoadPrescription(
            type: StrengthLoadType.percent1rm,
            percent1rm: percent,
          );
        }
      }
      if (unit == 'bodyweight') {
        return const StrengthLoadPrescription(
          type: StrengthLoadType.bodyweight,
        );
      }
      if (unit == 'rpe') {
        final rpe = _parseInt(value);
        if (rpe != null && rpe > 0) {
          return StrengthLoadPrescription(type: StrengthLoadType.rpe, rpe: rpe);
        }
      }
      if (unit == 'rir') {
        final rir = _parseInt(value);
        if (rir != null && rir >= 0) {
          return StrengthLoadPrescription(type: StrengthLoadType.rir, rir: rir);
        }
      }
    }

    final targetRpe = _parseInt(targetRpeRaw);
    if (targetRpe != null && targetRpe > 0) {
      return StrengthLoadPrescription(
        type: StrengthLoadType.rpe,
        rpe: targetRpe,
      );
    }

    return null;
  }

  ExercisePerformanceCapture? _mapPerformanceCapture(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final capture = ExercisePerformanceCapture(
      loadUnit: map['load_unit']?.toString(),
      loadLabel: map['load_label']?.toString(),
      distanceUnit: map['distance_unit']?.toString(),
      durationOptional: map['duration_optional'] == true,
    );
    return capture.toJson().length == 1 && !capture.durationOptional
        ? null
        : capture;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// Resolves YAML exercise references to catalogue rows (slug, then exact name).
class FounderProgrammeExerciseResolver {
  FounderProgrammeExerciseResolver._(
    this._catalogue,
    this._transitionalIdentityResolver,
  );

  final List<Exercise> _catalogue;
  final FounderProgrammeTransitionalIdentityResolver?
  _transitionalIdentityResolver;

  factory FounderProgrammeExerciseResolver.fromCatalogue(
    List<Exercise> exercises, {
    FounderProgrammeTransitionalIdentityResolver? transitionalIdentityResolver,
  }) {
    return FounderProgrammeExerciseResolver._(
      exercises,
      transitionalIdentityResolver,
    );
  }

  /// Legacy slug/name resolution for YAML without a transitional identity.
  String? resolveExerciseId(FounderProgrammeYamlExercise exercise) {
    final slug = exercise.exerciseSlug?.trim();
    if (slug != null && slug.isNotEmpty) {
      final bySlug = _catalogue
          .where((row) => row.slug?.trim() == slug)
          .toList();
      if (bySlug.length == 1) return bySlug.first.exerciseId;
      if (bySlug.length > 1) return null;
    }

    final name = exercise.exerciseName?.trim();
    if (name != null && name.isNotEmpty) {
      final byName = _catalogue
          .where((row) => row.name.trim() == name)
          .toList();
      if (byName.length == 1) return byName.first.exerciseId;
    }

    return null;
  }

  FounderProgrammeResolvedIdentityPlan resolveDocument(
    FounderProgrammeYamlDocument document,
  ) {
    final canonicalIds = <FounderProgrammeExerciseLocation, String>{};
    final issues = <FounderProgrammeIdentityIssue>[];
    final importKey = document.programme.importKey;

    for (final week in document.weeks) {
      for (final day in week.days) {
        for (
          var sessionIndex = 0;
          sessionIndex < day.sessions.length;
          sessionIndex++
        ) {
          final session = day.sessions[sessionIndex];
          for (
            var blockIndex = 0;
            blockIndex < session.blocks.length;
            blockIndex++
          ) {
            final block = session.blocks[blockIndex];
            for (final exercise in block.exercises) {
              final location = FounderProgrammeExerciseLocation(
                importKey: importKey,
                weekNumber: week.weekNumber,
                dayNumber: day.dayNumber,
                sessionOrder: sessionIndex + 1,
                blockOrder: block.order,
                exerciseOrder: exercise.order,
              );
              final issue = _resolveAt(
                exercise: exercise,
                location: location,
                canonicalIds: canonicalIds,
              );
              if (issue != null) issues.add(issue);
            }
          }
        }
      }
    }

    return FounderProgrammeResolvedIdentityPlan(
      canonicalIds: canonicalIds,
      issues: issues,
    );
  }

  FounderProgrammeIdentityIssue? _resolveAt({
    required FounderProgrammeYamlExercise exercise,
    required FounderProgrammeExerciseLocation location,
    required Map<FounderProgrammeExerciseLocation, String> canonicalIds,
  }) {
    final transitional = exercise.transitionalExerciseId?.trim();
    final slug = exercise.exerciseSlug?.trim();
    final name = exercise.exerciseName?.trim();

    if (transitional != null && transitional.isNotEmpty) {
      if (slug != null && slug.isNotEmpty) {
        return FounderProgrammeIdentityIssue(
          location: location,
          rawReference: transitional,
          code: 'conflicting_authored_reference',
          message:
              'transitional_exercise_id cannot be combined with exercise_slug.',
        );
      }

      final resolver = _transitionalIdentityResolver;
      if (resolver == null) {
        return FounderProgrammeIdentityIssue(
          location: location,
          rawReference: transitional,
          code: 'unmapped_transitional_exercise_id',
          message: 'No transitional identity resolver is configured.',
        );
      }

      final resolution = resolver.resolve(transitional);
      switch (resolution.kind) {
        case FounderProgrammeTransitionalResolutionKind.invalid:
          return FounderProgrammeIdentityIssue(
            location: location,
            rawReference: transitional,
            code: 'invalid_transitional_exercise_id',
            message:
                'transitional_exercise_id must use cohort.exercise.<snake_case>.',
          );
        case FounderProgrammeTransitionalResolutionKind.unmapped:
          return FounderProgrammeIdentityIssue(
            location: location,
            rawReference: transitional,
            code: 'unmapped_transitional_exercise_id',
            message: 'No published founder-approved mapping exists.',
          );
        case FounderProgrammeTransitionalResolutionKind.conflict:
          return FounderProgrammeIdentityIssue(
            location: location,
            rawReference: transitional,
            code: 'conflicting_transitional_mapping',
            message:
                'The transitional identity has multiple canonical targets.',
            canonicalCandidates: resolution.canonicalCandidates,
          );
        case FounderProgrammeTransitionalResolutionKind.retired:
          return FounderProgrammeIdentityIssue(
            location: location,
            rawReference: transitional,
            code: 'retired_transitional_mapping',
            message:
                'The transitional identity is retired and unavailable for new imports.',
          );
        case FounderProgrammeTransitionalResolutionKind.resolved:
          final canonicalId = resolution.canonicalId!;
          final matches = _catalogue
              .where((row) => row.exerciseId.trim() == canonicalId)
              .toList(growable: false);
          if (matches.isEmpty) {
            return FounderProgrammeIdentityIssue(
              location: location,
              rawReference: transitional,
              code: 'missing_canonical_target',
              message:
                  'Resolved canonical target $canonicalId is absent from the supplied catalogue.',
            );
          }
          if (matches.length > 1) {
            return FounderProgrammeIdentityIssue(
              location: location,
              rawReference: transitional,
              code: 'conflicting_canonical_target',
              message:
                  'Resolved canonical target $canonicalId occurs more than once in the supplied catalogue.',
              canonicalCandidates: [canonicalId],
            );
          }
          if (!matches.single.published) {
            return FounderProgrammeIdentityIssue(
              location: location,
              rawReference: transitional,
              code: 'canonical_target_not_published',
              message:
                  'Resolved canonical target $canonicalId is not published.',
            );
          }
          canonicalIds[location] = canonicalId;
          return null;
      }
    }

    if ((slug == null || slug.isEmpty) && (name == null || name.isEmpty)) {
      return FounderProgrammeIdentityIssue(
        location: location,
        rawReference: '',
        code: 'missing_exercise_reference',
        message:
            'Exercise must include transitional_exercise_id, exercise_slug, or exercise_name.',
      );
    }

    final legacyId = resolveExerciseId(exercise);
    if (legacyId == null) {
      return FounderProgrammeIdentityIssue(
        location: location,
        rawReference: (slug != null && slug.isNotEmpty) ? slug : name ?? '',
        code: 'legacy_exercise_reference_unresolved',
        message:
            'Legacy exercise slug/name did not resolve exactly once in the supplied catalogue.',
      );
    }
    canonicalIds[location] = legacyId;
    return null;
  }

  String? validationError(FounderProgrammeYamlExercise exercise, String path) {
    final slug = exercise.exerciseSlug?.trim();
    final name = exercise.exerciseName?.trim();

    if ((slug == null || slug.isEmpty) && (name == null || name.isEmpty)) {
      return '$path must include exercise_slug or exercise_name.';
    }

    if (slug != null && slug.isNotEmpty) {
      final matches = _catalogue
          .where((row) => row.slug?.trim() == slug)
          .toList();
      if (matches.isEmpty) {
        return '$path exercise_slug "$slug" did not match any published exercise.';
      }
      if (matches.length > 1) {
        return '$path exercise_slug "$slug" matched multiple exercises.';
      }
      return null;
    }

    final matches = _catalogue.where((row) => row.name.trim() == name).toList();
    if (matches.isEmpty) {
      return '$path exercise_name "$name" did not match any published exercise exactly.';
    }
    if (matches.length > 1) {
      return '$path exercise_name "$name" matched multiple exercises.';
    }
    return null;
  }
}
