import 'dart:io';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/domain/exercise_knowledge/value_objects/exercise_id.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_modality.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';

/// Disposable fixture authority simulation only. Never a catalogue/backfill producer.
void main() {
  const kinds = PersonalisationTargetKind.values;
  const versions = ['7', '3', '11'];
  const modalities = [
    ExerciseModality.locomotion,
    ExerciseModality.erg,
    ExerciseModality.strength,
  ];
  for (var i = 0; i < 3; i++) {
    final definition = ExerciseDefinition(
      id: ExerciseId.parse('EX-${900900 + i}'),
      canonicalName: 'Synthetic ${kinds[i].name} fixture',
      modality: modalities[i],
      lifecycleStatus: ExerciseLifecycleStatus.published,
      version: versions[i],
      publishedAt: DateTime.utc(2026, 10, 23),
    );
    final provenance = {
      'issuer': 'founder_exercise_publication_v1',
      'event_id': 'bc230000-0000-4000-8000-00000000002$i',
      'source_reference': 'disposable-synthetic-publication-$i',
      'published_at': '2026-10-23T00:00:00Z',
      'approved_binding_kinds': [kinds[i].name],
    };
    stdout.writeln(
      "SET ROLE cohort_exercise_version_publisher; SELECT public.retain_published_exercise_definition_v1(\$doc\$${personalisationCanonicalJson(definition.toJson())}\$doc\$,\$doc\$${personalisationCanonicalJson(provenance)}\$doc\$::jsonb); RESET ROLE;",
    );
  }
}
