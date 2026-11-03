import hashlib
import json
from pathlib import Path
import unittest
import select_performance_running as generator

ROOT=generator.ROOT
class PerformanceSourceTest(unittest.TestCase):
    def test_all_forty_match_independent_reconciliation_projection_and_selected_reference(self):
        data=generator.build()
        audit=json.loads((ROOT/'docs/checkpoints/m11_run_source_reconciliation/ALL_40_RUNS.json').read_text())
        self.assertEqual(hashlib.sha256(generator.REFERENCE.read_bytes()).hexdigest(),audit['source_pins'][str(generator.REFERENCE.relative_to(ROOT))])
        expected={r['session_id']:r for r in audit['rows']}
        bodies=json.loads(data['RUNNING_BODIES.json']);self.assertEqual(len(bodies),40)
        for body in bodies:
            with self.subTest(session=body['source_session_id']):
                actual=[]
                for s in body['workout']['steps']:
                    t=s['target'];target='authored_effort' if t['kind']=='none' else 'zone_2' if t['kind']=='heart_rate_zone_ref' else t['category']
                    actual.append({'role':s['role'],'seconds':s['duration'].get('milliseconds',0)//1000,'distance_metres':s['duration'].get('millimetres',0)//1000,'target':target})
                    self.assertNotIn('fallback_rpe',t)
                    self.assertNotIn(t['kind'],['pace','pace_range','heart_rate','heart_rate_range'])
                self.assertEqual(actual,expected[body['source_session_id']]['reference_semantic_steps_AUDIT_ONLY'])
                self.assertEqual(sum(s['seconds'] for s in actual),body['fixed_seconds'])
    def test_strength_and_evidence_byte_exact_and_no_missing_records_fabricated(self):
        data=generator.build()
        for name in ['STRENGTH_REVIEW_GRAPHS.json','IDENTITY_INTAKE.json']:
            self.assertEqual(data[name].encode(),(generator.ARCHIVE/name).read_bytes())
        source=json.loads(data['SOURCE.json']);old=generator.load('SOURCE.json')
        self.assertEqual([s for s in source['sessions'] if s['type']=='strength'],[s for s in old['sessions'] if s['type']=='strength'])
        graphs=json.loads(data['STRENGTH_REVIEW_GRAPHS.json'])
        self.assertEqual(sum(e['exercise_id'] is None for g in graphs for b in g['blocks'] for e in b['exercises']),28)
    def test_every_recovery_ending_and_independent_weekly_sums(self):
        runs=json.loads(generator.build()['RUNNING_BODIES.json'])
        totals=[]
        for week in range(1,11):
            total=0
            for r in [r for r in runs if r['source_week']==week]:
                ss=r['workout']['steps'];total+=sum(s['duration'].get('milliseconds',0)//1000 for s in ss)
                quality=[i for i,s in enumerate(ss) if s['target']['kind']=='alpha_quality_pace_v1']
                if quality:self.assertEqual(ss[quality[-1]+1]['role'],'cool_down')
                if r['source_day']==2:self.assertEqual(ss[6]['role'],'recovery')
                if r['source_day']==5 and week in [3,5,10]:self.assertEqual(ss[-2]['role'],'recovery')
            totals.append(total)
        self.assertEqual(totals,[11550,12360,13140,11250,13320,12090,12240,11550,10110,6180])
        final=runs[-1]['workout']['steps']
        self.assertEqual([s['duration'].get('milliseconds',0)//1000 for s in final],[600,20,40,20,40,20,40,120,0,300])
        self.assertEqual(final[-2]['duration'],{'kind':'distance','millimetres':10000000})
    def test_regeneration_matches_all_outputs(self):
        for name,text in generator.build().items():self.assertEqual((generator.DEST/name).read_text(),text,name)

if __name__=='__main__':unittest.main()
