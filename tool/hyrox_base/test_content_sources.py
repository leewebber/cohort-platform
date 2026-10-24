"""Offline semantic regressions; no sockets or service/database fixtures."""
import copy
import json
from pathlib import Path
import unittest

import content_sources as c


class ContentSourcesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads((c.ROOT / c.REL / 'PROGRESSION.json').read_bytes())
        cls.bundle = c.compile_sources(cls.spec, c.ROOT)
        cls.sessions = {(s['week'],s['mode']):s for s in cls.bundle['sessions']}

    def test_complete_unique_schedule_and_rest_is_not_training(self):
        schedule = self.bundle['schedule']
        self.assertEqual(len(schedule),56)
        self.assertEqual(len(self.bundle['sessions']),48)
        self.assertEqual(len({s['source_id'] for s in self.bundle['sessions']}),48)
        for week in range(1,9):
            days = [s for s in schedule if s['week']==week]
            self.assertEqual([d['day'] for d in days],list(range(1,8)))
            self.assertEqual([d['type'] for d in days],['training']*6+['rest'])
            self.assertIsNone(days[-1]['source_id'])

    def test_source_disagreements_are_not_selected(self):
        plank = self.sessions[1,'gym_b']['blocks'][2]
        row = self.sessions[1,'gym_c']['blocks'][1]['exercises'][1]
        self.assertIsNone(plank['seconds'])
        self.assertEqual(plank['decision']['original'],[20,30])
        self.assertEqual(plank['decision']['later'],[20,20])
        self.assertIsNone(row['reps'])
        self.assertEqual(row['decision']['original'],[10,10])
        self.assertEqual(row['decision']['later'],[10,12])

    def test_latest_long_correction_and_exact_time_conflicts(self):
        for week in [6,7]:
            self.assertEqual(self.sessions[week,'long']['blocks'][0]['minutes'],[65,80])
        conflicts = [w for w in range(1,9) if 'D3' in self.sessions[w,'long']['content_decisions']]
        self.assertEqual(conflicts,[3,5,6,7])
        self.assertEqual(self.sessions[6,'long']['timing']['full_seconds'],[4500,5700])
        self.assertEqual(self.sessions[2,'long']['timing']['full_seconds'][1],5400)

    def test_dedicated_intervals_do_not_add_final_recovery(self):
        for source in self.bundle['sessions']:
            for block in source['blocks']:
                if block['kind'] != 'intervals':
                    continue
                steps = block['steps']
                self.assertEqual(len(steps),2*block['repetitions']-1)
                self.assertEqual(steps[-1]['phase'],'work')
                self.assertEqual(len({s['id'] for s in steps}),len(steps))
        self.assertEqual(self.sessions[1,'gym_a']['timing']['finisher_seconds'],1170)

    def test_accelerations_and_unknown_dynamic_prep(self):
        quality = self.sessions[1,'quality']
        self.assertEqual(quality['timing']['known_seconds'],[3260,3560])
        self.assertIsNone(quality['timing']['full_seconds'])
        self.assertEqual(quality['preparation']['accelerations']['recovery_placement'],'between_only')

    def test_mixed_finishers_are_separate_from_bound_row(self):
        for w in range(1,9):
            b = self.sessions[w,'gym_b']['blocks'][-1]
            self.assertEqual(b['cycles']*2,b['minutes'])
            self.assertEqual(b['stations'][1]['exercise'], 'two_dumbbell_devils_press' if 5<=w<=7 else 'kettlebell_swing')
            g = self.sessions[w,'gym_c']['blocks'][-1]
            self.assertEqual(g['stations'][-1],dict(kind='rest',seconds=60))
            self.assertEqual(g['minutes'],3*g['rounds'])
            self.assertIsNone(g['stations'][1]['race_mapping'])
            self.assertEqual(self.sessions[w,'gym_c']['binding_intents'],[])
        self.assertEqual(self.sessions[4,'gym_b']['blocks'][-1],self.sessions[8,'gym_b']['blocks'][-1])

    def test_per_side_pairing_hold_and_optional_progression(self):
        g = self.sessions[5,'gym_c']['blocks']
        self.assertTrue(g[0]['per_side'])
        self.assertTrue(g[1]['exercises'][1]['per_side'])
        self.assertEqual(g[1]['rest_after_pair_seconds'],[90,90])
        self.assertEqual(g[2]['extended_hold_seconds'],2)
        self.assertEqual(g[2]['resistance_direction'],'optional increase')
        self.assertEqual(self.sessions[5,'gym_b']['blocks'][2]['lever_direction'],'optional longer lever')
        self.assertEqual(self.sessions[4,'gym_a']['blocks'][2]['load_direction'],'lighter')

    def test_no_canonical_identity_or_approval_is_fabricated(self):
        for s in self.bundle['sessions']:
            self.assertIsNone(s['canonical_source'])
            self.assertIsNone(s['exact_exercise_versions'])
            self.assertIn('T1',s['technical_blockers'])
        self.assertEqual(c.canonical_compilation(self.bundle)['canonical_packages'],0)
        forged = copy.deepcopy(self.bundle)
        forged['sessions'][0]['canonical_source'] = {'approved':True,'version':1}
        self.assertEqual(c.canonical_compilation(forged)['status'],'blocked_before_canonical_compilation')

    def test_source_compilation_refuses_unapproved_existing_rule_changes(self):
        bad = copy.deepcopy(self.spec)
        bad['approved_weeks'][5]['long_minutes'][0] = 70
        with self.assertRaisesRegex(ValueError,'disagree'):
            c.compile_sources(bad,c.ROOT)

    def test_invalid_and_unknown_supporting_inputs_refuse(self):
        for key,value in [('carry',[3,-30]),('bike',[13,35,'kettlebell_swing',10,7]),('new_coaching_dose',42)]:
            with self.subTest(key=key):
                bad = copy.deepcopy(self.spec)
                bad['supporting_weeks'][0][key] = value
                with self.assertRaises(ValueError):
                    c.compile_sources(bad,c.ROOT)

    def test_review_round_trip_preserves_every_source_and_alternative(self):
        raw = c.export_review(self.bundle)
        self.assertEqual(c.import_review(raw),self.bundle)
        self.assertEqual(c.export_review(c.import_review(raw)),raw)
        obj = json.loads(raw)
        obj['source']['sessions'][0]['blocks'][0]['reps'] = [99,99]
        with self.assertRaisesRegex(ValueError,'digest'):
            c.import_review(c.encoded(obj))

    def test_export_envelope_refuses_duplicate_unknown_fields(self):
        raw = c.export_review(self.bundle)
        with self.assertRaisesRegex(ValueError,'Duplicate'):
            c.import_review(b'{"format":"wrong",'+raw[1:])
        obj = json.loads(raw)
        obj['approved'] = True
        with self.assertRaisesRegex(ValueError,'Unknown'):
            c.import_review(c.encoded(obj))

    def test_reproducible_readable_coverage_and_manifest(self):
        outputs = c.build_outputs(c.ROOT)
        self.assertEqual(outputs,c.build_outputs(c.ROOT))
        text = outputs['MASTER.md'].decode()
        for s in self.bundle['sessions']:
            self.assertEqual(text.count('## '+s['source_id']+' —'),1)
        manifest = json.loads(outputs['MANIFEST.json'])
        for name,sha in manifest['files'].items():
            self.assertEqual(c.digest(outputs[name]),sha)


if __name__ == '__main__':
    unittest.main()
