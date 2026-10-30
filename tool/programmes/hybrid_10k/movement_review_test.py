"""Focused fail-closed controls for the real, pinned draft; no DB/network."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_movement_review as review


class MovementReviewTest(unittest.TestCase):
    def test_review_retains_all_twenty_graphs_and_exact_occurrences(self):
        built = review.build()
        graphs = built['STRENGTH_REVIEW_GRAPHS.json']
        intake = review.read('IDENTITY_INTAKE.json')
        links = [e for g in graphs for b in g['blocks'] for e in b['exercises']]
        self.assertEqual(len(graphs), 20)
        self.assertEqual(len(links), 124)
        self.assertEqual(sum(e['prescription']['sets'] for e in links), 263)
        self.assertEqual(sum(e['exercise_id'] is not None for e in links), 37)
        for expected, actual in zip(intake['occurrences'], links):
            self.assertEqual(actual['source_occurrence_id'], expected['source_occurrence_id'])
            self.assertEqual(actual['prescription'], expected['prescription'])
        with self.assertRaisesRegex(ValueError, '^movement_identity_or_selection_required:87$'):
            review.admissible_strength_graphs(graphs)

    def test_similar_id_cannot_fill_missing_identity(self):
        graphs = copy.deepcopy(review.build()['STRENGTH_REVIEW_GRAPHS.json'])
        for g in graphs:
            for b in g['blocks']:
                for e in b['exercises']:
                    if e['variant_key'] == 'flat_db_bench':
                        e['exercise_id'] = 'EX-084'  # incline is not flat
        with self.assertRaisesRegex(ValueError, 'movement_review_not_exact_pinned_source'):
            review.admissible_strength_graphs(graphs)

    def test_candidate_csv_is_not_admitted_by_inserting_id(self):
        graphs = copy.deepcopy(review.build()['STRENGTH_REVIEW_GRAPHS.json'])
        for g in graphs:
            for b in g['blocks']:
                for e in b['exercises']:
                    if e['variant_key'] == 'db_row_b':
                        e['exercise_id'] = 'EX-038'
        with self.assertRaisesRegex(ValueError, 'movement_review_not_exact_pinned_source'):
            review.admissible_strength_graphs(graphs)

    def test_forged_approval_or_missing_occurrence_refuses(self):
        expected = review.build()['STRENGTH_REVIEW_GRAPHS.json']
        for change in ['approval', 'remove', 'dose', 'reorder']:
            graphs = copy.deepcopy(expected)
            if change == 'approval':
                graphs[0]['approved'] = True
            elif change == 'remove':
                graphs[0]['blocks'][1]['exercises'].pop(0)
            elif change == 'dose':
                graphs[0]['blocks'][1]['exercises'][0]['prescription']['sets'] = 99
            else:
                graphs[0]['blocks'][1]['exercises'].reverse()
            with self.subTest(change=change), self.assertRaises(ValueError):
                review.admissible_strength_graphs(graphs)

    def test_changed_source_or_catalogue_is_not_repinned_silently(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for relative in review.PINNED_FILES:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((review.ROOT / relative).read_bytes())
            for relative in ['docs/programmes/hybrid_10k/general_draft_2026_10_30/SOURCE.json', review.WAVE]:
                target = root / relative
                original = target.read_bytes()
                target.write_bytes(original + b' ')
                with patch.object(review, 'ROOT', root), self.assertRaisesRegex(ValueError, 'pinned_source_changed'):
                    review.build()
                target.write_bytes(original)

    def test_proposals_cannot_be_read_as_published_definitions(self):
        proposals = json.loads((review.OUT / 'PROPOSED_IDENTITIES.json').read_text())
        self.assertEqual(len(proposals['records']), 6)
        for p in proposals['records']:
            self.assertFalse(p['approved'])
            self.assertIsNone(p['publication_event'])
            self.assertIsNone(p['content_approval'])
            for key in ['definition_template', 'movement_standard_template']:
                self.assertIsNone(p[key]['id'])
                self.assertIsNone(p[key]['version'])
                self.assertEqual(p[key]['lifecycle_status'], 'draft')

    def test_options_remain_options_and_setup_matches_remain_candidates(self):
        e = review.build()['LOCAL_IDENTITY_EVIDENCE.json']
        self.assertEqual(e['new_verified_options_not_selected'], ['EX-084', 'EX-114', 'EX-125'])
        self.assertEqual(set(e['current_slot_bindings'].values()), {'EX-073', 'EX-078', 'EX-101', 'EX-116'})
        self.assertEqual(sum(x['occurrences'] for x in e['completed_setup_comparisons'].values()), 20)
        self.assertFalse(e['historical_export']['runtime_seed'])


if __name__ == '__main__':
    unittest.main()
