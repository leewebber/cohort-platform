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
BASE = '398a7fe9dc61791db71410fa46ba8d3a1e6c3991'
PINS = {
    'SOURCE.json': '3a610154a8be27d31ecfe7cbf2fdfb16908a305e1bd35e1ada22b7e4b1bee486',
    'RUNNING_BODIES.json': '3eaa1b932b9251c1ca5d6c299d856436a0291ff4d7ade2663155eebb30d02c60',
    'SCHEDULE_CANDIDATE.json': 'd60803201b0986f67f6ab8ce6a9d8693e74fbd5b94a6d23e4f6d3c4aa9d9a092',
    'GENERAL_GUIDANCE.md': '1aabcb3034f88efb0d2a29e280ffc141b759371c9364c28015d2dc51c79370c3',
    'IDENTITY_INTAKE.json': '2229c3f72f3fba97de7dead7abe8ba6a172fa2293eff3f310fa2cef3f3306b10',
}
SELECTION_HASH = 'dd7e08cc1b026b46307b42c491216543899879e202c3f665ce837f486bc0d6d8'
WAVE = 'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql'
WAVE_HASH = '22a2683b81d09e071b99adda3c120dff06cb6410fcc4a2b53029beffca73d0c8'
BOUND = {'incline_db_press': 'EX-084', 'cable_pallof_square': 'EX-114',
         'machine_standing_calf': 'EX-125', 'side_plank': 'EX-116',
         'barbell_rdl_carryover': 'EX-078'}
CANDIDATES = {'pull_up_bodyweight': 'EX-053', 'chest_supported_db_row': 'EX-090',
              'db_lateral_raise': 'EX-044', 'bench_supported_db_row': 'EX-038',
              'seated_supported_db_press': 'EX-037', 'reverse_lunge_db': None}
MONDAY = ['incline_db_press', 'pull_up_bodyweight', 'chest_supported_db_row',
          'db_lateral_raise', 'cable_pallof_square']
THURSDAY = ['barbell_rdl_carryover', 'reverse_lunge_db', 'seated_supported_db_press',
            'bench_supported_db_row', 'machine_standing_calf', 'side_plank']
CONSOLIDATION = {4, 7}


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


def old_ex(source, week, label, day=None):
    return next(e for s in source['sessions'] if s['week'] == week and s['type'] == 'strength'
                and (day is None or s['day'] == day) for e in s['exercises'] if e['exercise'] == label)


def add_reduction(e, original, explanation, hold=None, apply=False):
    e['retained_reduction_proposals'].append({'source_occurrence_id': original['exercise_occurrence_id'],
        'original_label': original['exercise'], 'sets': original['sets'],
        'repetitions_or_duration': original['repetitions_or_duration'], 'rir': original['rir'],
        'rest_seconds': original['rest_seconds'], 'explanation': explanation,
        'applied_as_proposed_only': apply})
    if hold:
        e['content_holds'].append(hold)
        e['effective_dose_status'] = 'UNRESOLVED_REDUCTION_REFERENCE_DOSE_ONLY'
    if apply:
        e['standard_week_reference'] = {k: e[k] for k in ['sets', 'repetitions_or_duration', 'rir', 'rest_seconds']}
        for k in ['sets', 'repetitions_or_duration', 'rir', 'rest_seconds']:
            e[k] = original[k]
        e['dose_status'] = 'RETAINED_PROPOSED_REDUCTION_NOT_FINAL_CONTENT_APPROVAL'
        e['effective_dose_status'] = 'EXACT_RETAINED_PROPOSAL_PENDING_D8'


