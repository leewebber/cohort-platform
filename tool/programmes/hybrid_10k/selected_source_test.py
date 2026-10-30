import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import apply_strength_selections as source
import render_selected_review as readable


class SelectedSourceTest(unittest.TestCase):
    def test_exact_standard_doses_days_and_setups(self):
        expected = {
            'barbell_rdl': (4, 2, '5–6', '2–3', '120–180'),
            'incline_db_press': (1, 3, '6–10', '2', '120'),
            'pull_up_bodyweight': (1, 3, '5–8', '2', '120'),
            'chest_supported_db_row': (1, 3, '8–12', '1–2', '90'),
            'db_lateral_raise': (1, 3, '12–20', '1–2', '60'),
            'cable_pallof_square': (1, 2, '10/side', 'N/A', '45–60'),
            'reverse_lunge_db': (4, 1, '6/leg', '2–3', '90'),
            'seated_supported_db_press': (4, 3, '6–10', '2', '120'),
            'bench_supported_db_row': (4, 3, '8–12/side', '1–2', '90'),
            'machine_standing_calf': (4, 2, '10–15', '2', '60–90'),
            'side_plank': (4, 2, '30–45 sec/side', 'N/A', '45–60'),
        }
        data = source.build()
        for s in data['SOURCE.json']['sessions']:
            if s['type'] != 'strength' or s['week'] not in [1, 2, 3, 5, 6, 7]:
                continue
            for e in s['exercises']:
                self.assertEqual((s['day'], e['sets'], e['repetitions_or_duration'], e['rir'], e['rest_seconds']), expected[e['variant_key']])
        standard = source.standards()
        self.assertIn('30°', standard['incline_db_press']['notes'])
        self.assertIn('square stance', standard['cable_pallof_square']['notes'])
        self.assertIn('without leg drive', standard['seated_supported_db_press']['notes'])
        self.assertIn('no unilateral DB', standard['machine_standing_calf']['notes'])
        for key in ['side_plank', 'cable_pallof_square']:
            self.assertNotIn('rir_range', source.native({**standard[key], 'exercise_occurrence_id': 'local-source-probe'}))

    def test_selected_rdl_and_working_sets_are_separate_from_preparation(self):
        data = source.build()
        exercises = [e for s in data['SOURCE.json']['sessions'] for e in s.get('exercises', [])]
        forbidden = ['Barbell back squat', 'DB farmer carry', 'DB bench press', 'Standing single-leg DB calf raise', 'Reverse crunch']
        self.assertFalse(any(e['exercise'] in forbidden for e in exercises))
        self.assertEqual(len(exercises), 105)
        self.assertEqual(data['AUDIT.json']['rdl_membership'], 'EXPLICITLY_SELECTED')
        self.assertEqual(data['AUDIT.json']['weekly_strength_work_sets'], [27,27,27,21,27,27,27,27,16,12])
        self.assertEqual(sum(e['sets'] for e in exercises), 238)
        self.assertTrue(all(not e['content_holds'] and e['effective_prescription'] is not None for e in exercises))
        for g in data['STRENGTH_REVIEW_GRAPHS.json']:
            self.assertEqual(g['blocks'][0]['exercises'], [])
            self.assertEqual(g['blocks'][2]['exercises'], [])
        self.assertIn('10 bodyweight squats', data['STRENGTH_REVIEW_GRAPHS.json'][0]['blocks'][0]['content'])
        self.assertEqual([len(r['occurrences']) for r in data['AUDIT.json']['removed_working_carryovers']], [9, 9])

    def test_exact_selected_week_rules_effort_rests_and_no_old_w7_reductions(self):
        data = source.build()
        standard = source.standards()
        def rows(week, day=None):
            return {e['variant_key']:e for s in data['SOURCE.json']['sessions'] if s['week']==week and s['type']=='strength' and (day is None or s['day']==day) for e in s['exercises']}
        fields = ['sets','repetitions_or_duration','rir','rest_seconds']
        for key,e in rows(7).items():
            self.assertEqual([e[x] for x in fields], [standard[key][x] for x in fields])
        self.assertNotIn('consolid', data['SOURCE.json']['weeks'][6]['focus'].lower())
        self.assertEqual(data['SCHEDULE_CANDIDATE.json']['weeks'][6]['title'], data['SOURCE.json']['weeks'][6]['focus'])
        self.assertTrue(all(not e['retained_reduction_proposals'] for s in data['SOURCE.json']['sessions'] for e in s.get('exercises', [])))
        for key,e in rows(4).items():
            self.assertEqual(e['sets'], 2 if standard[key]['sets']==3 else standard[key]['sets'])
            for f in fields[1:]: self.assertEqual(e[f],standard[key][f])
        self.assertFalse(rows(4)['barbell_rdl']['planned_load_increase'])
        self.assertEqual([rows(8)['barbell_rdl'][f] for f in fields], [2,'5','3','120–180'])
        self.assertEqual([rows(8)['reverse_lunge_db'][f] for f in fields], [1,'6/leg','3','90'])
        for key in ['barbell_rdl','reverse_lunge_db','machine_standing_calf']:
            e=rows(8)[key]
            self.assertFalse(e['planned_load_increase'])
            self.assertFalse(e['reference_prescription']['authored_details']['planned_load_increase'])
        self.assertNotIn('reverse_lunge_db',rows(9))
        self.assertEqual([rows(9)['barbell_rdl'][f] for f in fields], [1,'5','3','120–180'])
        for key,e in rows(9).items():
            if key=='barbell_rdl':continue
            self.assertEqual(e['sets'],2 if standard[key]['sets']==3 else 1)
            for f in fields[1:]: self.assertEqual(e[f],standard[key][f])
        for key,e in rows(10,1).items():
            self.assertEqual(e['sets'],1 if key in ['db_lateral_raise','cable_pallof_square'] else 2)
            for f in fields[1:]: self.assertEqual(e[f],standard[key][f])
        self.assertEqual(set(rows(10,4)),{'seated_supported_db_press','bench_supported_db_row'})
        for key,e in rows(10,4).items():
            self.assertEqual(e['sets'],2)
            self.assertEqual(e['rir'],'at least 3')
            self.assertNotIn('rir_range',e['reference_prescription'])
            self.assertEqual(e['rest_seconds'],'120' if key=='seated_supported_db_press' else '90')
        self.assertEqual(data['AUDIT.json']['content_hold_counts'],{})

    def test_timed_running_and_distance_identity_targets_order_unchanged(self):
        data = source.build()
        for before, after in zip(source.load('RUNNING_BODIES.json'), data['RUNNING_BODIES.json']):
            for key in ['source_session_id', 'source_week', 'source_day', 'fixed_seconds', 'distance_metres']:
                self.assertEqual(before[key], after[key])
            self.assertEqual(before['workout']['steps'], after['workout']['steps'])
            steps = after['workout']['steps']
            fixed = sum(s['duration'].get('milliseconds', 0) for s in steps) // 1000
            self.assertEqual(fixed, after['fixed_seconds'])
        weeks = data['AUDIT.json']['weekly_running']
        self.assertEqual([w['fixed_workout_seconds'] for w in weeks], [6600, 7200, 8460, 8250, 9840, 10500, 8760, 11040, 9300, 6360])
        self.assertEqual([w['threshold_seconds'] + w['ten_k_specific_seconds'] for w in weeks], [0, 0, 720, 1200, 1080, 1440, 960, 1620, 1080, 360])
        self.assertEqual([w['distance_ended_metres'] for w in weeks], [0]*9 + [10000])
        self.assertEqual(weeks[9]['running_seconds_range_if_permitted_recoveries_walked'], [5240, 6360])
        self.assertEqual(len(data['AUDIT.json']['removed_personal_notes']), 1)

    def test_human_review_covers_every_session_exact_doses_and_rule_behaviour(self):
        data = source.build()
        review = readable.render()
        for s in data['SOURCE.json']['sessions']:
            self.assertEqual(review.count(f"Review reference: `{s['session_id']}`"), 1)
            for e in s.get('exercises', []):
                self.assertIn(readable.dose(e), review)
        for phrase in ['0 through 56 local civil days inclusive', 'alpha_manual_threshold_pm2_v1', 'exact halves upward', 'Phase labels — reconciled together', 'D8 remains pending', '10,000 metres — DISTANCE-ENDED']:
            self.assertIn(phrase, review)
        self.assertNotIn('RETAINED TARGET REQUIRING REVIEW', review)
        self.assertNotIn('### Saturday — Rest / travel', review)

    def test_untrusted_candidates_and_assisted_branches_cannot_gain_authority(self):
        data = source.build()
        e = data['IDENTITY_INTAKE.json']
        self.assertEqual(sum(b['exercise_id'] is not None for b in e['occurrences']), 77)
        self.assertEqual(sum(b['exercise_id'] is None for b in e['occurrences']), 28)
        self.assertEqual(len(e['assisted_branches']), 2)
        self.assertFalse(e['weighted_option']['selected'])
        graphs = data['STRENGTH_REVIEW_GRAPHS.json']
        result = source.admission_preflight(graphs)
        self.assertFalse(result['admitted'])
        self.assertEqual(result['unique_content_holds'], [])
        for key, fake in [('chest_supported_db_row', 'EX-090'), ('seated_supported_db_press', 'EX-037'), ('pull_up_bodyweight', 'EX-095')]:
            changed = copy.deepcopy(graphs)
            next(x for g in changed for b in g['blocks'] for x in b['exercises'] if x['variant_key'] == key)['exercise_id'] = fake
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'not_exact_selected_source_review'):
                source.admission_preflight(changed)
        changed = copy.deepcopy(graphs)
        changed[0]['approved'] = True
        with self.assertRaises(ValueError):
            source.admission_preflight(changed)

    def test_changed_selection_or_trusted_row_bytes_refuse_without_mutating_sources(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old = root / 'old'
            out = root / 'new'
            old.mkdir(); out.mkdir()
            for name in source.PINS:
                (old / name).write_bytes((source.OLD / name).read_bytes())
            (out / 'FOUNDER_SELECTIONS.md').write_bytes((source.OUT / 'FOUNDER_SELECTIONS.md').read_bytes())
            (out / 'DOSE_CLARIFICATIONS.md').write_bytes((source.OUT / 'DOSE_CLARIFICATIONS.md').read_bytes())
            wave = root / source.WAVE
            wave.parent.mkdir(parents=True)
            wave.write_bytes((source.ROOT / source.WAVE).read_bytes())
            with patch.object(source, 'ROOT', root), patch.object(source, 'OLD', old), patch.object(source, 'OUT', out):
                source.verify_pins()
                for path in [out / 'FOUNDER_SELECTIONS.md', out / 'DOSE_CLARIFICATIONS.md', wave, old / 'SOURCE.json']:
                    before = path.read_bytes()
                    path.write_bytes(before + b' ')
                    with self.assertRaises(ValueError):
                        source.verify_pins()
                    path.write_bytes(before)


if __name__ == '__main__':
    unittest.main()
