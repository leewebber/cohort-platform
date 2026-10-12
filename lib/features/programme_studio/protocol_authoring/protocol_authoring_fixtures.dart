import 'dart:convert';

import '../../../domain/exercise_knowledge/models/exercise_definition.dart';
import '../../../domain/exercise_knowledge/models/exercise_identity_mapping.dart';
import '../../../domain/exercise_knowledge/value_objects/exercise_id.dart';
import '../../../domain/exercise_knowledge/value_objects/transitional_exercise_id.dart';
import '../../../domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import '../../../domain/exercise_knowledge/vocabulary/exercise_modality.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import '../authoring/programme_authoring_fixtures.dart';
import 'founder_strength_yaml_writer.dart';

const d2RootProtocolId = 'syn-d2-strength-r1-w1-d1-s1';
const d2LineageId = 'SYN-D2-STRENGTH-LINEAGE';
String d2ImportKey(int revision) => 'syn-d2-strength-r$revision';
String d2SessionKey(int revision) => 'SYN-D2-STRENGTH-R$revision';

List<ExerciseDefinition> d2ExerciseDefinitions() => [
  for (var i = 1; i <= 2; i++)
    ExerciseDefinition(
      id: ExerciseId.parse('EX-900$i'),
      canonicalName: 'Synthetic fixture ${i == 1 ? 'A' : 'B'}',
      modality: ExerciseModality.strength,
      lifecycleStatus: ExerciseLifecycleStatus.published,
      version: '1',
    ),
];
List<ExerciseIdentityMapping> d2IdentityMappings() => [
  for (var i = 1; i <= 2; i++)
    ExerciseIdentityMapping(
      id: 'd2-fixture-map-$i',
      transitionalId: TransitionalExerciseId.parse(
        'cohort.exercise.d2_fixture_${i == 1 ? 'a' : 'b'}',
      ),
      canonicalId: ExerciseId.parse('EX-900$i'),
      lifecycleStatus: ExerciseLifecycleStatus.published,
      version: '1',
      provenance:
          'Synthetic local contract test only; no production identity approval.',
    ),
];

Map<String, dynamic> d2FounderTree() =>
    jsonDecode(
          jsonEncode({
            'schema_version': 1,
            'programme': {
              'import_key': d2ImportKey(1),
              'code': 'SYN-D2',
              'title': 'Synthetic D2 wrapper',
              'description': 'Local fixture only.',
              'objective': 'Inspect authored source; no coaching approval.',
              'duration_weeks': 1,
              'sessions_per_week': 1,
            },
            'weeks': [
              {
                'week_number': 1,
                'title': 'Synthetic week',
                'days': [
                  {
                    'day_number': 1,
                    'display_name': 'Synthetic day',
                    'is_rest_day': false,
                    'coach_notes': 'Fixed synthetic wrapper notes.',
                    'sessions': [
                      {
                        'title': 'Synthetic strength session',
                        'session_type': 'strength',
                        'estimated_duration_minutes': 20,
                        'coach_notes': 'Synthetic session note.',
                        'blocks': [
                          {
                            'title': 'Straight sets',
                            'block_type': 'strength',
                            'order': 1,
                            'coach_notes': 'Synthetic block note.',
                            'exercises': [
                              {
                                'transitional_exercise_id':
                                    'cohort.exercise.d2_fixture_a',
                                'exercise_name': 'Synthetic fixture A',
                                'order': 1,
                                'prescription': {
                                  'sets': 2,
                                  'reps': 5,
                                  'rest_seconds': 60,
                                  'tempo': '3-1-1',
                                  'notes': 'Synthetic cue only.',
                                  'load': {'unit': 'kg', 'value': 12.5},
                                },
                              },
                              {
                                'transitional_exercise_id':
                                    'cohort.exercise.d2_fixture_b',
                                'exercise_name': 'Synthetic fixture B',
                                'order': 2,
                                'prescription': {'sets': 1, 'reps': 3},
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          }),
        )
        as Map<String, dynamic>;
String d2R1Source() =>
    '# Retained R1 synthetic source. Not programme content.\n${const FounderStrengthYamlWriter().write(d2FounderTree())}';

/// D1's accepted synthetic contract fixture supplies the locked package shape.
/// This detached D2 fixture has one slot/lineage; it does not mutate D1 inputs.
Map<String, dynamic> d2PackageTree({
  required SessionRevisionIdentity identity,
  required String title,
}) {
  final tree = programmeAuthoringFixtures.first.sourceTree;
  final programme = tree['programme'] as Map;
  programme['lineage_code'] = 'SYN-D2-PROGRAMME';
  programme['name'] = 'Synthetic D2 revision selection';
  programme['duration_weeks'] = 1;
  final weeks = tree['weeks'] as List;
  weeks.removeLast();
  final slots =
      (((weeks.single as Map)['days'] as List).first as Map)['slots'] as List;
  slots.removeLast();
  (slots.single as Map)['session_key'] = d2SessionKey(identity.revisionNumber);
  (tree['assessments'] as List).single['slot_ref'] = 'W1D1S1';
  (tree['comparison_identities'] as List).single['session_lineage_id'] =
      d2LineageId;
  tree['sessions'] = [
    {
      'session_key': d2SessionKey(identity.revisionNumber),
      'protocol_id': identity.protocolId,
      'session_lineage_id': identity.sessionLineageId,
      'revision_number': identity.revisionNumber,
      'title': title,
    },
  ];
  return tree;
}
