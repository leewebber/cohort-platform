#!/usr/bin/env python3
"""One self-contained ten-week review from the selected genuine source."""
import argparse
import json

import apply_strength_selections as selected


def duration(seconds):
    return f'{seconds // 60}:{seconds % 60:02}'


def dose(e):
    effort = 'no RIR/failure target' if e['rir'] == 'N/A' else ('at least 3 RIR' if e['rir'] == 'at least 3' else e['rir'] + ' RIR')
    return f"{e['sets']} × {e['repetitions_or_duration']}; {effort}; rest {e['rest_seconds']} seconds"


def target(step):
    t = step['target']
    kind = t['kind']
    if kind == 'heart_rate_zone_ref':
        return 'athlete-confirmed Zone 2 (reviewed/frozen personal BPM range; supporting EASY effort, no invented BPM)'
    if kind == 'alpha_quality_pace_v1':
        return 'approved personalised ' + ('threshold' if t['category'] == 'threshold' else 'estimated-current-10K') + ' target; explicit source selection/review/acceptance'
    if kind == 'rpe_range':
        return f"authored RPE {t['low']}–{t['high']}/10, no fixed pace"
    if kind == 'none':
        return 'authored effort only; no fixed pace or invented HR target'
    if kind == 'instruction':
        return t.get('instruction', t.get('text', 'authored assessment effort'))
    # Preserve any genuinely unfamiliar target visibly, never translate it away.
    return 'RETAINED TARGET REQUIRING REVIEW: ' + json.dumps(t, ensure_ascii=False)


