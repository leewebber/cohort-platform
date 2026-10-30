#!/usr/bin/env python3
"""Source-specific review builder. No publication, catalogue seed or network port.

Null identities stay in REVIEW graphs only. admissible_strength_graphs refuses
before the private graph decoder, which is not a catalogue identity validator.
"""
import argparse
import copy
import csv
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
BASE = 'a22249e23a385ebb6064b8f05e3d2fb17af3914e'
SOURCE = ROOT / 'docs/programmes/hybrid_10k/general_draft_2026_10_30'
OUT = ROOT / 'docs/programmes/hybrid_10k/movement_review_2026_10_30'
WAVE = 'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql'
WAVE_HASH = '22a2683b81d09e071b99adda3c120dff06cb6410fcc4a2b53029beffca73d0c8'

PINNED_FILES = {'docs/programmes/hybrid_10k/general_draft_2026_10_30/SOURCE.json': '3a610154a8be27d31ecfe7cbf2fdfb16908a305e1bd35e1ada22b7e4b1bee486', 'docs/programmes/hybrid_10k/general_draft_2026_10_30/IDENTITY_INTAKE.json': '2229c3f72f3fba97de7dead7abe8ba6a172fa2293eff3f310fa2cef3f3306b10', 'docs/programmes/hybrid_10k/general_draft_2026_10_30/SCHEDULE_CANDIDATE.json': 'd60803201b0986f67f6ab8ce6a9d8693e74fbd5b94a6d23e4f6d3c4aa9d9a092', 'docs/programmes/hybrid_10k/general_draft_2026_10_30/RUNNING_BODIES.json': '3eaa1b932b9251c1ca5d6c299d856436a0291ff4d7ade2663155eebb30d02c60', 'docs/programmes/hybrid_10k/general_draft_2026_10_30/FOUNDER_CLARIFICATION.md': '8e16f59f8963efbc0db40b0c4b0532dcc4104e52ca6af391a604fa17cb5a48eb', 'docs/programmes/hybrid_10k/general_draft_2026_10_30/GENERAL_GUIDANCE.md': '1aabcb3034f88efb0d2a29e280ffc141b759371c9364c28015d2dc51c79370c3', 'docs/programmes/hybrid_10k/lee_draft_2026_10_28/SOURCE.md': 'd932e7103b03036e136249e0ab35d48378b0175c75feba84282386fc6ca00f40', 'docs/programmes/hybrid_10k/FOUNDER_BRIEF_2026_10_27.txt': '7de445cf0ac8d7e9082cb158c356b9f29c778b1df24da12c0090f7d7efb1c44a', 'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql': '22a2683b81d09e071b99adda3c120dff06cb6410fcc4a2b53029beffca73d0c8'}


def verify_pins():
    for name, expected in PINNED_FILES.items():
        if digest((ROOT / name).read_bytes()) != expected:
            raise ValueError("pinned_source_changed:" + name)


