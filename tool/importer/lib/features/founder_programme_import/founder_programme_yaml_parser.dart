import 'package:yaml/yaml.dart';

import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';

class FounderProgrammeYamlParser {
  const FounderProgrammeYamlParser();

  FounderProgrammeYamlDocument parse(String yamlSource) {
    final dynamic root;
    try {
      root = loadYaml(yamlSource);
    } catch (error) {
      throw FounderProgrammeImportException('YAML parse failed: $error');
    }

    if (root is! YamlMap) {
      throw FounderProgrammeImportException(
        'Root document must be a YAML map.',
      );
    }

    final map = _toStringKeyMap(root);

    final schemaVersion = _requireInt(map, 'schema_version');
    final programmeRaw = map['programme'];
    final weeksRaw = map['weeks'];

    if (programmeRaw is! Map) {
      throw FounderProgrammeImportException('programme must be a map.');
    }
    if (weeksRaw is! List) {
      throw FounderProgrammeImportException('weeks must be a list.');
    }

    final programme = _parseProgramme(_toStringKeyMap(programmeRaw));
    final weeks = weeksRaw
        .map((week) {
          if (week is! Map) {
            throw FounderProgrammeImportException('Each week must be a map.');
          }
          return _parseWeek(_toStringKeyMap(week));
        })
        .toList(growable: false);

    return FounderProgrammeYamlDocument(
      schemaVersion: schemaVersion,
      programme: programme,
      weeks: weeks,
    );
  }

  FounderProgrammeYamlProgramme _parseProgramme(Map<String, dynamic> map) {
    return FounderProgrammeYamlProgramme(
      importKey: _requireString(map, 'import_key'),
      title: _requireString(map, 'title'),
      code: _requireString(map, 'code'),
      description: _optionalString(map, 'description'),
      objective: _optionalString(map, 'objective'),
      durationWeeks: _requireInt(map, 'duration_weeks'),
      sessionsPerWeek: _optionalInt(map, 'sessions_per_week'),
    );
  }

  FounderProgrammeYamlWeek _parseWeek(Map<String, dynamic> map) {
    final daysRaw = map['days'];
    if (daysRaw is! List) {
      throw FounderProgrammeImportException('week.days must be a list.');
    }

    return FounderProgrammeYamlWeek(
      weekNumber: _requireInt(map, 'week_number'),
      title: _optionalString(map, 'title'),
      days: daysRaw
          .map((day) {
            if (day is! Map) {
              throw FounderProgrammeImportException('Each day must be a map.');
            }
            return _parseDay(_toStringKeyMap(day));
          })
          .toList(growable: false),
    );
  }

  FounderProgrammeYamlDay _parseDay(Map<String, dynamic> map) {
    final sessionsRaw = map['sessions'];
    final isRestDay = map['is_rest_day'] == true;
    final sessions = <FounderProgrammeYamlSession>[];

    if (sessionsRaw != null) {
      if (sessionsRaw is! List) {
        throw FounderProgrammeImportException('day.sessions must be a list.');
      }
      for (final session in sessionsRaw) {
        if (session is! Map) {
          throw FounderProgrammeImportException('Each session must be a map.');
        }
        sessions.add(_parseSession(_toStringKeyMap(session)));
      }
    }

    return FounderProgrammeYamlDay(
      dayNumber: _requireInt(map, 'day_number'),
      displayName: _optionalString(map, 'display_name'),
      isRestDay: isRestDay,
      coachNotes: _optionalString(map, 'coach_notes'),
      sessions: sessions,
    );
  }

  FounderProgrammeYamlSession _parseSession(Map<String, dynamic> map) {
    final blocksRaw = map['blocks'];
    if (blocksRaw is! List) {
      throw FounderProgrammeImportException('session.blocks must be a list.');
    }

    return FounderProgrammeYamlSession(
      title: _requireString(map, 'title'),
      sessionType: _requireString(map, 'session_type'),
      estimatedDurationMinutes: _optionalInt(map, 'estimated_duration_minutes'),
      coachNotes: _optionalString(map, 'coach_notes'),
      blocks: blocksRaw
          .map((block) {
            if (block is! Map) {
              throw FounderProgrammeImportException(
                'Each block must be a map.',
              );
            }
            return _parseBlock(_toStringKeyMap(block));
          })
          .toList(growable: false),
    );
  }

  FounderProgrammeYamlBlock _parseBlock(Map<String, dynamic> map) {
    final exercisesRaw = map['exercises'];
    if (exercisesRaw is! List) {
      throw FounderProgrammeImportException('block.exercises must be a list.');
    }

    return FounderProgrammeYamlBlock(
      title: _requireString(map, 'title'),
      blockType: _requireString(map, 'block_type'),
      order: _requireInt(map, 'order'),
      coachNotes: _optionalString(map, 'coach_notes'),
      exercises: exercisesRaw
          .map((exercise) {
            if (exercise is! Map) {
              throw FounderProgrammeImportException(
                'Each exercise must be a map.',
              );
            }
            return _parseExercise(_toStringKeyMap(exercise));
          })
          .toList(growable: false),
    );
  }

  FounderProgrammeYamlExercise _parseExercise(Map<String, dynamic> map) {
    final prescriptionRaw = map['prescription'];
    Map<String, dynamic>? prescription;
    if (prescriptionRaw != null) {
      if (prescriptionRaw is! Map) {
        throw FounderProgrammeImportException(
          'exercise.prescription must be a map when provided.',
        );
      }
      prescription = _toStringKeyMap(prescriptionRaw);
    }

    return FounderProgrammeYamlExercise(
      exerciseSlug: _optionalString(map, 'exercise_slug'),
      exerciseName: _optionalString(map, 'exercise_name'),
      order: _requireInt(map, 'order'),
      prescription: prescription,
      notes: _optionalString(map, 'notes'),
    );
  }

  static Map<String, dynamic> _toStringKeyMap(Map<dynamic, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
    );
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is YamlMap) {
      return _toStringKeyMap(value);
    }
    if (value is YamlList) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static String _requireString(Map<String, dynamic> map, String key) {
    final value = _optionalString(map, key);
    if (value == null || value.isEmpty) {
      throw FounderProgrammeImportException('$key is required.');
    }
    return value;
  }

  static String? _optionalString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _requireInt(Map<String, dynamic> map, String key) {
    final value = _optionalInt(map, key);
    if (value == null) {
      throw FounderProgrammeImportException('$key is required.');
    }
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
