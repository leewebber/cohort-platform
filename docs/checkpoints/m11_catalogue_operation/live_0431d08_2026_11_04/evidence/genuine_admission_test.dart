import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_session_source.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/native_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/catalogue_operation_receipt.dart';
const out='/private/tmp/m11_live_0431d08_20261104';
Map<String,String> sources(String dir)=>{for(final n in ['SOURCE.json','SCHEDULE_CANDIDATE.json','STRENGTH_REVIEW_GRAPHS.json','RUNNING_BODIES.json','IDENTITY_INTAKE.json']) n:File('$dir/$n').readAsStringSync()};
Map<String,dynamic> meaning(String text){final g=jsonDecode(text) as Map<String,dynamic>;g.remove('protocol_id');g.remove('revision_number');return g;}
void main(){
 test('genuine hosted three-record evidence admits complete preserved strength graphs and local full source archive',()async{
  // Trust established by this task's separate operator audit and independent authenticated readback.
  const trust=CatalogueOperationTrust(receiptSha256:'f7261883ef7da25d35f09889f2706c9bd3d26bc33a853d8a0ff358b24fb21b62',auditReference:'supabase-cli-login:a5510f770d978a56-CGK:m11_live_0431d08_20261104');
  final files={for(final n in ['receipt.json','manifest.json','seed.sql','apply.json','preflight.raw.json','readback.raw.json']) n:File('$out/retained/$n').readAsStringSync()};
  final operation=RetainedCatalogueOperation.read(files,trust);
  final c=GenuineWorkspace.fromSelectedSources(sources(hybridSourceDirectory),historicalSources:[sources(archivedHybridSourceDirectory)]);addTearDown(c.dispose);
  final selected=(jsonDecode(File('$hybridSourceDirectory/SOURCE.json').readAsStringSync()) as Map)['sessions'] as List;
  final old={for(final s in selected) if(s['type']=='strength'||s['type']=='running') s['session_id'] as String:c.selected(s['session_id'] as String)};
  final oldBytes={for(final o in c.owners.values) for(final r in o.revisions) r.key:r.source};
  final strength=selected.where((s)=>s['type']=='strength').toList();expect(strength,hasLength(20));
  c.installRetainedCatalogueOperation(operation);
  expect(strength.every((s)=>!c.inspectRevision(old[s['session_id']]!).admitted),isTrue,reason:'Evidence installation must not silently rewrite existing revisions');
  final counts=<String,int>{};var preserved=0;final outcomes=<Map<String,dynamic>>[];
  for(final s in strength){
   final slot=s['session_id'] as String;final before=old[slot]!;final owner=c.ownerOf(before);final expected=meaning(before.source);
   for(final b in expected['blocks'] as List){for(final e in b['exercises'] as List){if(e['exercise_id']==null){final variant=e['variant_key'] as String;final id=c.catalogue.idFor(variant);expect(id,isNotNull);e['exercise_id']=id;counts.update(variant,(v)=>v+1,ifAbsent:()=>1);}else{preserved++;}}}
   c.begin(before);c.edit(owner,(g){for(final b in g['blocks']){for(final e in b['exercises']){if(e['exercise_id']==null)e['exercise_id']=c.catalogue.idFor(e['variant_key'] as String);}}});
   expect(c.freeze(owner),isTrue,reason:c.errors.join('; '));final after=owner.latest;
   expect(meaning(after.source),expected,reason:'Only missing exact catalogue IDs and local revision identity may change');
   c.useRevision(after,[slot],c.generation);final receipt=c.inspectRevision(c.selected(slot));expect(receipt.admitted,isTrue,reason:receipt.issues.join('; '));
   outcomes.add({'session_id':slot,'old_revision_key':before.key,'new_revision_key':after.key,'source_sha256':nativeDigest(after.source),'admitted':receipt.admitted,'prescriptions_unchanged':true});
  }
  expect(counts,{'chest_supported_db_row':10,'seated_supported_db_press':10,'reverse_lunge_db':8});expect(preserved,77);
  for(final o in c.owners.values){for(final r in o.revisions){if(oldBytes.containsKey(r.key))expect(r.source,oldBytes[r.key]);}}
  final running=selected.where((s)=>s['type']=='running').toList();expect(running,hasLength(40));
  for(final s in running){expect(c.selected(s['session_id'] as String).source,old[s['session_id']]!.source);}
  c.excludeUnusedSources();expect(await c.refreshReview(),isTrue,reason:c.errors.join('; '));
  final saved=c.save();File('$out/admitted-workspace.json').writeAsStringSync(saved);
  final opened=c.prepareOpen(saved).candidate;addTearDown(opened.dispose);expect(opened.save(),saved);expect(await opened.refreshReview(),isTrue,reason:opened.errors.join('; '));
  final archive=NativeSourceBundle.prepare(c).transport.archiveBytes;File('$out/admitted-source.tar').writeAsBytesSync(archive);
  final verified=NativeSourceBundle.verify(File('$out/admitted-source.tar').readAsBytesSync(),c.catalogue);
  expect((jsonDecode(verified['source-index.json']!) as Map)['sessions'],hasLength(60));
  final reopened=NativeSourceBundle.open(archive,c.catalogue);addTearDown(reopened.dispose);expect(reopened.occurrences,hasLength(60));expect(await reopened.refreshReview(),isTrue,reason:reopened.errors.join('; '));
  final validation=jsonDecode(verified['validation.json']!);expect(validation['status'],'LOCALLY_VALIDATED_NOT_APPROVED_OR_PUBLISHED');
  final report={'classification':'GENUINE_HOSTED_EVIDENCE_LOCAL_STRENGTH_ADMISSION','catalogue_ids':{'chest_supported_db_row':c.catalogue.idFor('chest_supported_db_row'),'seated_supported_db_press':c.catalogue.idFor('seated_supported_db_press'),'reverse_lunge_db':c.catalogue.idFor('reverse_lunge_db')},'trust_receipt_sha256':trust.receiptSha256,'complete_strength_admitted':20,'complete_strength_attempted':20,'resolved_occurrences':counts,'existing_id_occurrences_unchanged':preserved,'all_105_strength_prescriptions_unchanged':true,'all_old_revision_bytes_preserved':true,'old_revision_count':oldBytes.length,'running_sources_unchanged':40,'complete_programme_review':true,'archive_session_count':60,'editable_roundtrip_exact':true,'archive_readback_verified':true,'archive_reopen_review':true,'workspace_sha256':nativeDigest(saved),'validation':validation,'D8':'PENDING','programme_publication':'NOT_PERFORMED','M1_1':'OPEN','Gate_A':'OPEN','sessions':outcomes};
  File('$out/ADMISSION.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(report)}\n');
 });
}
