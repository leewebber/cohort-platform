#!/usr/bin/env python3
"""Bounded genuine-source reconciliation. No catalogue/DB/publication ports.

New selections replace source variants, never manufacture identity evidence.
Reference doses are distinct from unresolved effective consolidation/taper doses.
"""
import argparse
import collections
import copy
import csv
import hashlib
import json
from pathlib import Path
import re

import reconcile_general_source as prior

ROOT = Path(__file__).resolve().parents[3]
OLD = ROOT / 'docs/programmes/hybrid_10k/general_draft_2026_10_30'
OUT = ROOT / 'docs/programmes/hybrid_10k/founder_selected_2026_10_30'
BASE = '15627ecd7c41ab0f5f593ba6a08075374f7316fe'
PINS = {
    'SOURCE.json': '3a610154a8be27d31ecfe7cbf2fdfb16908a305e1bd35e1ada22b7e4b1bee486',
    'RUNNING_BODIES.json': '3eaa1b932b9251c1ca5d6c299d856436a0291ff4d7ade2663155eebb30d02c60',
    'SCHEDULE_CANDIDATE.json': 'd60803201b0986f67f6ab8ce6a9d8693e74fbd5b94a6d23e4f6d3c4aa9d9a092',
    'GENERAL_GUIDANCE.md': '1aabcb3034f88efb0d2a29e280ffc141b759371c9364c28015d2dc51c79370c3',
    'IDENTITY_INTAKE.json': '2229c3f72f3fba97de7dead7abe8ba6a172fa2293eff3f310fa2cef3f3306b10',
}
SELECTION_HASH = 'dd7e08cc1b026b46307b42c491216543899879e202c3f665ce837f486bc0d6d8'
DOSE_HASH = 'e38cba504a1b40dcfe93e1fa72cee4b1804b0f4bee5078e7e240e41df9457b76'
WAVE = 'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql'
WAVE_HASH = '22a2683b81d09e071b99adda3c120dff06cb6410fcc4a2b53029beffca73d0c8'
BOUND = {'incline_db_press': 'EX-084', 'cable_pallof_square': 'EX-114',
         'machine_standing_calf': 'EX-125', 'side_plank': 'EX-116',
         'barbell_rdl': 'EX-078'}
CANDIDATES = {'pull_up_bodyweight': 'EX-053', 'chest_supported_db_row': 'EX-090',
              'db_lateral_raise': 'EX-044', 'bench_supported_db_row': 'EX-038',
              'seated_supported_db_press': 'EX-037', 'reverse_lunge_db': None}
MONDAY = ['incline_db_press', 'pull_up_bodyweight', 'chest_supported_db_row',
          'db_lateral_raise', 'cable_pallof_square']
THURSDAY = ['barbell_rdl', 'reverse_lunge_db', 'seated_supported_db_press',
            'bench_supported_db_row', 'machine_standing_calf', 'side_plank']


