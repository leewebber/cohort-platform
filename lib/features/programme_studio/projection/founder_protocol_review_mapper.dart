import 'dart:convert';

import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';

import '../domain/programme_review_models.dart';

class FounderProtocolReviewMapper {
  const FounderProtocolReviewMapper();

  List<ProgrammeReviewBlock> blocksFor({
    required FounderProgrammeYamlDocument document,
    required int weekNumber,
    required int dayOrder,
    required String sessionTitle,
  }) {
    for (final week in document.weeks) {
      if (week.weekNumber != weekNumber) {
        continue;
      }
      for (final day in week.days) {
        if (day.dayNumber != dayOrder) {
          continue;
        }
        for (final session in day.sessions) {
          if (session.title != sessionTitle) {
            continue;
          }
          return session.blocks
              .map(_block)
              .toList(growable: false)
            ..sort((a, b) => a.position.compareTo(b.position));
        }
      }
    }
    return const [];
  }

  ProgrammeReviewBlock _block(FounderProgrammeYamlBlock block) {
    return ProgrammeReviewBlock(
      position: block.order,
      title: block.title,
      blockType: block.blockType,
      sourceIdentity: 'founder:${block.order}:${block.title}',
      content: null,
      coachNotes: block.coachNotes,
      movements: block.exercises.map(_movement).toList(growable: false),
    );
  }

  ProgrammeReviewMovement _movement(FounderProgrammeYamlExercise exercise) {
    final prescription = exercise.prescription ?? const <String, dynamic>{};
    final reps = prescription['reps'];
    return ProgrammeReviewMovement(
      position: exercise.order,
      name:
          exercise.exerciseName ??
          exercise.exerciseSlug ??
          exercise.transitionalExerciseId ??
          'Movement',
      exerciseId: exercise.transitionalExerciseId,
      sets: prescription['sets']?.toString(),
      reps: _reps(reps),
      duration: _duration(prescription, reps),
      distance: prescription['distance']?.toString(),
      recovery: prescription['rest_seconds']?.toString(),
      notes: exercise.notes ?? exercise.executionGroup?.label,
      rawPrescription: prescription.isEmpty ? null : jsonEncode(prescription),
    );
  }

  String? _reps(Object? reps) {
    if (reps == null) {
      return null;
    }
    if (reps is Map) {
      if (reps['type'] == 'duration') {
        return null;
      }
      if (reps['type'] == 'range') {
        return '${reps['min']}–${reps['max']}';
      }
      return reps['text']?.toString() ?? reps.toString();
    }
    return reps.toString();
  }

  String? _duration(Map<String, dynamic> prescription, Object? reps) {
    if (prescription['duration'] != null) {
      return prescription['duration'].toString();
    }
    if (reps is Map && reps['type'] == 'duration') {
      return reps['text']?.toString();
    }
    return null;
  }
}
