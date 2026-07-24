import 'package:founder_importer/models/exercise.dart';
import 'package:founder_importer/models/protocol_draft.dart';

import 'package:founder_importer/features/founder_programme_import/founder_programme_protocol_writer.dart';

class RecordingFounderProgrammeProtocolWriter
    implements FounderProgrammeProtocolWriter {
  final drafts = <ProtocolDraft>[];

  @override
  Future<void> saveDraft(ProtocolDraft draft) async {
    drafts.add(draft);
  }
}

List<Exercise> founderImportTestExercises() {
  return const [
    Exercise(
      exerciseId: 'DB-FLOOR-PRESS',
      name: 'Dumbbell Floor Press',
      slug: 'dumbbell-floor-press',
      published: true,
    ),
    Exercise(
      exerciseId: 'GOBLET-SQ',
      name: 'Goblet Squat',
      slug: 'goblet-squat',
      published: true,
    ),
  ];
}

const founderImportSampleYaml = '''
schema_version: 1

programme:
  import_key: founder-test-v1
  title: Founder Test Programme
  code: FOUNDER-TEST
  description: Test import
  objective: Strength foundation
  duration_weeks: 1

weeks:
  - week_number: 1
    title: Week 1
    days:
      - day_number: 1
        display_name: Monday
        is_rest_day: false
        sessions:
          - title: Lower Strength
            session_type: strength
            estimated_duration_minutes: 55
            coach_notes: Quality reps only.
            blocks:
              - title: Primary
                block_type: strength
                order: 1
                exercises:
                  - exercise_slug: goblet-squat
                    order: 1
                    prescription:
                      sets: 3
                      reps: 10
                      load:
                        value: 32
                        unit: kg
                      rest_seconds: 120
      - day_number: 2
        is_rest_day: true
''';
