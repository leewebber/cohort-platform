import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

/// Builds repository-derived private protocol graphs from founder YAML.
///
/// Plan Package v1 remains the schedule/identity authority. Founder YAML is
/// the executable body authority. This builder does not invent prescriptions.
class PrivateProtocolGraphBuilder {
  const PrivateProtocolGraphBuilder({
    this.parser = const FounderProgrammeYamlParser(),
  });

  final FounderProgrammeYamlParser parser;

  PrivateProtocolGraphBuildResult build({
    required PlanPackageCompileResult compileResult,
    required String founderYaml,
  }) {
    if (!compileResult.isValid || compileResult.manifest == null) {
      throw StateError('Protocol graph requires a valid Plan Package compile.');
    }
    final document = parser.parse(founderYaml);
    final manifest = compileResult.manifest!;
    final graphs = <Map<String, Object?>>[];
    final missing = <String>[];

    for (final week in manifest.weeks) {
      for (final day in week.days) {
        if (day.dayType == ProgrammeDayType.rest && day.slots.isEmpty) {
          continue;
        }
        for (final slot in day.slots) {
          PlanPackageSessionRevisionRef? ref;
          for (final session in manifest.sessions) {
            if (session.sessionKey == slot.sessionKey) {
              ref = session;
              break;
            }
          }
          if (ref == null) {
            missing.add(slot.sessionKey);
            continue;
          }
          final founderSession = _founderSession(
            document: document,
            weekNumber: week.weekNumber,
            dayOrder: day.dayOrder,
            title: ref.title,
          );
          if (founderSession == null || founderSession.blocks.isEmpty) {
            missing.add(ref.protocolId);
            continue;
          }
          graphs.add(
            _graph(
              protocolId: ref.protocolId,
              revisionNumber: ref.revisionNumber,
              session: founderSession,
            ),
          );
        }
      }
    }

    return PrivateProtocolGraphBuildResult(
      graphs: graphs,
      missingProtocolIds: missing,
    );
  }

  FounderProgrammeYamlSession? _founderSession({
    required FounderProgrammeYamlDocument document,
    required int weekNumber,
    required int dayOrder,
    required String title,
  }) {
    for (final week in document.weeks) {
      if (week.weekNumber != weekNumber) continue;
      for (final day in week.days) {
        if (day.dayNumber != dayOrder) continue;
        for (final session in day.sessions) {
          if (session.title == title) return session;
        }
      }
    }
    return null;
  }