def encode(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read(name):
    return json.loads((SOURCE / name).read_text())


def repository_rows():
    raw = (ROOT / WAVE).read_bytes()
    if digest(raw) != WAVE_HASH:
        raise ValueError('catalogue_source_hash_mismatch')
    columns = ['exercise_id', 'name', 'slug', 'published', 'category',
               'movement_pattern', 'equipment', 'primary_muscles',
               'primary_capability', 'loading_options', 'purpose']
    wanted = {'EX-073', 'EX-078', 'EX-084', 'EX-095', 'EX-101', 'EX-114', 'EX-116', 'EX-125'}
    rows = {}
    for line in raw.decode().splitlines():
        match = re.match(r"\s*\(('EX-\d+'.*)\)[,;]?\s*$", line)
        if not match:
            continue
        values = next(csv.reader([match[1]], quotechar="'", skipinitialspace=True))
        if len(values) != len(columns):
            raise ValueError('malformed_catalogue_row')
        row = dict(zip(columns, values))
        row['published'] = row['published'] == 'true'
        if row['exercise_id'] in wanted:
            rows[row['exercise_id']] = {
                'catalogue_row': row, 'row_sql': line.strip(),
                'row_sha256': digest(encode(row).encode()),
                'source_path': WAVE, 'source_sha256': WAVE_HASH,
                'snapshot_git_revision': BASE,
                'classification': 'PINNED_LOCAL_V1_V2_ROW_NOT_CURRENT_HOSTED_PROOF',
                'canonical_definition_version': None, 'publication_event': None,
            }
    if set(rows) != wanted or not all(r['catalogue_row']['published'] for r in rows.values()):
        raise ValueError('missing_published_repository_row')
    return rows


# Decisions key unique variants; never infer mappings by display-name similarity.
DECISIONS = {
    'reverse_lunge_db': 'D4', 'pull_up_choice': 'D5',
    'db_overhead_press': 'D6', 'db_row_a': 'D7',
    'db_row_b': 'T1', 'db_lateral_raise': 'T2',
    'flat_db_bench': 'D1', 'single_leg_db_calf': 'D2', 'reverse_crunch': 'D3',
}
BOUND = {'back_squat': 'EX-073', 'barbell_rdl': 'EX-078',
         'db_farmer_carry': 'EX-101', 'side_plank': 'EX-116'}


def build():
    verify_pins()
    intake = read('IDENTITY_INTAKE.json')
    source = read('SOURCE.json')
    schedule = read('SCHEDULE_CANDIDATE.json')
    rows = repository_rows()
    source_pins = {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in [
        SOURCE / n for n in ['SOURCE.json', 'IDENTITY_INTAKE.json',
                             'SCHEDULE_CANDIDATE.json', 'RUNNING_BODIES.json',
                             'FOUNDER_CLARIFICATION.md', 'GENERAL_GUIDANCE.md']
    ]}
    for path in ['docs/programmes/hybrid_10k/lee_draft_2026_10_28/SOURCE.md',
                 'docs/programmes/hybrid_10k/FOUNDER_BRIEF_2026_10_27.txt', WAVE]:
        source_pins[path] = digest((ROOT / path).read_bytes())
    review = []
    occurrences = intake['occurrences']
    for session in source['sessions']:
        if session['type'] != 'strength':
            continue
        sid = session['session_id']
        reference = next(r for r in schedule['sessions'] if r['session_key'] == sid)
        links = []
        for position, item in enumerate([r for r in occurrences if r['session_id'] == sid], 1):
            expected = BOUND.get(item['variant_key'])
            if item['exercise_id'] != expected:
                raise ValueError('retained_binding_changed')
            links.append({
                'position': position, 'exercise_id': expected,
                'source_occurrence_id': item['source_occurrence_id'],
                'variant_key': item['variant_key'],
                'display_label_override': next(e['exercise'] for e in session['exercises']
                    if e['exercise_occurrence_id'] == item['source_occurrence_id']),
                'prescription': copy.deepcopy(item['prescription']),
                'hold_reference': None if expected else DECISIONS[item['variant_key']],
            })
        # Keep authored preparation as text: no invented canonical warm-up IDs or durations.
        prep = ('Apply retained strength preparation in GENERAL_GUIDANCE.md: '
                '5 min walk/march; 10 bodyweight squats, 8 unloaded hinges, '
                '8 scapular pull-ups OR shoulder-blade movements, 8 arm circles each way; '
                '2–4 progressive warm-up sets for first loaded lower-body exercise; '
                '1–2 light sets for each new upper-body pattern as needed; no failure.')
        if sid == 'LW10K-W10-D04':
            prep = ('Upper-body preparation only, per GENERAL_GUIDANCE.md. '
                    '1–2 light sets for each new upper-body pattern as needed; '
                    'no lower-body lifting or squat/hinge preparation; no failure.')
        review.append({
            'source_session_id': sid, 'protocol_id': reference['protocol_id'],
            'revision_number': reference['revision_number'],
            'classification': 'REVIEW_ONLY_WITHHELD_NOT_ADMISSIBLE',
            'blocks': [
                {'position': 1, 'block_type': 'warm_up', 'title': 'Retained preparation',
                 'content': prep, 'workout_format': 'none', 'exercises': []},
                {'position': 2, 'block_type': 'strength', 'title': session['title'],
                 'content': 'Proposed ordered work; retain shared tempo, load, fatigue and taper guidance.',
                 'workout_format': 'none', 'performance_capture_mode': 'auto', 'exercises': links},
                {'position': 3, 'block_type': 'cool_down', 'title': 'Retained finish',
                 'content': '3–5 minutes easy walking.', 'workout_format': 'none', 'exercises': []},
            ],
        })
    candidate_rows = {r['Exercise ID']: r for r in intake['candidate_export']['rows']}
    technical = {
        'T1': {'variant': 'db_row_b', 'candidate_id': 'EX-038',
               'source_setup': 'One dumbbell; unilateral; free hand supported on bench; rest after both sides; external kg per dumbbell.',
               'evidence_setup': 'One Dumbbell, Bench; pull elbow to hip, pause briefly, control lower; no shrug/twist/bounce.',
               'conclusion': 'EXACT_SETUP_CANDIDATE_TRUSTED_ROW_STILL_REQUIRED',
               'occurrences': 10},
        'T2': {'variant': 'db_lateral_raise', 'candidate_id': 'EX-044',
               'source_setup': 'Dumbbells; bilateral per-side=false; controlled both ways; no swinging; external kg per dumbbell.',
               'evidence_setup': 'One Dumbbell, Two Dumbbells; slight elbow bend, raise to shoulder height, control down; no swing/shrug.',
               'conclusion': 'EXACT_SETUP_CANDIDATE_TRUSTED_ROW_STILL_REQUIRED',
               'occurrences': 10},
    }
    return {
        'SOURCE_PINS.json': {'base': BASE, 'files': source_pins},
        'LOCAL_IDENTITY_EVIDENCE.json': {
            'scope': 'LOCAL_REVIEW_ONLY_NO_CATALOGUE_MUTATION',
            'repository_rows': rows,
            'current_slot_bindings': BOUND,
            'historical_export': {**intake['candidate_export'], 'runtime_seed': False},
            'completed_setup_comparisons': technical,
            'candidate_rows': candidate_rows,
            'new_verified_options_not_selected': ['EX-084', 'EX-114', 'EX-125'],
            'trusted_action': 'Retain an admissible exact v1/v2 row from the established trusted source. Historical CSV Published=Yes is insufficient. No v3 version/event is required by this path.',
        },
        'STRENGTH_REVIEW_GRAPHS.json': review,
    }


def admissible_strength_graphs(graphs):
    """Fail closed on authored changes/forged flags, not merely non-null IDs.

    This is a source-review guard, not a replacement for trusted intake or
    publication authorization. No review object is allowed to select a new ID.
    """
    expected = build()['STRENGTH_REVIEW_GRAPHS.json']
    if graphs != expected:
        raise ValueError('movement_review_not_exact_pinned_source')
    missing = [e['source_occurrence_id'] for g in graphs for b in g['blocks']
               for e in b['exercises'] if e['exercise_id'] is None]
    if missing:
        raise ValueError(f'movement_identity_or_selection_required:{len(missing)}')
    raise ValueError('remaining_content_review_required')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, value in build().items():
        data = encode(value)
        if args.check:
            if (OUT / name).read_text() != data:
                raise SystemExit(f'Stale review artifact: {name}')
        else:
            (OUT / name).write_text(data)
    print('Review artifacts match retained source' if args.check else 'Built 20 withheld strength review graphs')


if __name__ == '__main__':
    main()