def render():
    data = selected.build()
    source, audit = data['SOURCE.json'], data['AUDIT.json']
    guidance = (selected.OLD / 'GENERAL_GUIDANCE.md').read_text()
    controlling_runs = guidance[guidance.index('## Controlling targets'):guidance.index('## Retained strength guidance')]
    fatigue = guidance[guidance.index('## Progression, fatigue and taper boundaries'):]
    fatigue = fatigue.replace('consolidation weeks and reduced lower-body work.', 'W4 consolidation, W5–7 build, W8 lower-body effort control and W9–10 workload reduction. Selected running prescriptions stay unchanged.')
    rules = (selected.ROOT / 'docs/checkpoints/m23_quality_target_admission/DECISIONS.md').read_text()
    exact_rules = rules[rules.index('| Source/rule'):rules.index('No target-rule decision remains')]
    lines = [
        '# General Hybrid 10K PB — complete ten-week founder review', '',
        '**D1–D7, RDL membership and all week-specific strength doses below are founder-selected. D8 remains pending. This is not full programme approval, publication, eligibility or athlete assignment.**', '',
        'Scope: already-fit, competent runner pursuing a 10K PB. Lee’s personal return-to-running/travel adjustment remains separate. Calendar dates below are illustrative retained source dates, not assignment authority.', '',
        'The complete schedule has **40 runs, 20 strength sessions and 10 rest days**: Monday strength, Tuesday main run, Wednesday easy, Thursday strength, Friday easy/strides, Saturday rest, Sunday long run/final test. There are **39 timed runs and one distance-ended 10K test**. Four exact Tuesday replacements (W4/W8/W9/W10) and W10 Thursday’s structure were already selected; the remaining running prescriptions remain proposed.', '',
        'Every session is printed below. Shared preparation/target/progression instructions here apply to each specified session; no external document is needed to interpret the doses. Within-session strength order is shown for review and remains part of D8. No actual load, BPM or pace is guessed.', '',
        '## Source clarification status and remaining review', '',
        'The previous dose holds are resolved: RDL belongs to the template; W4 uses two sets for standard three-set upper-body exercises, with normal core/calf/lunge; W7 uses standard strength, not consolidation; W8 controls lower-body effort; W9 reduces workload and omits lunges; W10 has the exact selected Monday doses and Thursday press/row exception. Rest periods and standard effort instructions remain unchanged unless explicitly stated below.', '',
        '**D8/full-programme approval remains pending founder review of this document.** It still covers general entry workload, remaining run details, strength order and preparation/progression/fatigue guidance. The resolved membership/dose choices are not new questions. Exact identity retention is a separate technical boundary, listed once below.', '',
        '## Phase labels — reconciled together', '',
        '| Wording or pattern | Current interpretation |', '|---|---|',
        '| W4 consolidation; W5–7 build; W8 lower-body effort control; W9–10 workload reduction | Controlling founder progression. W7 strength is standard; no old W7 reductions survive. |',
        '| Old W7 consolidation label | Removed from current source, schedule titles and this review. It survives only in historical source/provenance records. |',
        '| W7 running time/threshold work remains lower than W6 | Explicitly preserved selected running prescriptions. This numerical running pattern does not reintroduce a W7 strength deload or a consolidation phase label. |',
        '| W8 run title “Peak 10K specificity” | Retained label for that selected running session only; it does not override W8 lower-body strength effort control. |',
        '| W9 former “Final 10K-specific development” week label | Current week overview says reduce workload; the selected running session remains unchanged. W10 sharpening/final-test labels remain compatible with taper. |', '',
        '## Strength source corrections and authority', '',
        '- Working back squats (9 occurrences) and DB farmer carries (9) came from the supplied attachment’s Thursday work tables. They were outside the selected strength template and are removed from current work graphs. They were never preparation sets.',
        '- Ten bodyweight squats and eight unloaded hinges in shared gym preparation are **preparation**, not working barbell squat/RDL sets. Warm-up/ramp sets are separate from the listed work sets. W10 Thursday has upper-body preparation only.',
        '- Flat DB bench, unilateral DB calf and reverse crunch are superseded. Incline press is Monday; machine calf is Thursday; Pallof is Monday; side plank is Thursday. Standard doses use the founder’s new numbers, not the attachment’s doses. Shoulder press is Thursday seated/back-supported/neutral grip; Monday row is bilateral chest-supported, Thursday row is single-arm/bench-supported.',
        '- Barbell RDL is explicitly selected template work, not an unintended carryover. Standard dose is 2×5–6, 2–3 RIR, 120–180 seconds rest, with the exact W8/W9 exceptions below. Earlier carryover/membership and dose-hold labels are superseded, not current questions.',
        '- Old W2 Sunday personal travel-option wording is excluded from this general source. Its 40-minute base run, steps, targets and identity are unchanged. Old Monday-lunge/squat-removal fatigue rules are inapplicable after these selections; no replacement adjustment is invented.',
        '',
        '## Exact strength setup, preparation and logging', '',
        'Monday standard work: approximately 30° bilateral incline DB press 3×6–10, 2 RIR, 120 sec rest; strict shoulder-width overhand pull-up 3×5–8, 2 RIR, 120 sec rest, bodyweight initially; bilateral chest-supported DB row 3×8–12, 1–2 RIR, 90 sec rest; DB lateral raise 3×12–20, 1–2 RIR, 60 sec rest; standing square-stance cable Pallof at chest height, both hands on handle, no torso rotation, 2×10/side, controlled, 45–60 sec rest, no RIR/failure requirement.', '',
        'Thursday standard selected work: barbell RDL 2×5–6, 2–3 RIR, 120–180 seconds rest; two DBs at sides, neutral grip reverse lunge 1×6/leg, 2–3 RIR, one side then the other, 90 sec rest after both; seated near-upright back-supported two-DB neutral strict press without leg drive 3×6–10, 2 RIR, 120 sec rest; free-hand bench-supported single-arm DB row 3×8–12/side, 1–2 RIR, 90 sec after both sides; bilateral machine standing calf 2×10–15, 2 RIR, 60–90 sec rest; bodyweight side plank 2×30–45 sec/side, 45–60 sec rest, stop before posture loss, no failure target.', '',
        'Gym preparation (retained proposal except the W10 Thursday restriction): 5 minutes brisk walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles in each direction. For the first loaded lower-body exercise add 2–4 progressively loaded warm-up sets; for each new upper-body pattern add 1–2 light sets as needed. No warm-up set to failure. W10 Thursday: upper-body preparation only, 1–2 light sets per new upper-body pattern as needed; no squat/hinge or loaded lower-body work inserted. Finish every gym session with 3–5 minutes easy walking.', '',
        'Retained proposed tempo: controlled lowering approximately 2 seconds, no forced pause, purposeful lift; lateral raises controlled both ways; calves approximately 2 sec up, 1 sec at top, 2 sec down through comfortable range. Pallof uses controlled execution and side plank a controlled hold. RIR means reps left with good technique; core work has no RIR/failure requirement. Each per-side dose applies to EACH side; both sides form one set. D4 and Thursday row rest follows both sides; no extra intra-side rest or fixed transition duration is invented.', '',
        'Choose actual loads from current ability; no guessed kg. DB load is external load **per dumbbell** (including bilateral rows), barbell RDL is total external barbell load. Machine/cable resistance retains actual displayed unit and setup; do not assume cross-machine equivalence. Bodyweight is the initial pull-up branch. Added load is conditional on an exact retained supported weighted identity and explicit selection; do not silently change canonical exercise identity as “progression”. Foot-assisted and machine-assisted branches remain unresolved and separate; never encode assistance as negative added load. Do not prefill actuals.', '',
        'Retained proposed progression: once ALL work sets reach the top of the rep range at target RIR on two exposures, the athlete may accept the smallest available load increase (typically 1–2 kg per DB, 2–2.5 kg upper-body barbell or 2.5–5 kg lower-body barbell), returning to the bottom of the range. Never force a load jump or progress automatically. Maintain if running quality/recovery is affected. No 1RM or failure tests. Week-specific no-planned-load-increase instructions override this generic proposal (W4 RDL; W8 lower-body work). This is D8 review content, not automatic runtime authority.', '',
        controlling_runs.strip(), '', '## Approved personalised quality-target rules — exact retained behaviour', '',
        exact_rules.strip(), '', fatigue.strip(), '',
        '## Weekly running duration and quality-work audit', '',
        'All values are minutes:seconds. **Fixed workout time** includes every authored timed warm-up, work, recovery, stride and cooldown. The distance-ended 10K adds its actual elapsed segment time; no estimate replaces it. Extra 3–5-minute walks/drills outside ordinary run bodies are excluded from these totals. For the four selected Tuesday replacements, the exact authored body supersedes extra mandatory walking/preparation.', '',
        'The running range subtracts the four explicitly optional five-minute walking cooldowns and any inherited recovery phases whose retained effort notes allow walking. It is a conditional running-time range, not a second workout clock or permission to replace the selected jog recoveries in the four replacements. Prescribed jog recoveries count in the nominal budget; actual walking never becomes running volume. “Quality work” here means only timed threshold plus estimated-current-10K work; steady work and relaxed strides/accelerations are separate. The final 10K quality time is unknown until measured.', '',
        '| Week / phase | Fixed workout time | Conditional running time | Threshold | 10K-specific | Timed quality total | Steady | Strides/accelerations | Distance-ended work |',
        '|---|---:|---:|---:|---:|---:|---:|---:|---|',
    ]
    for w in audit['weekly_running']:
        extra = ' + actual 10K time' if w['distance_ended_metres'] else ''
        lo, hi = w['running_seconds_range_if_permitted_recoveries_walked']
        focus = source['weeks'][w['week'] - 1]['focus']
        lines.append(f"| {w['week']} — {focus} | {duration(w['fixed_workout_seconds'])}{extra} | {duration(lo)}–{duration(hi)}{extra} | {duration(w['threshold_seconds'])} | {duration(w['ten_k_specific_seconds'])} | {duration(w['threshold_seconds'] + w['ten_k_specific_seconds'])} | {duration(w['steady_seconds'])} | {duration(w['strides_acceleration_seconds'])} | {'10,000 m; time unknown until measured' if extra else 'None'} |")
    lines += ['', 'All recoveries are expanded explicitly below. For normal stride blocks the final 100-second recovery IS included. For the four selected Tuesday workouts, work recoveries are BETWEEN repetitions only, with no recovery after the last work repetition; their warm-up includes all three acceleration recoveries.', '',
              '## Exact local identity retention — six records/actions', '',
              'The retained legacy rows support the selected incline DB press (`EX-084`), cable Pallof (`EX-114`), bilateral machine standing calf (`EX-125`), side plank (`EX-116`) and barbell RDL (`EX-078`). RDL membership is now confirmed. This is local row evidence, not a new published version/event or current hosted-state verification.', '',
              ('| Selected movement' + (selected.OUT / 'EXACT_IDENTITY_ACTIONS.md').read_text().split('| Selected movement', 1)[1].split('For existing row leads', 1)[0]).strip(), '',
              'A trusted catalogue/definition owner must provide the actual records/setup bindings above through the established private v1/v2 boundary. The narrowly scoped SQL retention request is prepared but not executed; hosted target/read authority is separate. No new founder movement choice is being requested. Foot-assisted and machine-assisted pull-ups remain separate unresolved branches, never negative added load; weighted EX-095 is a separate retained weight-belt option, not the initial bodyweight identity.', '',
              '**Actual full admission:** both v1/v2 schedules compile; known-identity partial graph/codec checks pass. Full strength admission remains blocked by the exact identity records above, with no unresolved dose holds. D8/full-programme approval is still pending. Nothing is published, acquired, started, logged, completed or restored for an athlete here. The final 10K remains distance-ended and unsupported by the current runner.', '',
              '## All ten weeks — every session', '']
    for week in range(1, 11):
        focus = source['weeks'][week - 1]['focus']
        lines += [f'## Week {week} — {focus}', '']
        for s in [s for s in source['sessions'] if s['week'] == week]:
            lines += [f"### {s['weekday']} — {s['title']} ({s['date']})", '', f"Review reference: `{s['session_id']}`. Status: " + ('exact selected standard/week-specific strength doses; full-programme D8 pending.' if s['type'] == 'strength' else 'founder-selected exact replacement.' if s['content_status'].startswith('FOUNDER_SELECTED_REPLACEMENT') else 'retained proposed content, D8 pending.'), '']
            if s['type'] == 'rest':
                lines += s['instructions'] + ['']
            elif s['type'] == 'running':
                r = next(r for r in data['RUNNING_BODIES.json'] if r['source_session_id'] == s['session_id'])
                selected_replacement = s['content_status'].startswith('FOUNDER_SELECTED_REPLACEMENT')
                lines += ['Preparation: exact 13-minute warm-up begins this selected body; no extra mandatory warm-up/walk is added.' if selected_replacement else 'Preparation outside this body: 3–5 min brisk walk, 10 ankle rocks/side, 10 calf raises, 10 controlled leg swings/side; no static stretching holds. First 5 min of a continuous easy run are particularly gentle and INCLUDED.', '']
                for i, step in enumerate(r['workout']['steps'], 1):
                    dur = step['duration']
                    amount = duration(dur['milliseconds'] // 1000) if dur['kind'] == 'time' else f"{dur['millimetres'] // 1000:,} metres — DISTANCE-ENDED"
                    lines.append(f"{i}. **{step['label']} — {amount}**. {target(step)}. {step['notes']}")
                lines += ['', f"Body total: **{duration(r['fixed_seconds'])}" + (' + actual elapsed 10K segment time**.' if r['distance_metres'] else '**.'),
                          'Finish outside this body: 3–5 min easy walking.' if not selected_replacement else 'The final 5-minute very easy run-or-walk cooldown is already included; no additional mandatory finish phase.', *s['notes'], '']
            else:
                graph = next(g for g in data['STRENGTH_REVIEW_GRAPHS.json'] if g['source_session_id'] == s['session_id'])
                lines += [graph['blocks'][0]['content'], '', '| Review order / working lift | Exact selected working dose | Review status |', '|---|---|---|']
                for i, e in enumerate(s['exercises'], 1):
                    state = 'Exact founder-selected dose; D8 full-programme review pending'
                    lines.append(f"| {i}. {e['exercise']} | {dose(e)} | {state} |")
                lines += ['']
                for i, e in enumerate(s['exercises'], 1):
                    lines.append(f"{i}. **{e['exercise']} setup:** {e['notes']} Tempo: {e['tempo']}.")
                    for old in e['retained_reduction_proposals']:
                        if 'sets' in old:
                            lines.append(f"   Retained source proposal: {old['original_label']} — {dose(old)}. {old['explanation']}")
                        else:
                            lines.append('   Retained source context: ' + old['explanation'])
                lines += ['', 'Finish: 3–5 minutes easy walking. Preparation/ramp sets are additional to the listed work sets. Gym elapsed time is unknown, not an invented exact session duration.', '']
    return '\n'.join(line.rstrip() for line in lines).rstrip() + '\n'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = render()
    target_path = selected.OUT / 'TEN_WEEK_REVIEW.md'
    if args.check:
        if target_path.read_text() != data:
            raise SystemExit('Stale ten-week review')
        print('Complete ten-week review matches selected source')
    else:
        target_path.write_text(data)
        print(f'Wrote {target_path}')
