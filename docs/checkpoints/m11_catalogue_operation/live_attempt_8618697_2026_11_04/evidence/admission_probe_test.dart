import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';

Map<String,String> sources(String dir) => {
 for (final n in ['SOURCE.json','SCHEDULE_CANDIDATE.json','STRENGTH_REVIEW_GRAPHS.json','RUNNING_BODIES.json','IDENTITY_INTAKE.json'])
  n:File('$dir/$n').readAsStringSync()
};
void main() {
 test('complete genuine strength admission remains refused after no-write catalogue conflict stop', () async {
  final c=GenuineWorkspace.fromSelectedSources(sources(hybridSourceDirectory),historicalSources:[sources(archivedHybridSourceDirectory)]);
  addTearDown(c.dispose);
  final selected=(jsonDecode(File('$hybridSourceDirectory/SOURCE.json').readAsStringSync()) as Map)['sessions'] as List;
  final strength=selected.where((s)=>s['type']=='strength').toList();
  expect(strength,hasLength(20));
  final outcomes=<Map<String,dynamic>>[];
  final missing=<String,int>{};
  for(final s in strength) {
   final rev=c.selected(s['session_id'] as String);
   final before=rev.source;
   final result=c.inspectRevision(rev);
   expect(result.admitted,isFalse);
   expect(result.issues.every((i)=>i.contains('Unresolved exercise setup')),isTrue,reason:result.issues.join('; '));
   final graph=jsonDecode(before) as Map;
   for(final b in graph['blocks'] as List) {
    for(final e in b['exercises'] as List) {
     if(e['exercise_id']==null) missing.update(e['variant_key'] as String,(v)=>v+1,ifAbsent:()=>1);
    }
   }
   expect(rev.source,before);
   outcomes.add({'session_id':s['session_id'],'admitted':result.admitted,'issues':result.issues,'source_unchanged':true});
  }
  expect(missing,{'chest_supported_db_row':10,'seated_supported_db_press':10,'reverse_lunge_db':8});
  final complete=await c.refreshReview();
  expect(complete,isFalse);
  expect(()=>NativeSourceBundle.prepare(c),throwsFormatException);
  final report={'classification':'GENUINE_LOCAL_ADMISSION_ATTEMPT_AFTER_HOSTED_NO_WRITE_STOP','complete_strength_admitted':outcomes.where((s)=>s['admitted']==true).length,'complete_strength_attempted':20,'missing_occurrences':missing,'whole_programme_review':complete,'complete_export_refused':true,'new_catalogue_rows_installed':0,'old_revisions_unchanged':true,'D8':'PENDING','Gate_A':'OPEN','sessions':outcomes};
  File('/private/tmp/m11_live_apply_8618697_20261104/ADMISSION.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
 });
}
