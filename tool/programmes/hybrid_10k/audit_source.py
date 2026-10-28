#!/usr/bin/env python3
"""Derive review-only artifacts from retained Lee draft. No network or writes to DB.

Run from the repository root; --check verifies byte-identical regeneration.
SOURCE.md is the only editable coaching source. Never edit generated calendars.
"""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import uuid

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'docs/programmes/hybrid_10k/lee_draft_2026_10_28'


def encoded(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def expand_run(session):
    result = []
    for index, step in enumerate(session['steps'], 1):
        def append(action, effort, seconds=None, metres=None, repetition=None):
            result.append({
                'source_step': index,
                'step_id': f"{session['session_id']}-P{len(result)+1:02}",
                'action': action, 'effort': effort,
                'seconds': seconds, 'metres': metres,
                'repetition': repetition,
            })
        if 'repetitions' in step:
            for rep in range(1, step['repetitions'] + 1):
                seconds = step.get('work_seconds')
                if 'work_minutes' in step:
                    seconds = step['work_minutes'] * 60
                append(step['action'], step['work_effort'], seconds,
                       step.get('work_metres'), rep)
                if rep < step['repetitions'] or step['recovery_after_last']:
                    recovery = (step['recovery_minutes'] * 60
                                if 'recovery_minutes' in step
                                else step['recovery_seconds'])
                    append('Recovery', step['recovery_effort'], recovery,
                           repetition=rep)
        else:
            seconds = step.get('duration_minutes')
            append(step['action'], step['effort'],
                   seconds * 60 if seconds is not None else None,
                   step.get('distance_metres'))
    return result


def target(effort):
    bounds = {'EASY': (3, 4), 'RECOVERY': (2, 3), 'STEADY': (5, 6),
              'THRESHOLD': (7, 8), 'TEN_K': (7, 9), 'STRIDE': (7, 8)}
    if effort not in bounds:
        return {'kind': 'none'}  # Assessment narrative, never guessed RPE.
    low, high = bounds[effort]
    return {'kind': 'rpe_range', 'scale': 'rpe_cr10', 'low': low, 'high': high}


EFFORT_NOTES = {
    'EASY': 'RPE 3–4/10; full sentences, relaxed gait, slow down as needed; not fixed pace.',
    'RECOVERY': 'RPE 2–3/10; very easy jog, walking allowed if needed.',
    'STEADY': 'RPE 5–6/10; controlled moderate effort, short sentences, below threshold.',
    'THRESHOLD': 'RPE 7/10 initially, up to 8 at the end; strong and repeatable, not a time trial; finish able to do one more repetition.',
    'TEN_K': 'RPE about 7–8 early, at most 9 at end; current realistic 10K effort, repeatable output and controlled mechanics.',
    'STRIDE': 'RPE about 7–8, relaxed; smooth acceleration, quick running, never all-out sprint.',
}


def build():
    raw = (DEST / 'SOURCE.md').read_bytes()
    text = raw.decode()
    appendix = re.findall(r'```json\n(.*?)\n```', text, re.S)
    assert len(appendix) == 1, 'Expected exactly one retained source calendar'
    source = json.loads(appendix[0])
    sessions = source['sessions']
    assert len(sessions) == 70
    start = datetime.date.fromisoformat(source['start_date'])
    assert start.weekday() == 0
    assert source['end_date'] == str(start + datetime.timedelta(days=69))
    assert len({s['session_id'] for s in sessions}) == 70
    occurrence_ids = [e['exercise_occurrence_id'] for s in sessions
                      for e in s.get('exercises', [])]
    assert len(occurrence_ids) == len(set(occurrence_ids))
    counts = collections.Counter(s['type'] for s in sessions)
    expanded, runs, issues = [], [], []
    running_sums = {}
    for index, s in enumerate(sessions):
        assert s['week'] == index // 7 + 1 and s['day'] == index % 7 + 1
        date = start + datetime.timedelta(days=index)
        assert s['date'] == str(date) and s['weekday'] == date.strftime('%A')
        row = dict(s)
        if s['type'] == 'running':
            steps = expand_run(s)
            fixed = sum(p['seconds'] or 0 for p in steps)
            distance = sum(p['metres'] or 0 for p in steps)
            actual = None if distance else fixed
            declared = s['prescribed_total_running_minutes']
            assert (declared * 60 if declared is not None else None) == actual, s['session_id']
            if distance:
                assert distance == s['work_distance_metres'], s['session_id']
            # Independently check the human calendar against JSON totals and sequence.
            narrative = text.split(f"· `{s['session_id']}`", 1)[1].split('\n**', 1)[0]
            if actual is not None:
                assert f'**{declared} minutes running**' in narrative, s['session_id']
            for step in s['steps']:
                if 'repetitions' in step:
                    assert f"{step['repetitions']} × " in narrative, s['session_id']
                    assert ('BETWEEN repetitions only' in narrative) == (not step['recovery_after_last']), s['session_id']
            row.update(ordered_running_steps=steps, fixed_running_seconds=fixed,
                       distance_work_metres=distance, exact_running_seconds=actual)
            running_sums[s['session_id']] = (fixed, distance)
            body = {
                'schema_version': 1, 'workout_id': s['session_id'],
                'title': s['title'],
                'notes': 'DRAFT / NOT APPROVED. Shared run rules in SOURCE.md apply. '
                         + ' '.join(s['notes']),
                'steps': [{
                    'kind': 'atomic', 'step_id': p['step_id'],
                    'role': ('recovery' if p['effort'] == 'RECOVERY' else
                             'warm_up' if 'warm-up jog' in p['action'].lower() else
                             'cool_down' if 'cooldown' in p['action'].lower() else 'work'),
                    'duration': ({'kind': 'time', 'milliseconds': p['seconds'] * 1000}
                                 if p['seconds'] is not None else
                                 {'kind': 'distance', 'millimetres': p['metres'] * 1000}),
                    'target': target(p['effort']), 'label': p['action'],
                    'notes': f"Source effort: {p['effort']}; source step {p['source_step']}"
                             + (f"; repetition {p['repetition']}" if p['repetition'] else '')
                             + '. ' + EFFORT_NOTES.get(p['effort'], p['effort']),
                } for p in steps],
            }
            runs.append({'source_session_id': s['session_id'],
                         'source_week': s['week'], 'source_day': s['day'],
                         'fixed_seconds': fixed, 'distance_metres': distance,
                         'workout': body})
        elif s['type'] == 'strength':
            narrative = text.split(f"· `{s['session_id']}`", 1)[1].split('\n**', 1)[0]
            for e in s['exercises']:
                table_row = f"| {e['exercise']} | {e['sets']} | {e['repetitions_or_duration']} | {e['rir']} | {e['rest_seconds']} |"
                assert table_row in narrative, (s['session_id'], e['exercise'])
            row['ordered_work_sets'] = [
                dict(e, set_index=n, side_semantics='Each side; both sides form one set',
                     rest_placement='Between work sets; no invented post-exercise rest')
                if '/side' in e['repetitions_or_duration'] or '/leg' in e['repetitions_or_duration']
                else dict(e, set_index=n, rest_placement='Between work sets; no invented post-exercise rest')
                for e in s['exercises'] for n in range(1, e['sets'] + 1)]
        expanded.append(row)
    weeks = []
    for week in source['weeks']:
        number = week['week']
        rows = [s for s in sessions if s['week'] == number]
        subtotal = sum(running_sums[s['session_id']][0] for s in rows if s['type'] == 'running')
        distance = sum(running_sums[s['session_id']][1] for s in rows if s['type'] == 'running')
        weeks.append(dict(week, counts=dict(collections.Counter(s['type'] for s in rows)),
                          fixed_running_minutes=subtotal // 60, distance_work_metres=distance,
                          exact_weekly_running_minutes=None if distance else subtotal // 60,
                          strength_work_sets=sum(e['sets'] for s in rows for e in s.get('exercises', [])),
                          strength_estimate_minutes=[25, 35] if number == 10 else [80, 120],
                          additional_run_walk_minutes=[24, 40],
                          untimed_drills_and_transitions='not included; duration unavailable'))
    issues.extend([
        {'code': 'week_10_template_conflict', 'sessions': ['LW10K-W10-D04'],
         'detail': 'Week 10 has 4 runs / 1 strength / 2 rest; accepted template is 4 / 2 / 1.'},
        {'code': 'easy_target_conflict', 'detail': 'Draft EASY RPE 3–4; retained general direction requires confirmed Zone 2. No zone marker inserted into source.'},
        {'code': 'threshold_target_conflict', 'detail': 'Draft forbids mechanical threshold derivation; approved alpha five_k rule includes threshold P10 ×1.02..1.06. Rules remain unchanged.'},
        {'code': 'personal_vs_general_scope', 'detail': 'This is Lee-specific return-to-running/travel source; general fit-runner PB brief remains separate.'},
    ])
    metadata = {'status': 'GENUINE_RETAINED_DRAFT_NOT_APPROVED_NOT_PUBLISHED',
                'source_sha256': hashlib.sha256(raw).hexdigest(),
                'counts': dict(counts), 'strength_occurrences': len(occurrence_ids),
                'timing_discrepancies': [], 'weeks': weeks, 'source_conflicts': issues,
                'distance_session_ids': [r['source_session_id'] for r in runs if r['distance_metres']]}
    manifest = {'package_schema_version': 1,
                'programme': {'lineage_code': source['programme_id'], 'version_number': 1,
                              'name': source['title'] + ' [DRAFT REVIEW ONLY]',
                              'description': 'Genuine Lee source; NOT approved, published or assigned. Source version 1.0.0 is not a database version.',
                              'library_scope': 'coach_private', 'owner_type': 'coach',
                              'coaching_intent': 'Review-only source admission',
                              'duration_weeks': 10, 'sessions_per_week': 6},
                'sessions': [], 'phases': [], 'weeks': [],
                'adaptation_permissions': [], 'protected_invariants': [], 'assessments': [],
                'performance_evidence_requirements': [], 'comparison_identities': []}
    for s in sessions:
        if s['type'] == 'rest':
            continue
        manifest['sessions'].append({'session_key': s['session_id'],
                                     'protocol_id': s['session_id'] + '-DRAFT-R1',
                                     # Local source-reference key only, not a published UUID.
                                     'session_lineage_id': str(uuid.uuid5(uuid.NAMESPACE_URL, source['programme_id'] + '/' + s['session_id'])),
                                     'revision_number': 1, 'title': s['title']})
    for w in source['weeks']:
        manifest['weeks'].append({'week_number': w['week'], 'title': w['focus'], 'days': [
            {'day_key': f"day_{s['day']}", 'day_order': s['day'],
             'day_type': 'rest' if s['type'] == 'rest' else 'training', 'title': s['title'],
             'slots': [] if s['type'] == 'rest' else [{'slot_key': s['session_id'],
                 'session_order': 1, 'session_key': s['session_id'], 'display_title': s['title'],
                 'progression': {'prescription_summary': 'DRAFT ONLY — see retained SOURCE.md and expanded review; no automatic progression'}}]}
            for s in sessions if s['week'] == w['week']]})
    review = ['# Expanded Lee draft — derived review view', '',
              'DRAFT, NOT CONTENT APPROVED / PUBLISHED / ASSIGNED. SOURCE.md is the sole coaching source.',
              'Generated by audit_source.py; edit SOURCE.md and regenerate. Shared rules and all coaching explanations remain in SOURCE.md.', '',
              'Running totals below include jog recoveries, warm-ups, cooldowns and strides. They exclude 3–5 minutes walking before AND after every run and untimed mobility/drills.',
              'Gym duration ranges are authored estimates including preparation, not verified exact totals: ramp sets, loads, rep speed and transitions vary.', '',
              '| Week | Fixed running minutes | Distance work added | Runs / strength / rest |',
              '|---|---:|---:|---|']
    for w in weeks:
        c = w['counts']
        review.append(f"| {w['week']} | {w['fixed_running_minutes']} | {w['distance_work_metres']} m | {c['running']} / {c['strength']} / {c['rest']} |")
    review += ['', 'Distance weeks are sums, not timed substitutes: W4 = 125 min + T5K; W8 = 166 min + T4×1km; W9 = 146 min + T3×1600m; W10 = 102 min + T3×800m + T10K.',
               'W2 travel alternatives: 105 min (25-minute Sunday) or 80 min (Sunday rest), against 120 min base. W4 whole-session easy replacement: 130 min; no 5K result.',
               'Weeks 3/5/6/7 Tuesday recoveries are between repetitions only. Every stride retains its final 100-second recovery. No automatic next-week load change.', '']
    for s in expanded:
        review += [f"## {s['session_id']} · {s['date']} · {s['title']}", '']
        if s['type'] == 'running':
            review += ['1. Walk briskly 3–5 min; 10 ankle rocks/side, 10 calf raises, 10 controlled leg swings/side (additional to running).']
            for i, p in enumerate(s['ordered_running_steps'], 2):
                dose = f"{p['seconds']} sec" if p['seconds'] is not None else f"{p['metres']} m — distance ended"
                review.append(f"{i}. {p['step_id']}: {p['action']} — {dose}; {p['effort']}" + (f"; repetition {p['repetition']}." if p['repetition'] else '.'))
            review += [f"{len(s['ordered_running_steps'])+2}. Walk 3–5 min afterwards (additional).", '',
                       f"Running: {s['fixed_running_seconds']//60} fixed min" + (f" + time to complete {s['distance_work_metres']} m work; total unavailable before execution." if s['distance_work_metres'] else '.'),
                       'Quality: optional 2–3 min familiar dynamic drills after jog warm-up, before repetitions; no added fast running. EASY starts with 5 gentle minutes included.']
        elif s['type'] == 'strength':
            review += ['1. Prepare: 5 min brisk walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups or shoulder-blade movements; 8 arm circles each direction.',
                       '2. Before first loaded lower-body exercise: 2–4 progressive warm-up sets; before each new upper pattern: 1–2 light sets as needed. Warm-up sets are additional; none to failure.']
            for i, e in enumerate(s['ordered_work_sets'], 3):
                review.append(f"{i}. {e['exercise_occurrence_id']} set {e['set_index']}/{e['sets']}: {e['exercise']} — {e['repetitions_or_duration']}; RIR {e['rir']}; rest {e['rest_seconds']} sec between sets. {e['notes']}")
            review += [f"{len(s['ordered_work_sets'])+3}. Finish: easy walking 3–5 min.", '',
                       'Tempo: ~2 sec lowering, no forced pause, purposeful lift. Calves ~2 sec up / 1 sec top / ~2 sec down; lateral raise controlled both ways. Both sides form one set. Side order and inter-exercise transition time are not prescribed. Holds/carries stop before posture/grip failure; no RIR.',
                       f"Authored duration estimate: {s['expected_duration_minutes']} min; exact total unavailable."]
        else:
            review += s['instructions']
        review += s.get('instructions', []) if s['type'] != 'rest' else []
        review += s.get('notes', []) + ['']
    return {'CALENDAR.json': encoded(source), 'EXPANDED.json': encoded(expanded),
            'AUDIT.json': encoded(metadata), 'RUNNING_BODIES.json': encoded(runs),
            'SCHEDULE_CANDIDATE.json': encoded(manifest), 'EXPANDED_REVIEW.md': '\n'.join(review)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, content in build().items():
        path = DEST / name
        if args.check:
            assert path.read_text() == content, f'Stale generated review: {name}'
        else:
            path.write_text(content)
    print('Source dates, 70 slots, unique identities, interval/recovery arithmetic and regeneration verified.')


if __name__ == '__main__':
    main()
