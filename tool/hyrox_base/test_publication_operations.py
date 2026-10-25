import copy,json,unittest
import publication_operations as p
class PublicationOperationTests(unittest.TestCase):
 def test_no_authority_from_empty_inventory_or_flags(self):
  self.assertFalse(p.analyse_matches({'id':'EX-073','canonical_name':'Back Squat'},[])['authority_verified'])
  self.assertFalse(p.analyse_matches({'id':'EX-073','canonical_name':'Back Squat'},[{'definition':{'id':'EX-073','canonical_name':'Back Squat','version':'7'},'approved':True,'published':True,'verified':True}])['authority_verified'])
 def test_ambiguous_and_conflicting_versions_reject(self):
  d={'id':'EX-073','canonical_name':'Back Squat','equipment':{'required_tokens':['barbell']}}
  exact={'definition':dict(d,version='7',lifecycle_status='published')}
  self.assertIn('AMBIGUOUS',p.analyse_matches(d,[exact,copy.deepcopy(exact)])['disposition'])
  wrong=copy.deepcopy(exact);wrong['definition']['equipment']['required_tokens']=['dumbbell']
  self.assertIn('CONFLICT',p.analyse_matches(d,[wrong])['disposition'])
 def test_matching_content_never_certifies_publication(self):
  d={'id':'EX-073','canonical_name':'Back Squat'}
  result=p.analyse_matches(d,[{'definition':dict(d,version='11',lifecycle_status='published')}])
  self.assertEqual(result['version'],'11');self.assertFalse(result['authority_verified'])
 def test_stable_uuid_matches_established_seed_shape(self):
  # Exact value returned by the unchanged cohort_stable_uuid in disposable PG17.
  self.assertEqual(p.stable_uuid('protocol:block:1'),'24fa73e3-3afe-463e-864e-69440ce8f6c3')
  self.assertNotEqual(p.stable_uuid('protocol:block:1'),p.stable_uuid('protocol:block:2'))
  self.assertRegex(p.stable_uuid('protocol:block:1'),r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-8[0-9a-f]{3}-[0-9a-f]{12}$')
 def test_complete_package_is_deterministic_and_unassigned(self):
  root=p.ROOT;out=root/p.REL
  local=json.loads((out/'LOCAL_REHEARSAL_SOURCE_INVENTORY.json').read_bytes())
  rehearsal=dict(classification='LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE',definitions=local['exercise_definitions'],sources=[dict(source_id=s['source_id'],input_sha256=s['approved_source_sha256'],source=s['rehearsal_source']) for s in local['sources']])
  readiness=json.loads((out/'READINESS.json').read_bytes())
  a=p.build(root,readiness,rehearsal);b=p.build(root,readiness,rehearsal)
  self.assertEqual(a,b)
  self.assertEqual(p.build(root,readiness,p.normalise_rehearsal(local)),a)
  ops=json.loads(a['OPERATIONS.json']);self.assertEqual(len(ops['exercise_operations']),27);self.assertEqual(len(ops['source_operations']),48)
  self.assertEqual(sum(len(x['labels']) for x in ops['exercise_operations']),29)
  keys={x['operation_id'] for x in ops['exercise_operations']}
  for x in ops['source_operations']:
   self.assertIsNone(x['body_sha256']);self.assertIsNone(x['candidate_identity']['assigned_revision'])
   self.assertTrue(set(x['dependencies'])<=keys)
   for block in x['provisional_graph_template']['blocks']:
    for exercise in block['exercises']:
     self.assertIsNone(exercise['exercise_id']);self.assertIsNone(exercise['unresolved_exact_version'])
  self.assertFalse(ops['real_execution_performed']);self.assertIsNone(ops['real_canonical_artifact'])
  self.assertEqual(len(local['rest_entries']),8)
  self.assertEqual(len(local['authored_root_metadata']['schedule']),56)
  for source in local['sources']:self.assertEqual(p.digest(source['authored_source']),source['approved_source_sha256'])
 def test_tampered_source_and_nonfixture_fail_closed(self):
  root=p.ROOT;out=root/p.REL;local=json.loads((out/'LOCAL_REHEARSAL_SOURCE_INVENTORY.json').read_bytes())
  fixture=dict(classification='LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE',definitions=local['exercise_definitions'],sources=[dict(source_id=s['source_id'],input_sha256=s['approved_source_sha256'],source=s['rehearsal_source']) for s in local['sources']])
  readiness=json.loads((out/'READINESS.json').read_bytes())
  bad=copy.deepcopy(fixture);bad['classification']='published'
  with self.assertRaises(ValueError):p.build(root,readiness,bad)
  bad=copy.deepcopy(fixture);bad['sources'][0]['input_sha256']='0'*64
  with self.assertRaises(ValueError):p.build(root,readiness,bad)
if __name__=='__main__':unittest.main()