def encode(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def load(name):
    return json.loads((OLD / name).read_text())


def verify_pins():
    for name, expected in PINS.items():
        if sha((OLD / name).read_bytes()) != expected:
            raise ValueError('retained_source_changed:' + name)
    if sha((OUT / 'FOUNDER_SELECTIONS.md').read_bytes()) != SELECTION_HASH:
        raise ValueError('founder_selection_changed')
    if sha((OUT / 'DOSE_CLARIFICATIONS.md').read_bytes()) != DOSE_HASH:
        raise ValueError('founder_dose_clarification_changed')
    if sha((ROOT / WAVE).read_bytes()) != WAVE_HASH:
        raise ValueError('trusted_row_source_changed')


def rows():
    columns = ['exercise_id', 'name', 'slug', 'published', 'category', 'movement_pattern',
               'equipment', 'primary_muscles', 'primary_capability', 'loading_options', 'purpose']
    result = {}
    for line in (ROOT / WAVE).read_text().splitlines():
        match = re.match(r"\s*\(('EX-\d+'.*)\)[,;]?\s*$", line)
        if not match:
            continue
        values = next(csv.reader([match[1]], quotechar="'", skipinitialspace=True))
        if len(values) != len(columns):
            raise ValueError('malformed_trusted_row')
        row = dict(zip(columns, values))
        row['published'] = row['published'] == 'true'
        if row['exercise_id'] in set(BOUND.values()) | {'EX-090', 'EX-095'}:
            result[row['exercise_id']] = {
                'catalogue_row': row, 'row_sql': line.strip(),
                'row_sha256': sha(encode(row).encode()), 'source_path': WAVE,
                'source_sha256': WAVE_HASH, 'snapshot_git_revision': BASE,
                'canonical_definition_version': None, 'publication_event': None,
                'hosted_state': 'UNVERIFIED',
            }
    assert len(result) == 7 and all(r['catalogue_row']['published'] for r in result.values())
    return result


def exercise(key, label, sets, reps, rir, rest, notes, decision, tempo=None):
    return {'variant_key': key, 'exercise': label, 'sets': sets,
            'repetitions_or_duration': reps, 'rir': rir, 'rest_seconds': rest,
            'notes': notes, 'tempo': tempo or 'Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift',
            'authority': decision, 'dose_status': 'FOUNDER_SELECTED_STANDARD',
            'effective_dose_status': 'SELECTED_STANDARD_NO_REDUCTION_CONFLICT',
            'effective_prescription': None, 'content_holds': [],
            'retained_reduction_proposals': []}


def standards():
    return {
        'barbell_rdl': exercise('barbell_rdl', 'Barbell Romanian deadlift', 2, '5–6', '2–3', '120–180',
            'Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected.', 'RDL clarification'),
        'incline_db_press': exercise('incline_db_press', 'Bilateral incline DB press', 3, '6–10', '2', '120',
            'Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell.', 'D1'),
        'pull_up_bodyweight': exercise('pull_up_bodyweight', 'Strict bodyweight pull-up', 3, '5–8', '2', '120',
            'Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate.', 'D5'),
        'chest_supported_db_row': exercise('chest_supported_db_row', 'Bilateral chest-supported DB row', 3, '8–12', '1–2', '90',
            'Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute.', 'D7'),
        'db_lateral_raise': exercise('db_lateral_raise', 'DB lateral raise', 3, '12–20', '1–2', '60',
            'Bilateral dumbbells; no swinging. Log external load per dumbbell.', 'D7', 'Controlled both ways'),
        'cable_pallof_square': exercise('cable_pallof_square', 'Square-stance cable Pallof press', 2, '10/side', 'N/A', '45–60',
            'Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR.', 'D3', 'Controlled execution'),
        'reverse_lunge_db': exercise('reverse_lunge_db', 'DB reverse lunge', 1, '6/leg', '2–3', '90',
            'Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell.', 'D4'),
        'seated_supported_db_press': exercise('seated_supported_db_press', 'Seated back-supported neutral-grip DB press', 3, '6–10', '2', '120',
            'Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell.', 'D6'),
        'bench_supported_db_row': exercise('bench_supported_db_row', 'Bench-supported single-arm DB row', 3, '8–12/side', '1–2', '90',
            'Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell.', 'D7'),
        'machine_standing_calf': exercise('machine_standing_calf', 'Bilateral machine standing calf raise', 2, '10–15', '2', '60–90',
            'Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence.', 'D2', '~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)'),
        'side_plank': exercise('side_plank', 'Bodyweight side plank', 2, '30–45 sec/side', 'N/A', '45–60',
            'Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement.', 'D3', 'Controlled hold; stop before posture loss'),
    }


def native(e):
    # Reuse existing range/side/rest/RIR parsing, then set exact authored setup.
    p = prior.prescription(e)
    p['tempo'] = e['tempo']
    p['authored_details'].update(selection=e['authority'], variant_key=e['variant_key'],
                                source_dose_status=e['dose_status'])
    if e.get('planned_load_increase') is False:
        p['authored_details']['planned_load_increase'] = False
    if e['variant_key'] == 'machine_standing_calf':
        p['load'] = {'type': 'athleteSelected'}
        p['performance_capture'] = {'load_label': 'Machine-indicated resistance; retain actual unit and setup'}
    elif e['variant_key'] == 'cable_pallof_square':
        p['load'] = {'type': 'athleteSelected'}
        p['performance_capture'] = {'load_label': 'Cable-indicated external resistance; retain actual unit and setup'}
    elif e['variant_key'] == 'pull_up_bodyweight':
        p.pop('load', None)
        p['performance_capture'] = {'load_label': 'Added external load only after supported weighted-identity selection'}
    return p


def apply_week_dose(e, week, day):
    """Apply the selected week rules, never old occurrence-dose transfers."""
    key = e['variant_key']
    if week in {4, 9} and e['sets'] == 3:
        e['sets'] = 2
    if week == 4 and key == 'barbell_rdl':
        e['planned_load_increase'] = False
    if week == 8:
        if key == 'barbell_rdl':
            e.update(repetitions_or_duration='5', rir='3')
        elif key == 'reverse_lunge_db':
            e['rir'] = '3'
        if key in {'barbell_rdl', 'reverse_lunge_db', 'machine_standing_calf'}:
            e['planned_load_increase'] = False
    if week == 9:
        if key == 'barbell_rdl':
            e.update(sets=1, repetitions_or_duration='5', rir='3')
        elif key in {'machine_standing_calf', 'cable_pallof_square', 'side_plank'}:
            e['sets'] = 1
    if week == 10:
        if day == 1:
            e['sets'] = {'pull_up_bodyweight': 2, 'incline_db_press': 2,
                         'chest_supported_db_row': 2, 'db_lateral_raise': 1,
                         'cable_pallof_square': 1}[key]
        else:
            e.update(sets=2, rir='at least 3')
            e['notes'] += ' Comfortable upper-body work; at least 3 RIR, no invented upper bound; no lower-body lifting or additional working exercises.'
    if week in {4, 8, 9, 10}:
        e['dose_status'] = 'FOUNDER_SELECTED_WEEK_SPECIFIC_DOSE'
        e['authority'] += '; DOSE_CLARIFICATIONS.md'
    e['effective_dose_status'] = 'EXACT_SELECTED_DOSE_FULL_PROGRAMME_D8_PENDING'
    if e.get('planned_load_increase') is False:
        e['notes'] += ' No planned load increase this week.'
    return e


def build():
    verify_pins()
    original = load('SOURCE.json')
    source = copy.deepcopy(original)
    source.update(source_schema='hybrid10k-founder-selected-review/3',
                  title='General Hybrid 10K PB — founder-selected strength, D8 review pending',
                  content_status='D1_D7_AND_WEEK_DOSES_SELECTED_D8_PENDING',
                  shared_rules_location='TEN_WEEK_REVIEW.md in this source directory',
                  authority_source='FOUNDER_SELECTIONS.md + DOSE_CLARIFICATIONS.md', publication_approved=False)
    phase_focus = {4: 'Consolidation in W4; selected running retained',
                   5: 'Build W5–7; threshold duration and endurance',
                   6: 'Build W5–7; repeatable threshold work',
                   7: 'Build W5–7; standard strength; selected running retained',
                   8: 'Control lower-body effort; selected 10K-specific running retained',
                   9: 'Reduce workload; selected running retained',
                   10: 'Reduce workload and sharpen; final 10K test'}
    for w in source['weeks']:
        if w['week'] in phase_focus:
            w['focus'] = phase_focus[w['week']]
    standard = standards()
    bindings, graphs = [], []
    for s in source['sessions']:
        if s['type'] != 'strength':
            continue
        week, day = s['week'], s['day']
        keys = MONDAY if day == 1 else (['seated_supported_db_press', 'bench_supported_db_row'] if week == 10 else THURSDAY)
        if week == 9 and day == 4:
            keys = [key for key in keys if key != 'reverse_lunge_db']
        exercises = []
        for key in keys:
            e = copy.deepcopy(standard[key])
            e['exercise_occurrence_id'] = f'W{week:02}-{"A" if day == 1 else "B"}-{key}'
            apply_week_dose(e, week, day)
            p = native(e)
            if not e['content_holds']:
                e['effective_prescription'] = copy.deepcopy(p)
            e['reference_prescription'] = p
            exercises.append(e)
            bindings.append({'session_id': s['session_id'], 'source_occurrence_id': e['exercise_occurrence_id'],
                'variant_key': key, 'exercise_id': BOUND.get(key), 'candidate_exercise_id': CANDIDATES.get(key),
                'identity_status': 'VERIFIED_LOCAL_LEGACY_ROW_MATCH' if key in BOUND else 'UNRESOLVED_EXACT_IDENTITY',
                'content_holds': e['content_holds'], 'dose_status': e['dose_status'],
                'effective_dose_status': e['effective_dose_status'], 'prescription': p,
                'effective_prescription': e['effective_prescription']})
        s.update(exercises=exercises, title='Monday selected strength' if day == 1 else 'Thursday selected strength' if week != 10 else 'Upper-body taper exception',
                 content_status='SELECTED_MOVEMENTS_STANDARD_DOSES_D8_PENDING', expected_duration_minutes=None,
                 instructions=['Review order shown; within-session order remains part of D8 review. Preparation and warm-up sets are separate from working sets.'])
        prep = ('Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; '
                '8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. '
                'First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. '
                'Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.')
        if week == 10 and day == 4:
            prep = 'Upper-body preparation only; 1–2 light sets per new upper-body pattern as needed, no failure. No lower-body lifting or squat/hinge warm-up inserted.'
        graphs.append({'source_session_id': s['session_id'], 'protocol_id': s['session_id'] + '-DRAFT-R3',
            'revision_number': 3, 'classification': 'REVIEW_ONLY_NOT_ADMITTED_OR_PUBLISHED',
            'blocks': [
                {'position': 1, 'block_type': 'warm_up', 'title': 'Preparation', 'content': prep, 'workout_format': 'none', 'exercises': []},
                {'position': 2, 'block_type': 'strength', 'title': s['title'], 'content': 'Exact founder-selected standard and week-specific doses; full programme D8 review pending.',
                 'workout_format': 'none', 'performance_capture_mode': 'auto', 'exercises': [
                    {'position': i, 'exercise_id': BOUND.get(e['variant_key']), 'variant_key': e['variant_key'],
                     'source_occurrence_id': e['exercise_occurrence_id'], 'display_label_override': e['exercise'],
                     'prescription': e['reference_prescription'], 'content_holds': e['content_holds'],
                     'effective_dose_status': e['effective_dose_status']} for i, e in enumerate(exercises, 1)]},
                {'position': 3, 'block_type': 'cool_down', 'title': 'Finish', 'content': '3–5 minutes easy walking; retained proposed finish.', 'workout_format': 'none', 'exercises': []},
            ]})
    # Correct a demonstrable general-scope transfer error in notes only. No run
    # duration, phase, target, identity, repetition or placement changes.
    removed_personal_notes = []
    runs = copy.deepcopy(load('RUNNING_BODIES.json'))
    for s in source['sessions']:
        if s['type'] == 'rest' and s['title'] == 'Rest / travel':
            s['title'] = 'Rest'
        if s['type'] != 'running':
            continue
        rejected = [n for n in s['notes'] if n.startswith('Travel variant:')]
        if rejected:
            s['notes'] = [n for n in s['notes'] if n not in rejected]
            removed_personal_notes.append({'session_id': s['session_id'], 'notes': rejected, 'reason': 'General PB scope already excludes Lee-specific travel variants; base 40-minute run unchanged.'})
            body = next(r for r in runs if r['source_session_id'] == s['session_id'])
            for n in rejected:
                body['workout']['notes'] = body['workout']['notes'].replace(n, '')
            body['workout']['notes'] = body['workout']['notes'].rstrip()
    schedule = load('SCHEDULE_CANDIDATE.json')
    schedule['programme'].update(name=source['title'], description='D1–D7 founder-selected standard strength; reductions/content/identity review pending. Unpublished genuine draft.')
    for ref in schedule['sessions']:
        s = next(s for s in source['sessions'] if s['session_id'] == ref['session_key'])
        if s['type'] == 'strength':
            ref.update(protocol_id=s['session_id'] + '-DRAFT-R3', revision_number=3, title=s['title'])
    for w in schedule['weeks']:
        w['title'] = source['weeks'][w['week_number'] - 1]['focus']
        for day in w['days']:
            day_source = next(s for s in source['sessions'] if s['week'] == w['week_number'] and s['day'] == day['day_order'])
            day['title'] = day_source['title']
            for slot in day['slots']:
                if any(g['source_session_id'] == slot['session_key'] for g in graphs):
                    slot['display_title'] = day_source['title']
                    slot['progression']['prescription_summary'] = 'D1–D7 plus exact founder-selected week doses; D8 full-programme review in TEN_WEEK_REVIEW.md. No automatic progression.'
    statistics = weekly_stats(runs)
    evidence = {'scope': 'TRUSTED_LOCAL_PRIVATE_V1_V2_ROW_INTAKE_NOT_V3_OR_HOSTED', 'base': BASE,
        'repository_rows': rows(), 'historical_candidate_rows': load('IDENTITY_INTAKE.json')['candidate_export'],
        'verified_bindings': BOUND, 'candidate_leads': CANDIDATES,
        'occurrences': bindings,
        'assisted_branches': [
            {'variant_key': 'pull_up_foot_assisted', 'identity': None, 'selected': False, 'status': 'UNRESOLVED_SEPARATE_BRANCH_NOT_NEGATIVE_LOAD'},
            {'variant_key': 'pull_up_machine_assisted', 'identity': None, 'selected': False, 'status': 'UNRESOLVED_SEPARATE_BRANCH_NOT_NEGATIVE_LOAD'}],
        'weighted_option': {'exercise_id': 'EX-095', 'selected': False, 'status': 'VERIFIED_LOCAL_WEIGHT_BELT_OPTION_NOT_INITIAL_BODYWEIGHT_IDENTITY'}}
    requests = {'scope': 'EXACT_SELECTED_VARIANTS_TRUSTED_PRODUCER_REQUEST_NOT_PUBLISHED_RECORDS',
        'canonical_definition_versions_or_events_required_by_v1_v2': False,
        'records': [
            {'variant_key': key, 'source_decision': standard[key]['authority'],
             'plain_english_name': standard[key]['exercise'], 'selected_setup': standard[key]['notes'],
             'per_side': '/side' in standard[key]['repetitions_or_duration'] or '/leg' in standard[key]['repetitions_or_duration'],
             'load_representation': native({**standard[key], 'exercise_occurrence_id': 'review-request'}) .get('performance_capture'),
             'candidate_id': CANDIDATES[key], 'verified_exercise_id': None,
             'canonical_definition_version': None, 'publication_event': None,
             'content_authority': 'D1–D7 selected content; not identity publication authority',
             'required_action': 'Trusted author checks exact existing row/setup first. Retain actual admissible published v1/v2 row or complete established exact identity authoring/intake if absent. No invented ID or v3 dependency.',
             'candidate_gap': {
                 'pull_up_bodyweight': 'Approved bridge/historical CSV do not supply a trusted runtime row for the selected initial strict bodyweight branch.',
                 'chest_supported_db_row': 'Published EX-090 equipment says Machine or Bench, not Dumbbells. Need technical evidence for DB branch; unrelated HYROX candidate is not authority.',
                 'db_lateral_raise': 'Historical exact equipment/execution description only; no admissible row retained.',
                 'bench_supported_db_row': 'Historical exact One Dumbbell + Bench description only; no admissible row retained.',
                 'seated_supported_db_press': 'Historical EX-037 lacks the selected seated back-supported neutral two-DB setup; do not reuse standing proposal.',
                 'reverse_lunge_db': 'EX-026 is equipment None; no exact loaded two-DB reverse-lunge row retained.',
             }[key]}
            for key in CANDIDATES],
        'conditional_not_initial_blockers': evidence['assisted_branches'] + [evidence['weighted_option']]}
    audit = {'base': BASE, 'selection_sha256': SELECTION_HASH, 'dose_clarification_sha256': DOSE_HASH, 'inherited_source_sha256': PINS,
        'counts': dict(collections.Counter(s['type'] for s in source['sessions'])), 'strength_occurrences_in_review': len(bindings),
        'selected_template_occurrences': len(bindings),
        'rdl_membership': 'EXPLICITLY_SELECTED',
        'weekly_strength_work_sets': [sum(e['sets'] for s in source['sessions'] if s['week'] == w for e in s.get('exercises', [])) for w in range(1, 11)],
        'strength_work_sets': sum(e['sets'] for s in source['sessions'] for e in s.get('exercises', [])),
        'omitted_work': [{'week': 9, 'variant': 'reverse_lunge_db', 'authority': 'Explicit founder W9 omission'}],
        'phase_reconciliation': [{'previous_label': 'W7 consolidation: reduce running and lifting volume', 'resolution': 'Removed; W7 uses standard strength; exact selected running preserved'},
                                 {'surviving_running_label': 'W8 Peak 10K specificity', 'scope': 'Selected run label only; does not override W8 lower-body strength effort control'},
                                 {'surviving_numeric_pattern': 'W7 running time and threshold minutes remain lower than W6', 'scope': 'Explicitly preserve selected running prescriptions; no retiming or implied strength deload'}],
        'verified_local_identity_occurrences': sum(b['exercise_id'] is not None for b in bindings),
        'unresolved_identity_occurrences': sum(b['exercise_id'] is None for b in bindings),
        'weekly_running': statistics, 'removed_personal_notes': removed_personal_notes,
        'removed_working_carryovers': [
            {'exercise': label, 'occurrences': [e['exercise_occurrence_id'] for s in original['sessions'] for e in s.get('exercises', []) if e['exercise'] == label],
             'authority': 'Founder explicitly identifies these as outside the selected strength template'}
            for label in ['Barbell back squat', 'DB farmer carry']],
        'removed_or_replaced_variants': ['Flat DB bench → Monday incline', 'Unilateral DB calf → bilateral machine calf',
            'Reverse crunch → Monday Pallof; side plank moves to Thursday', 'Unspecified shoulder press → Thursday seated supported neutral-grip press',
            'Monday unilateral row → bilateral chest-supported DB row', 'Monday reverse lunge → Thursday exact 1×6/leg'],
        'running_execution_steps_targets_and_identity_unchanged': all(a['workout']['steps'] == b['workout']['steps'] and a['source_session_id'] == b['source_session_id'] for a,b in zip(runs, load('RUNNING_BODIES.json'))),
        'timed_runs': sum(r['distance_metres'] == 0 for r in runs), 'distance_runs': 1,
        'content_hold_counts': dict(collections.Counter(h for b in bindings for h in b['content_holds'])),
        'full_programme_approval': False, 'publication': False}
    assert audit['counts'] == {'strength': 20, 'running': 40, 'rest': 10}
    assert len(bindings) == 105 and audit['verified_local_identity_occurrences'] == 47
    assert audit['running_execution_steps_targets_and_identity_unchanged']
    return {'SOURCE.json': source, 'RUNNING_BODIES.json': runs, 'SCHEDULE_CANDIDATE.json': schedule,
            'IDENTITY_INTAKE.json': evidence, 'TRUSTED_INTAKE_REQUESTS.json': requests,
            'STRENGTH_REVIEW_GRAPHS.json': graphs, 'AUDIT.json': audit}


def weekly_stats(runs):
    result = []
    for week in range(1, 11):
        group = [r for r in runs if r['source_week'] == week]
        steps = [s for r in group for s in r['workout']['steps']]
        def seconds(s):
            return s['duration'].get('milliseconds', 0) // 1000
        optional_walk = sum(seconds(s) for s in steps if 'walking allowed' in s['notes'] or 'running or walking' in s['label'])
        result.append({'week': week, 'fixed_workout_seconds': sum(r['fixed_seconds'] for r in group),
            'running_seconds_range_if_permitted_recoveries_walked': [sum(r['fixed_seconds'] for r in group) - optional_walk, sum(r['fixed_seconds'] for r in group)],
            'explicit_run_or_walk_cooldown_seconds': sum(seconds(s) for s in steps if 'running or walking' in s['label']),
            'inherited_optional_walk_recovery_seconds': sum(seconds(s) for s in steps if 'walking allowed' in s['notes']),
            'threshold_seconds': sum(seconds(s) for s in steps if s['target'].get('category') == 'threshold'),
            'ten_k_specific_seconds': sum(seconds(s) for s in steps if s['target'].get('category') == '10k_specific'),
            'steady_seconds': sum(seconds(s) for s in steps if 'Authored effort: STEADY.' in s['notes']),
            'strides_acceleration_seconds': sum(seconds(s) for s in steps if 'Authored effort: STRIDE.' in s['notes'] or s['label'] == 'Relaxed acceleration'),
            'distance_ended_metres': sum(r['distance_metres'] for r in group)})
    return result


def admission_preflight(graphs):
    expected = build()['STRENGTH_REVIEW_GRAPHS.json']
    if graphs != expected:
        raise ValueError('not_exact_selected_source_review')
    unresolved = [e for g in graphs for b in g['blocks'] for e in b['exercises'] if e['exercise_id'] is None]
    holds = sorted({h for g in graphs for b in g['blocks'] for e in b['exercises'] for h in e['content_holds']})
    return {'admitted': False, 'code': 'exact_identity_records_required',
            'unresolved_identity_occurrences': len(unresolved), 'unique_content_holds': holds,
            'full_strength_graphs_admitted': 0, 'complete_programme_approval': 'D8_PENDING',
            'canonical_private_decoder_called_for_incomplete_graphs': False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs = build()
    for name, value in outputs.items():
        data = encode(value)
        if args.check:
            if (OUT / name).read_text() != data:
                raise SystemExit('Stale selected-source artifact: ' + name)
        else:
            (OUT / name).write_text(data)
    print(encode(admission_preflight(outputs['STRENGTH_REVIEW_GRAPHS.json'])))


if __name__ == '__main__':
    main()
