import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/catalogue_operation_receipt.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/models/exercise.dart';

const root='/private/tmp/m11_guard_compatibility_20261104/rehearsal_final/retained';
dynamic read(String name)=>jsonDecode(File('$root/$name').readAsStringSync());
void main() {
 final report=<String,dynamic>{'classification':'SYNTHETIC_LOCAL_FIXTURE_NOT_GENUINE_RETENTION'};
 tearDownAll(()=>File('/private/tmp/m11_guard_compatibility_20261104/INTAKE_FINAL.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n'));
 test('actual legacy resolver admits three unique target lookups and refuses used ambiguous slug',() {
  final rows=(read('readback.raw.json') as Map)['rows'] as List;
  final catalogue=[for(final row in rows)Exercise.fromMap(Map<String,dynamic>.from(row as Map))];
  final resolver=FounderProgrammeExerciseResolver.fromCatalogue(catalogue);
  final operations=(read('manifest.json') as Map)['operations'] as List;
  for(final o in operations) {
   final f=o['fields'] as Map;
   expect(resolver.resolveExerciseId(FounderProgrammeYamlExercise(order:1,exerciseSlug:f['slug'] as String)),f['exercise_id']);
  }
  const duplicate=FounderProgrammeYamlExercise(order:1,exerciseSlug:'bulgarian-split-squat');
  expect(resolver.resolveExerciseId(duplicate),isNull);
  expect(resolver.validationError(duplicate,'fixture'),contains('matched multiple'));
  final first=operations.first['fields'] as Map;
  final alias=Map<String,dynamic>.from(first)..['exercise_id']='EX-997'..['name']='Synthetic unrelated alias'..['slug']=' ${first['slug']} ';
  final ambiguous=FounderProgrammeExerciseResolver.fromCatalogue([...catalogue,Exercise.fromMap(alias)]);
  expect(ambiguous.resolveExerciseId(FounderProgrammeYamlExercise(order:1,exerciseSlug:first['slug'] as String)),isNull);
  report['legacy_resolver']={'unique_targets_resolved':3,'existing_duplicate_if_requested_refused':true,'trimmed_target_dependency_refused':true,'unrelated_duplicate_does_not_change_target_resolution':true};
 });
 test('actual Studio receipt intake refuses the synthetic retained rehearsal even with matching file pins',() {
  final files={for(final n in ['receipt.json','manifest.json','seed.sql','apply.json','preflight.raw.json','readback.raw.json'])n:File('$root/$n').readAsStringSync()};
  final receipt=read('receipt.json') as Map;
  expect(()=>RetainedCatalogueOperation.read(files,CatalogueOperationTrust(receiptSha256:nativeDigest(files['receipt.json']!),auditReference:receipt['audit_reference'] as String)),throwsFormatException);
  report['studio_synthetic_rehearsal_refused']=true;
  report['genuine_receipt_pin_installed']=false;
 });
}