  Map<String, Object?> _graph({
    required String protocolId,
    required int revisionNumber,
    required FounderProgrammeYamlSession session,
  }) {
    final blocks = [...session.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));
    return {
      'protocol_id': protocolId,
      'revision_number': revisionNumber,
      'blocks': [
        for (final block in blocks)
          {
            'position': block.order,
            'block_type': block.blockType.trim(),
            'title': block.title.trim(),
            'content': '',
            'workout_format': _workoutFormat(block),
            'timer_config': null,
            'coach_notes': _nonEmpty(block.coachNotes),
            'performance_capture_mode': 'manual',
            'exercises': [
              for (final exercise
                  in ([...block.exercises]
                    ..sort((a, b) => a.order.compareTo(b.order))))
                _exercise(exercise),
            ],
          },
      ],
    };
  }

  Map<String, Object?> _exercise(FounderProgrammeYamlExercise exercise) {
    final name = _nonEmpty(exercise.exerciseName);
    final slug = _nonEmpty(exercise.exerciseSlug);
    return {
      'exercise_id': slug ?? name ?? 'movement-${exercise.order}',
      'position': exercise.order,
      'display_label_override': name ?? slug,
      'prescription': _prescription(exercise),
      if (exercise.executionGroup != null) ...{
        'execution_group_key': exercise.executionGroup!.key,
        'execution_group_label': exercise.executionGroup!.label,
        'execution_group_rounds': exercise.executionGroup!.rounds,
      },
    };
  }

  Map<String, Object?>? _prescription(FounderProgrammeYamlExercise exercise) {
    final yaml = exercise.prescription;
    final notes = [
      if (_nonEmpty(exercise.notes) != null) exercise.notes!.trim(),
    ];
    if (yaml == null || yaml.isEmpty) {
      if (notes.isEmpty) return null;
      return {
        'sets': 0,
        'reps': {'type': 'freeText', 'text': notes.join(' ')},
        'coach_cue': notes.join(' '),
      };
    }

    final duration = yaml['duration']?.toString().trim();
    final distance = yaml['distance']?.toString().trim();
    final restRaw = yaml['rest_seconds'];
    final loadRaw = yaml['load'];
    final runtime = yaml['runtime']?.toString().trim();
    final modality = yaml['modality']?.toString().trim();
    if (runtime != null && runtime.isNotEmpty) {
      notes.add('runtime=$runtime');
    }
    if (modality != null && modality.isNotEmpty) {
      notes.add('modality=$modality');
    }
    if (restRaw != null && restRaw is! int && restRaw.toString().contains('-')) {
      notes.add('rest ${restRaw.toString().trim()}s');
    }

    final sets = _asInt(yaml['sets']) ?? (duration != null || distance != null ? 1 : 0);
    final reps = _reps(yaml['reps'], duration: duration);
    final map = <String, Object?>{
      'sets': sets,
      'reps': reps,
    };
    final load = _load(loadRaw);
    if (load != null) map['load'] = load;
    final rest = _asInt(restRaw);
    if (rest != null) map['rest_seconds'] = rest;
    if (distance != null && distance.isNotEmpty) map['distance_m'] = distance;
    final cue = notes.where((item) => item.trim().isNotEmpty).join(' ').trim();
    if (cue.isNotEmpty) map['coach_cue'] = cue;
    return map;
  }

  Map<String, Object?> _reps(Object? raw, {String? duration}) {
    if (raw is int) {
      return {'type': 'exact', 'exact_reps': raw};
    }
    if (raw is String) {
      final trimmed = raw.trim();
      final range = RegExp(r'^(\d+)\s*[–-]\s*(\d+)$').firstMatch(trimmed);
      if (range != null) {
        return {
          'type': 'range',
          'min_reps': int.parse(range.group(1)!),
          'max_reps': int.parse(range.group(2)!),
        };
      }
      if (trimmed.toUpperCase() == 'AMRAP') {
        return {'type': 'maxEffort', 'text': 'AMRAP'};
      }
      if (trimmed.contains('/') || trimmed.contains('side')) {
        return {'type': 'freeText', 'text': trimmed};
      }
      final exact = int.tryParse(trimmed);
      if (exact != null) {
        return {'type': 'exact', 'exact_reps': exact};
      }
      return {'type': 'freeText', 'text': trimmed};
    }
    if (duration != null && duration.isNotEmpty) {
      return {'type': 'duration', 'text': duration};
    }
    return {'type': 'exact'};
  }

  Map<String, Object?>? _load(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final type = map['type']?.toString().trim().toLowerCase();
    final text = map['text']?.toString().trim();
    if (type == 'freetext' && text != null && text.isNotEmpty) {
      return {'type': 'freeText', 'text': text};
    }
    return null;
  }

  String _workoutFormat(FounderProgrammeYamlBlock block) {
    var steady = false;
    var intervals = false;
    for (final exercise in block.exercises) {
      final runtime = exercise.prescription?['runtime']?.toString();
      if (runtime == 'time_based_steady_state') steady = true;
      if (runtime == 'time_based_intervals') intervals = true;
    }
    if (intervals) return 'intervals';
    if (steady) return 'steady_state';
    return 'none';
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

class PrivateProtocolGraphBuildResult {
  const PrivateProtocolGraphBuildResult({
    required this.graphs,
    required this.missingProtocolIds,
  });

  final List<Map<String, Object?>> graphs;
  final List<String> missingProtocolIds;

  int get blockCount => graphs.fold<int>(
    0,
    (sum, graph) => sum + ((graph['blocks'] as List?)?.length ?? 0),
  );

  int get exerciseCount {
    var count = 0;
    for (final graph in graphs) {
      final blocks = graph['blocks'] as List? ?? const [];
      for (final block in blocks) {
        if (block is Map) {
          count += (block['exercises'] as List?)?.length ?? 0;
        }
      }
    }
    return count;
  }
}