def build():
    verify_pins()
    original = load('SOURCE.json')
    source = copy.deepcopy(original)
    source.update(source_schema='hybrid10k-founder-selected-review/2',
                  title='General Hybrid 10K PB — founder-selected strength, D8 review pending',
                  content_status='D1_D7_STANDARD_SELECTIONS_APPROVED_D8_PENDING',
                  shared_rules_location='TEN_WEEK_REVIEW.md in this source directory',
                  authority_source='FOUNDER_SELECTIONS.md', publication_approved=False)
    standard = standards()
    bindings, graphs = [], []
    for s in source['sessions']:
        if s['type'] != 'strength':
            continue
        week, day = s['week'], s['day']
        keys = MONDAY if day == 1 else (['seated_supported_db_press', 'bench_supported_db_row'] if week == 10 else THURSDAY)
        exercises = []
        for key in keys:
            if key == 'barbell_rdl_carryover':
                e = copy.deepcopy(old_ex(original, week, 'Barbell Romanian deadlift'))
                e['retained_source_occurrence_id'] = e['exercise_occurrence_id']
                e.update(variant_key=key, authority='RETAINED_UNSELECTED_ATTACHMENT_CARRYOVER',
                         dose_status='UNAPPROVED_SOURCE_CARRYOVER', effective_dose_status='TEMPLATE_MEMBERSHIP_UNRESOLVED',
                         effective_prescription=None, content_holds=['C4'], retained_reduction_proposals=[])
                e['tempo'] = '~2 seconds lowering; no forced pause; purposeful lift'
                e['notes'] += ' Not part of D1–D7 selections; retain/remove decision pending. Total external barbell load.'
            else:
                e = copy.deepcopy(standard[key])
            e['exercise_occurrence_id'] = f'W{week:02}-{"A" if day == 1 else "B"}-{key}'
            if week in CONSOLIDATION:
                mapping = {'incline_db_press': ('DB bench press', 'C1', False),
                           'chest_supported_db_row': ('One-arm DB row', 'C1', False),
                           'reverse_lunge_db': ('DB reverse lunge', 'C1', False),
                           'seated_supported_db_press': ('DB overhead press', 'C1', False),
                           'machine_standing_calf': ('Standing single-leg DB calf raise', 'C1', False),
                           'pull_up_bodyweight': ('Pull-up', None, True),
                           'db_lateral_raise': ('DB lateral raise', None, True),
                           'bench_supported_db_row': ('One-arm DB row', None, True)}
                if key in mapping:
                    label, hold, apply = mapping[key]
                    oldday = 1 if key == 'chest_supported_db_row' else 4 if key == 'bench_supported_db_row' else None
                    add_reduction(e, old_ex(original, week, label, oldday),
                        'Retained exact proposal for the same selected movement/branch.' if apply else
                        'Changed variant, day or standard dose: no automatic transfer of the old reduction.', hold, apply)
            if week == 9 and key == 'reverse_lunge_db':
                add_reduction(e, old_ex(original, week, 'DB reverse lunge'),
                              'Old reduced 1×5/leg conflicts with newly selected standard 1×6/leg; no fractional/zero-set reduction invented.', 'C2')
            if week == 10 and day == 1:
                if key in ['pull_up_bodyweight', 'db_lateral_raise']:
                    label = 'Pull-up' if key == 'pull_up_bodyweight' else 'DB lateral raise'
                    add_reduction(e, old_ex(original, 10, label), 'Same-movement exact retained taper proposal, not final D8 approval.', apply=True)
                else:
                    e['content_holds'].append('C3')
                    e['effective_dose_status'] = 'W10_NEW_OR_CHANGED_MOVEMENT_TAPER_DOSE_UNRESOLVED'
                    if key == 'chest_supported_db_row':
                        add_reduction(e, old_ex(original, 10, 'One-arm DB row'), 'Unilateral row taper dose cannot silently become bilateral DB row dose.')
                    elif key == 'cable_pallof_square':
                        add_reduction(e, old_ex(original, 10, 'Side plank'), 'One timed side-plank set cannot silently become a Pallof dose.')
                    else:
                        e['retained_reduction_proposals'].append({'explanation': 'No flat/incline chest press in old W10 template; Monday incline inclusion/dose requires explicit taper choice.'})
            if week == 10 and day == 4:
                e.update(sets=2, rir='at least 3', dose_status='FOUNDER_SELECTED_W10_EXCEPTION',
                         effective_dose_status='SELECTED_W10_EXCEPTION')
                if key == 'seated_supported_db_press':
                    add_reduction(e, old_ex(original, 10, 'DB overhead press', 4),
                        'Sets and minimum RIR are selected; prior proposed 90-second rest conflicts with new standard 120 seconds. Rest requires decision.', 'C3')
                e['notes'] += ' Comfortable upper-body work; at least 3 RIR, no invented upper bound; no lower-body lifting.'
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
        graphs.append({'source_session_id': s['session_id'], 'protocol_id': s['session_id'] + '-DRAFT-R2',
            'revision_number': 2, 'classification': 'REVIEW_ONLY_NOT_ADMITTED_OR_PUBLISHED',
            'blocks': [
                {'position': 1, 'block_type': 'warm_up', 'title': 'Preparation', 'content': prep, 'workout_format': 'none', 'exercises': []},
                {'position': 2, 'block_type': 'strength', 'title': s['title'], 'content': 'Selected standards, exact retained proposals and unresolved reference doses remain distinct.',
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
            ref.update(protocol_id=s['session_id'] + '-DRAFT-R2', revision_number=2, title=s['title'])
    for w in schedule['weeks']:
        for day in w['days']:
            day_source = next(s for s in source['sessions'] if s['week'] == w['week_number'] and s['day'] == day['day_order'])
            day['title'] = day_source['title']
            for slot in day['slots']:
                if any(g['source_session_id'] == slot['session_key'] for g in graphs):
                    slot['display_title'] = day_source['title']
                    slot['progression']['prescription_summary'] = 'D1–D7 standard selections; exact retained reductions/reference doses and D8 holds in TEN_WEEK_REVIEW.md. No automatic progression.'
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
    audit = {'base': BASE, 'selection_sha256': SELECTION_HASH, 'inherited_source_sha256': PINS,
        'counts': dict(collections.Counter(s['type'] for s in source['sessions'])), 'strength_occurrences_in_review': len(bindings),
        'selected_template_occurrences': sum(b['variant_key'] != 'barbell_rdl_carryover' for b in bindings),
        'unapproved_rdl_carryover_occurrences': 9,
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
    assert len(bindings) == 106 and audit['verified_local_identity_occurrences'] == 47
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
    return {'admitted': False, 'code': 'source_identity_and_content_holds',
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
