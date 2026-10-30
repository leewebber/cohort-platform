import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import apply_strength_selections as source
import trusted_catalogue_snapshot as trusted


class TrustedCatalogueSnapshotTest(unittest.TestCase):
    def test_exact_authenticated_scope_and_three_curated_matches(self):
        rows, receipt = trusted.load_snapshot(source.ROOT)
        self.assertEqual(set(rows), {'EX-026','EX-037','EX-038','EX-044','EX-053','EX-090'})
        self.assertEqual(receipt['rows'], 6)
        self.assertFalse(receipt['row_cap_reached'])
        evidence = trusted.row_evidence(source.ROOT)
        self.assertEqual(set(evidence), {'EX-038','EX-044','EX-053'})
        for identity, record in evidence.items():
            self.assertEqual(record['catalogue_row'], rows[identity])
            self.assertIsNone(record['catalogue_row']['setup'])
            self.assertIsNone(record['catalogue_row']['unilateral'])
            self.assertIsNone(record['catalogue_row']['loading_options'])
            self.assertIsNone(record['canonical_definition_version'])
            self.assertIsNone(record['publication_event'])
            self.assertFalse(record['global_catalogue_seed'])

    def test_raw_receipt_target_query_or_row_tampering_refuses(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / trusted.DIRECTORY
            target.mkdir(parents=True)
            for name in trusted.PINS:
                (target/name).write_bytes((source.ROOT/trusted.DIRECTORY/name).read_bytes())
            trusted.load_snapshot(root)
            for name in trusted.PINS:
                path = target/name
                original = path.read_bytes()
                path.write_bytes(original+b' ')
                with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'trusted_snapshot_integrity_mismatch'):
                    trusted.load_snapshot(root)
                path.write_bytes(original)

    def test_coaching_and_all_running_bodies_are_byte_identical_to_approved_base(self):
        built = source.build()
        for name in ['SOURCE.json','RUNNING_BODIES.json']:
            relative = str((source.OUT/name).relative_to(source.ROOT))
            previous = subprocess.check_output(['git','show','b220f42:'+relative],cwd=source.ROOT)
            self.assertEqual(source.encode(built[name]).encode(), previous, name)

    def test_only_retrieved_exact_matches_bind_and_no_complete_workout_is_fabricated(self):
        built = source.build()
        bindings = built['IDENTITY_INTAKE.json']['occurrences']
        for b in bindings:
            if b['variant_key'] in trusted.DIRECT_MATCHES:
                self.assertEqual(b['exercise_id'], trusted.DIRECT_MATCHES[b['variant_key']])
            if b['variant_key'] in {'chest_supported_db_row','seated_supported_db_press','reverse_lunge_db'}:
                self.assertIsNone(b['exercise_id'])
        self.assertEqual(sum(b['exercise_id'] is not None for b in bindings), 77)
        graphs = built['STRENGTH_REVIEW_GRAPHS.json']
        self.assertTrue(all(any(e['exercise_id'] is None for b in g['blocks'] for e in b['exercises']) for g in graphs))
        result = source.admission_preflight(graphs)
        self.assertFalse(result['admitted'])
        self.assertEqual(result['full_strength_graphs_admitted'], 0)
        self.assertEqual(result['unique_content_holds'], [])
        for key, identity in [('chest_supported_db_row','EX-090'),('seated_supported_db_press','EX-037'),('reverse_lunge_db','EX-026')]:
            changed = copy.deepcopy(graphs)
            next(e for g in changed for b in g['blocks'] for e in b['exercises'] if e['variant_key']==key)['exercise_id']=identity
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'not_exact_selected_source_review'):
                source.admission_preflight(changed)

    def test_proposals_preserve_null_facts_and_cannot_create_publication_authority(self):
        proposals=json.loads((source.ROOT/trusted.DIRECTORY/'SETUP_PROPOSALS.json').read_text())
        self.assertEqual(len(proposals['records']),3)
        for p in proposals['records']:
            self.assertFalse(p['applied'])
            for key in ['new_exercise_id','canonical_definition_version','publication_event','founder_or_publisher_approval_event']:
                self.assertIsNone(p[key])
        row=next(p for p in proposals['records'] if p['existing_candidate_id']=='EX-026')['existing_published_row_observed']
        self.assertIsNone(row['equipment'])
        self.assertIsNone(row['setup'])


if __name__=='__main__':
    unittest.main()
