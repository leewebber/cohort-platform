# Lee Webber — 10-week 10K development / HYROX foundation

**Content specification v1.0 · 2 November 2026–10 January 2027 · Preparation week excluded**

## Codex implementation brief

Import this entire authored programme into Cohort using the repository's CURRENT supported contracts. This document is the training-content source of truth, not an existing Cohort schema or a claim of import compatibility. Inspect the repository instructions, plan-package validators, exercise catalogue and current execution models before mapping it. Preserve every prescription, unit, order, rest interval, intensity, date, assessment and note. The JSON appendix supplies the same complete calendar in a machine-readable form; shared rules below apply to every session.

- Programme ID: `LW-10K-HYROX-BASE-20261102`; version `1.0.0`. These are authored source IDs, not existing database IDs.
- Ten ordered weeks; seven ordered days per week; 70 explicit calendar entries. Normally four runs, two strength sessions and one rest day. Week 10 has one reduced strength session and two rest days.
- Preserve stable source session IDs and exercise occurrence IDs. Resolve real catalogue identities from the repository; do not invent production exercise UUIDs or silently map different exercises together.
- Running sets must execute in the stated order. Recoveries occur BETWEEN repetitions only unless a stride block explicitly includes recovery after each repetition.
- All strength work sets, per-side semantics, tempo, rest and RIR are authored below. Warm-up sets are additional and are not performance work sets.
- RPE targets and RIR targets are different fields. Do not convert effort-based runs into guessed pace or heart-rate targets. Unknown baseline values remain unavailable.
- Paces become available only after an athlete explicitly records AND selects a benchmark; never use a historical estimated 24-minute 5K as a measured result.
- No automatic load progression, benchmark replacement, session rewriting or schedule shifting. Show prior completed performance. Athlete accepts any suggested adjustment. Preserve started/completed prescriptions when inputs change.
- Do not stack this with another running or HYROX programme. All required training is contained here. No prep week, post-block week or HYROX race plan is included.
- First create/validate the mapped package and report unsupported content or ambiguous exercise identities. Do not silently drop content or activate, publish, deploy, migrate or assign to an athlete as an incidental import step. Follow the user's existing explicit authorization for any such operations.
- Implement only repository-appropriate validation; verify dates, ordering, interval arithmetic, per-side fields, benchmark selection, strength units and full content preservation. Report the resulting package/hash using the repository's actual system; do not claim this source file is already a canonical package.

## Purpose and athlete assumptions

Primary outcome: improve sustainable 10K running performance and establish a measured 10K result on 10 January. Strategic outcome: arrive ready for the January–May HYROX Pro build targeting Incheon around 15 May 2027. Running is the main training priority. Strength preserves meaningful lower-body force capacity, pulling/shoulder strength, trunk and grip; upper-body muscle gain is secondary.

Athlete is generally fit and strength trained, returning to regular running. No current measured 5K/10K is assumed. This programme starts with the ability to complete about 20–30 minutes easy running with normal gait and acceptable next-day recovery. If that is not true on 2 November, explicitly reduce/bridge the opening workload rather than force this schedule. Faster cardiovascular adaptation does not establish running-impact tolerance.

This is a running-led hybrid foundation, NOT full HYROX race preparation. Actual sled, wall-ball, row and SkiErg specificity belongs in the subsequent functional-gym phase. Do not invent those facilities during this block or present carries/lunges as equivalent sled practice.

## Equipment and environment

- 2–13 November: treadmill; squat rack, pull-up bar, bench, barbell, plates and dumbbells. No erg, cable, sled, box, bands or kettlebell is required.
- 14 November: travel/rest. 15 November: Korea arrival-week run, subject to the explicit travel adjustment below.
- From 15 November: good outdoor running route plus commercial gym with rack, barbells, dumbbells, kettlebells, machines and bands. The programme continues to use the same basic free-weight exercises so no facility-dependent rewrite is necessary.
- Treadmill: comfortable 0–1% incline, not a compulsory 1%. Strong fan/ventilation if available. Use effort, not outdoor historical pace. Change speed while staying on the belt; never jump onto/off a fast belt.
- Korea: choose flat, safe routes for quality work and benchmarks. Treadmill remains an acceptable substitute for unsafe footing/weather. Surface, wind and treadmill estimates affect pace comparisons; record them.

## Weekly ordering and training priority

Monday strength A is upper-body dominant with a SMALL single-leg maintenance dose. Tuesday is the main quality run, initially easy. Wednesday easy run. Thursday strength B carries the heavier lower-body work. Friday easy run/strides. Saturday rest. Sunday long easy run. This places a rest/easy buffer after the heavier leg session and avoids prescribing hard intervals the next day.

Required session priority if life interferes: (1) main Tuesday run, (2) Sunday long run, (3) Wednesday easy run, (4) strength B, (5) Friday easy run, (6) strength A. This is a scheduling priority, not permission to preserve a hard run through poor recovery. Never cram missed sessions or double the next day's load. If one gym session is possible, use B and add two sets of pull-ups only if time/recovery permits. Missed training does not create training debt.

## Effort, pace and benchmark rules

| Code | Target | Execution |
|---|---|---|
| EASY | RPE 3–4/10 | Full sentences, relaxed gait. Slow down as needed; easy is not a fixed pace. |
| RECOVERY | RPE 2–3/10 | Very easy jog; walking is allowed if needed during recovery. |
| STEADY | RPE 5–6/10 | Controlled moderate effort, short sentences; distinctly below threshold. |
| THRESHOLD | RPE 7/10 initially, up to 8 at the end | Strong and repeatable, not a time trial. Finish able to complete one more repetition. |
| TEN_K | RPE about 7–8 early; at most 9 at the end | Realistic CURRENT 10K effort. Repeatable output and controlled mechanics. |
| STRIDE | RPE about 7–8, relaxed | Smooth acceleration to quick running, never an all-out sprint. |

Before the week-4 assessment, effort is the primary target. Afterwards an optional conservative 10K pace reference may be computed from an explicitly selected 5K: predicted 10K seconds = measured 5K seconds × (10/5)^1.06; divide by 10 for seconds/km. This is an estimate, not a promised performance or measured 10K, and requires athlete acceptance. Do not derive a threshold pace mechanically from this estimate. Temperature, terrain and actual session effort take precedence: the athlete slows down if a suggested pace exceeds the target effort.

The 5K in week 4 and 10K in week 10 are separate assessment types with exact distance, elapsed time, environment and route fields. Use elapsed time, not moving time; no auto-pause. Treadmill results must be labelled treadmill. Historical estimates cannot populate these results. Week-4 test is optional on readiness grounds, with a defined replacement in that session. Week-10 10K is the primary assessment.

## Shared run execution

For EVERY run: 3–5 minutes brisk walking beforehand and 3–5 minutes walking afterwards, additional to prescribed RUNNING duration. Add 10 ankle rocks/side, 10 calf raises, 10 controlled leg swings/side before starting. Easy runs start with five especially gentle minutes INCLUDED in their prescribed duration. No stretching holds during hard running.

Quality sessions include their own easy-jog warm-up/cooldown in the session steps. After warm-up, optionally pause for 2–3 minutes of familiar dynamic drills, then start repetitions; do not add unprescribed fast running. Run recoveries at RECOVERY effort. Prescribed interval counts and between-only recoveries are exact. All easy-jog warm-ups/cooldowns count as running volume; walking and drills do not.

Strides are INCLUDED in the listed total run duration: easy lead-in, then N × (20 seconds relaxed quick run + 100 seconds very easy jogging). Thus the full stride block is N × 2 minutes, including recovery after the last stride. Do not add another stride block beyond the listed time. On a treadmill, use controlled acceleration and a safe speed; if transitions are awkward, execute the entire duration easy and record the omission.

## Strength execution and progression

RIR = repetitions remaining with good technique. Choose actual loads from current ability; no guessed kg prescriptions. Bodyweight pull-ups are valid; add weight only if the target reps and RIR are met. If needed use foot-assisted pull-ups with a secure setup (or an available assisted-pull-up machine in Korea). Record assistance separately from added external load.

Standard tempo: controlled lowering (~2 seconds), no forced pause, purposeful lift. Calf raises: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range. Lateral raises: controlled both ways. Carries: normal walking, tall posture, no running. Per-side repetitions/durations apply to EACH side; left+right form one set. RIR does not apply to holds/carries: stop before posture/grip breaks.

Warm-up for each gym session: 5 minutes brisk walking/marching, 10 bodyweight squats, 8 unloaded hinges, 8 scapular pull-ups or shoulder-blade movements, 8 arm circles each direction. For the first loaded lower-body exercise add 2–4 progressively loaded warm-up sets; for each new upper-body pattern add 1–2 light sets as needed. No warm-up set to failure. Finish with 3–5 minutes easy walking.

Repetition ranges are intentional: record completed reps. Once ALL work sets reach the top of the range at target RIR on two exposures, athlete may accept the smallest available load increase (typically 1–2 kg per DB / 2–2.5 kg upper-body barbell / 2.5–5 kg lower-body barbell), returning to the bottom of the range. Never force a load jump or automatically progress. Maintain if running quality or recovery is affected. No 1RM tests or failure training in this block.

If Monday lunges impair Tuesday running, the explicit athlete-selected adjustment is omit Monday lunges for that week; do not move extra leg volume elsewhere. If Thursday strength impairs Sunday long runs, first remove one squat work set. Shoulder pressing uses comfortable range and neutral DB grip if preferred; omit a painful movement and flag it rather than prescribing through pain.

## Recovery and adjustment rules

- Start at the prescribed workload only if the prior week's running was tolerated. Normal mild muscular soreness is acceptable; focal/worsening pain, limping or altered gait is not a progression signal. Stop/shorten the affected run and reassess.
- Accumulating non-painful fatigue: athlete may accept a 20–30% reduction in the next easy/long run and omit strides; quality work can become an equal-duration easy run. Do not automatically reschedule or rewrite started workouts.
- Week-2 travel: Saturday is already rest. If Sunday follows poor sleep or substantial travel fatigue, athlete may choose 25 minutes easy instead of 40, or rest. Do not make up the missing minutes. Keep the original and accepted variant visible.
- If unable to tolerate prescribed increases, repeat the last tolerated week's running structure with its original effort, then review remaining dates; retain the race date and do not compress missed progressions.
- Fuel training normally, including carbohydrate around quality and longer sessions. This block is not an aggressive weight-cut phase. Protein around 1.6–2.2 g/kg/day and adequate overall energy support recovery. Keep sleep and session timing consistent where possible.

## Full calendar

Every entry below is a required authored slot unless marked optional inside its notes. Rest slots contain no required workout.

### Week 01 · 2026-11-02 · Treadmill return: establish four easy runs
**Monday 02 November 2026 · `LW10K-W01-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 1 | 5/leg | 3 | 90 |
| Pull-up | 2 | 5–8 | 3 | 120 |
| DB overhead press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB lateral raise | 2 | 12–15 | 3 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 03 November 2026 · `LW10K-W01-D02`
Main run · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Wednesday 04 November 2026 · `LW10K-W01-D03`
Easy run · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 05 November 2026 · `LW10K-W01-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 2 | 4–6 | 3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 3 | 120 |
| DB bench press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB farmer carry | 2 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 3 | 60 |
| Reverse crunch | 2 | 10–15 | 3 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 06 November 2026 · `LW10K-W01-D05`
Easy run / strides · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Saturday 07 November 2026 · `LW10K-W01-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 08 November 2026 · `LW10K-W01-D07`
Long easy run · **35 minutes running**.
- 35 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 02 · 2026-11-09 · Treadmill consistency; travel to Korea on Saturday
**Monday 09 November 2026 · `LW10K-W02-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 1 | 5/leg | 3 | 90 |
| Pull-up | 2 | 5–8 | 3 | 120 |
| DB overhead press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB lateral raise | 2 | 12–15 | 3 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 10 November 2026 · `LW10K-W02-D02`
Main run · **30 minutes running**.
- 20 min — Easy run (EASY).
- 5 min — Controlled steady segment (STEADY).
- 5 min — Easy cooldown jog (EASY).

**Wednesday 11 November 2026 · `LW10K-W02-D03`
Easy run · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 12 November 2026 · `LW10K-W02-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 2 | 4–6 | 3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 3 | 120 |
| DB bench press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB farmer carry | 2 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 3 | 60 |
| Reverse crunch | 2 | 10–15 | 3 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 13 November 2026 · `LW10K-W02-D05`
Easy run / strides · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Saturday 14 November 2026 · `LW10K-W02-D06`
Rest / travel. No required training. Optional comfortable walking/mobility.

**Sunday 15 November 2026 · `LW10K-W02-D07`
Long easy run · **40 minutes running**.
- 40 min — Continuous run; first 5 minutes particularly gentle (EASY).

Travel variant: choose 25 minutes EASY or rest if travel fatigue/poor sleep; no make-up minutes.

### Week 03 · 2026-11-16 · Outdoor transition and first controlled threshold session
**Monday 16 November 2026 · `LW10K-W03-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 2 | 5/leg | 3 | 90 |
| Pull-up | 3 | 5–8 | 2 | 120 |
| DB overhead press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 2 | 8–12/side | 2 | 90 |
| DB lateral raise | 2 | 12–15 | 2 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 17 November 2026 · `LW10K-W03-D02`
Main run · **36 minutes running**.
- 12 min — Easy warm-up jog (EASY).
- 3 × 4 min THRESHOLD; 2 min RECOVERY BETWEEN repetitions only.
- 8 min — Easy cooldown jog (EASY).

**Wednesday 18 November 2026 · `LW10K-W03-D03`
Easy run · **30 minutes running**.
- 30 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 19 November 2026 · `LW10K-W03-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 3 | 4–6 | 2–3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 2–3 | 120 |
| DB bench press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 3 | 8–12/side | 2 | 90 |
| DB farmer carry | 3 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 2 | 60 |
| Reverse crunch | 2 | 10–15 | 2 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 20 November 2026 · `LW10K-W03-D05`
Easy run / strides · **30 minutes running**.
- 22 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 21 November 2026 · `LW10K-W03-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 22 November 2026 · `LW10K-W03-D07`
Long easy run · **45 minutes running**.
- 45 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 04 · 2026-11-23 · Consolidate and establish a 5K benchmark
**Monday 23 November 2026 · `LW10K-W04-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 1 | 5/leg | 3 | 90 |
| Pull-up | 2 | 5–8 | 3 | 120 |
| DB overhead press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB lateral raise | 2 | 12–15 | 3 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 24 November 2026 · `LW10K-W04-D02`
5K benchmark · distance-based session; total time depends on pace.
- 12 min — Easy warm-up jog (EASY).
- 3 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.
- 2 min — Very easy settle jog (RECOVERY).
- 5000 m assessment — Best sustainable evenly paced effort; no early sprint.
- 10 min — Easy cooldown jog (EASY).

Flat measured course or track preferred. Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause.

First kilometre controlled; settle into sustainable effort; build only in final 1–2 km. If not ready for maximal running, replace WHOLE running session with 35 minutes EASY and leave benchmark unavailable.

**Wednesday 25 November 2026 · `LW10K-W04-D03`
Easy run · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 26 November 2026 · `LW10K-W04-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 1 | 4–6 | 3 | 150–180 |
| Barbell Romanian deadlift | 1 | 6–8 | 3 | 120 |
| DB bench press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB farmer carry | 2 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 3 | 60 |
| Reverse crunch | 2 | 10–15 | 3 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 27 November 2026 · `LW10K-W04-D05`
Easy run / strides · **30 minutes running**.
- 22 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 28 November 2026 · `LW10K-W04-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 29 November 2026 · `LW10K-W04-D07`
Long easy run · **40 minutes running**.
- 40 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 05 · 2026-11-30 · Build threshold duration and aerobic endurance
**Monday 30 November 2026 · `LW10K-W05-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 2 | 5/leg | 3 | 90 |
| Pull-up | 3 | 5–8 | 2 | 120 |
| DB overhead press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 2 | 8–12/side | 2 | 90 |
| DB lateral raise | 2 | 12–15 | 2 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 01 December 2026 · `LW10K-W05-D02`
Main run · **44 minutes running**.
- 12 min — Easy warm-up jog (EASY).
- 3 × 6 min THRESHOLD; 2 min RECOVERY BETWEEN repetitions only.
- 10 min — Easy cooldown jog (EASY).

**Wednesday 02 December 2026 · `LW10K-W05-D03`
Easy run · **35 minutes running**.
- 35 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 03 December 2026 · `LW10K-W05-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 3 | 4–6 | 2–3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 2–3 | 120 |
| DB bench press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 3 | 8–12/side | 2 | 90 |
| DB farmer carry | 3 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 2 | 60 |
| Reverse crunch | 2 | 10–15 | 2 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 04 December 2026 · `LW10K-W05-D05`
Easy run / strides · **35 minutes running**.
- 27 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 05 December 2026 · `LW10K-W05-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 06 December 2026 · `LW10K-W05-D07`
Long easy run · **50 minutes running**.
- 50 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 06 · 2026-12-07 · Extend repeatable threshold work
**Monday 07 December 2026 · `LW10K-W06-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 2 | 5/leg | 3 | 90 |
| Pull-up | 3 | 5–8 | 2 | 120 |
| DB overhead press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 2 | 8–12/side | 2 | 90 |
| DB lateral raise | 2 | 12–15 | 2 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 08 December 2026 · `LW10K-W06-D02`
Main run · **50 minutes running**.
- 12 min — Easy warm-up jog (EASY).
- 3 × 8 min THRESHOLD; 2 min RECOVERY BETWEEN repetitions only.
- 10 min — Easy cooldown jog (EASY).

**Wednesday 09 December 2026 · `LW10K-W06-D03`
Easy run · **35 minutes running**.
- 35 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 10 December 2026 · `LW10K-W06-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 3 | 4–6 | 2–3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 2–3 | 120 |
| DB bench press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 3 | 8–12/side | 2 | 90 |
| DB farmer carry | 3 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 2 | 60 |
| Reverse crunch | 2 | 10–15 | 2 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 11 December 2026 · `LW10K-W06-D05`
Easy run / strides · **35 minutes running**.
- 23 min — Easy run (EASY).
- 6 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 12 December 2026 · `LW10K-W06-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 13 December 2026 · `LW10K-W06-D07`
Long easy run · **55 minutes running**.
- 55 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 07 · 2026-12-14 · Consolidation: reduce running and lifting volume
**Monday 14 December 2026 · `LW10K-W07-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 1 | 5/leg | 3 | 90 |
| Pull-up | 2 | 5–8 | 3 | 120 |
| DB overhead press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB lateral raise | 2 | 12–15 | 3 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 15 December 2026 · `LW10K-W07-D02`
Main run · **41 minutes running**.
- 12 min — Easy warm-up jog (EASY).
- 2 × 8 min THRESHOLD; 3 min RECOVERY BETWEEN repetitions only.
- 10 min — Easy cooldown jog (EASY).

**Wednesday 16 December 2026 · `LW10K-W07-D03`
Easy run · **30 minutes running**.
- 30 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 17 December 2026 · `LW10K-W07-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 1 | 4–6 | 3 | 150–180 |
| Barbell Romanian deadlift | 1 | 6–8 | 3 | 120 |
| DB bench press | 2 | 6–10 | 3 | 90 |
| One-arm DB row | 2 | 8–12/side | 3 | 90 |
| DB farmer carry | 2 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 3 | 60 |
| Reverse crunch | 2 | 10–15 | 3 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 18 December 2026 · `LW10K-W07-D05`
Easy run / strides · **30 minutes running**.
- 22 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 19 December 2026 · `LW10K-W07-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 20 December 2026 · `LW10K-W07-D07`
Long easy run · **45 minutes running**.
- 45 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 08 · 2026-12-21 · 10K-specific repetitions while retaining aerobic volume
**Monday 21 December 2026 · `LW10K-W08-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 2 | 5/leg | 3 | 90 |
| Pull-up | 3 | 5–8 | 2 | 120 |
| DB overhead press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 2 | 8–12/side | 2 | 90 |
| DB lateral raise | 2 | 12–15 | 2 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 22 December 2026 · `LW10K-W08-D02`
Main run · distance-based session; total time depends on pace.
- 15 min — Easy warm-up jog (EASY).
- 4 × 1000 m TEN_K; 2 min RECOVERY BETWEEN repetitions only.
- 10 min — Easy cooldown jog (EASY).

Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available.

**Wednesday 23 December 2026 · `LW10K-W08-D03`
Easy run · **40 minutes running**.
- 40 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 24 December 2026 · `LW10K-W08-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 3 | 4–6 | 2–3 | 150–180 |
| Barbell Romanian deadlift | 2 | 6–8 | 2–3 | 120 |
| DB bench press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 3 | 8–12/side | 2 | 90 |
| DB farmer carry | 3 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 2 | 60 |
| Reverse crunch | 2 | 10–15 | 2 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 25 December 2026 · `LW10K-W08-D05`
Easy run / strides · **35 minutes running**.
- 23 min — Easy run (EASY).
- 6 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 26 December 2026 · `LW10K-W08-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 27 December 2026 · `LW10K-W08-D07`
Long easy run · **60 minutes running**.
- 60 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 09 · 2026-12-28 · Final 10K-specific development; reduce lower-body lifting
**Monday 28 December 2026 · `LW10K-W09-D01`
Strength A · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| DB reverse lunge | 1 | 5/leg | 3 | 90 |
| Pull-up | 3 | 5–8 | 2 | 120 |
| DB overhead press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 2 | 8–12/side | 2 | 90 |
| DB lateral raise | 2 | 12–15 | 2 | 60 |
| Side plank | 2 | 30–40 sec/side | N/A | 45 |

Small maintenance dose; controlled step, no soreness chasing. Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 29 December 2026 · `LW10K-W09-D02`
Main run · distance-based session; total time depends on pace.
- 15 min — Easy warm-up jog (EASY).
- 3 × 1600 m TEN_K; 3 min RECOVERY BETWEEN repetitions only.
- 10 min — Easy cooldown jog (EASY).

Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available.

**Wednesday 30 December 2026 · `LW10K-W09-D03`
Easy run · **35 minutes running**.
- 35 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 31 December 2026 · `LW10K-W09-D04`
Strength B · expected 40–60 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Barbell back squat | 1 | 4–6 | 2–3 | 150–180 |
| Barbell Romanian deadlift | 1 | 6–8 | 2–3 | 120 |
| DB bench press | 3 | 6–10 | 2 | 90 |
| One-arm DB row | 3 | 8–12/side | 2 | 90 |
| DB farmer carry | 2 | 40 sec | N/A | 90 |
| Standing single-leg DB calf raise | 2 | 10–15/leg | 2 | 60 |
| Reverse crunch | 2 | 10–15 | 2 | 60 |

Familiar stance/depth; no grinding. Controlled hinge; stop before spinal position changes. Flat bench; comfortable shoulder range. Support free hand on bench; rest after both sides. Heavy enough to challenge grip with tall posture. Use prescribed calf tempo; rest after both sides. Controlled pelvic curl, no swing.

**Friday 01 January 2027 · `LW10K-W09-D05`
Easy run / strides · **30 minutes running**.
- 22 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 02 January 2027 · `LW10K-W09-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 03 January 2027 · `LW10K-W09-D07`
Long easy run · **50 minutes running**.
- 50 min — Continuous run; first 5 minutes particularly gentle (EASY).

### Week 10 · 2027-01-04 · Freshen up, sharpen and test 10K on Sunday
**Monday 04 January 2027 · `LW10K-W10-D01`
Strength A — test-week reduced upper body · expected 25–35 minutes, including preparation.

| Exercise | Sets | Reps / time | RIR | Rest (seconds) |
|---|---:|---|---|---|
| Pull-up | 2 | 5–8 | 3–4 | 120 |
| DB overhead press | 2 | 6–10 | 3–4 | 90 |
| One-arm DB row | 2 | 8–12/side | 3–4 | 90 |
| DB lateral raise | 1 | 12–15 | 3–4 | 60 |
| Side plank | 1 | 30–40 sec/side | N/A | 45 |

Bodyweight or athlete-selected added load/assistance. Comfortable range; neutral grip permitted. Rest after both sides. No swinging. Stop before posture loss.

**Tuesday 05 January 2027 · `LW10K-W10-D02`
Main run · distance-based session; total time depends on pace.
- 12 min — Easy warm-up jog (EASY).
- 3 × 800 m TEN_K; 2 min RECOVERY BETWEEN repetitions only.
- 8 min — Easy cooldown jog (EASY).

Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available.

**Wednesday 06 January 2027 · `LW10K-W10-D03`
Easy run · **25 minutes running**.
- 25 min — Continuous run; first 5 minutes particularly gentle (EASY).

**Thursday 07 January 2027 · `LW10K-W10-D04`
Rest. No required training. Optional comfortable walking/mobility.

**Friday 08 January 2027 · `LW10K-W10-D05`
Easy run / strides · **20 minutes running**.
- 12 min — Easy run (EASY).
- 4 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.

**Saturday 09 January 2027 · `LW10K-W10-D06`
Rest. No required training. Optional comfortable walking/mobility.

**Sunday 10 January 2027 · `LW10K-W10-D07`
10K final assessment · distance-based session; total time depends on pace.
- 15 min — Easy warm-up jog (EASY).
- 3 × 20 sec STRIDE + 100 sec RECOVERY after EACH repetition, including last.
- 2 min — Very easy settle jog (RECOVERY).
- 10000 m assessment — Best sustainable evenly paced effort; no early sprint.
- 10 min — Easy cooldown jog (EASY).

Flat measured course or track preferred. Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause.

First 2 km controlled; km 3–7 even sustainable effort; assess at 7 km and increase only if able; commit in final kilometre. Use training evidence to select pace. If unwell/in pain, do not force the assessment; retain an unavailable result and review timing.

## Assessment and logging fields

Run completion: elapsed duration, distance, environment (outdoor/treadmill), route/surface, mean pace if valid, lap/repetition results, mean/max HR if available, session RPE, pain/next-day leg response, notes. Heart rate is observational; no guessed zones are required. Record treadmill console distance/speed separately from watch-estimated distance if they differ.

Strength completion: exercise identity, set index, load unit, external load, load interpretation (per dumbbell vs total barbell), reps per side where relevant, achieved RIR, assistance if used, duration/carry load, notes. Two 20 kg dumbbells means 20 kg PER DUMBBELL, not a 20 kg pair. For pull-ups, added load is separate from athlete bodyweight; 0 kg added means bodyweight, not no resistance.

Benchmark result: assessment ID, exact distance, elapsed seconds, source session ID, measured vs estimated status, environment, route, splits, date and explicit selection status. W04 5K and W10 10K retain separate identities. Missing/declined assessments remain unavailable. Optional estimated paces must retain provenance to the selected measured assessment and calculation policy.

## Completion / handoff to the next block

The programme ends after the 10 January assessment. Review the measured result, completed running volume, strength maintenance and recovery before beginning the next HYROX phase. No sub-40 outcome is promised. The next programme owns its recovery transition and station-specific build; do not append extra sessions to this package.

## Machine-readable calendar

The JSON below repeats all 70 authored slots and embeds all strength prescriptions. It uses a SOURCE-CONTENT schema (`lw-training-source/1`), not a Cohort production schema. Narrative shared rules and exercise notes above are binding content and must be carried into the mapping. `null` for total time in distance-based sessions means unknown until pace/completion, not zero or missing work. `work_distance_metres` excludes warm-up, cooldown and jog recoveries.

```json
{
  "source_schema": "lw-training-source/1",
  "programme_id": "LW-10K-HYROX-BASE-20261102",
  "version": "1.0.0",
  "title": "10-week 10K development / HYROX foundation",
  "start_date": "2026-11-02",
  "end_date": "2027-01-10",
  "primary_test_date": "2027-01-10",
  "primary_test_distance_metres": 10000,
  "automatic_progression": false,
  "shared_rules_location": "Narrative sections in this same document",
  "weeks": [
    {
      "week": 1,
      "focus": "Treadmill return: establish four easy runs"
    },
    {
      "week": 2,
      "focus": "Treadmill consistency; travel to Korea on Saturday"
    },
    {
      "week": 3,
      "focus": "Outdoor transition and first controlled threshold session"
    },
    {
      "week": 4,
      "focus": "Consolidate and establish a 5K benchmark"
    },
    {
      "week": 5,
      "focus": "Build threshold duration and aerobic endurance"
    },
    {
      "week": 6,
      "focus": "Extend repeatable threshold work"
    },
    {
      "week": 7,
      "focus": "Consolidation: reduce running and lifting volume"
    },
    {
      "week": 8,
      "focus": "10K-specific repetitions while retaining aerobic volume"
    },
    {
      "week": 9,
      "focus": "Final 10K-specific development; reduce lower-body lifting"
    },
    {
      "week": 10,
      "focus": "Freshen up, sharpen and test 10K on Sunday"
    }
  ],
  "sessions": [
    {
      "session_id": "LW10K-W01-D01",
      "week": 1,
      "day": 1,
      "date": "2026-11-02",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W01-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 1,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-A-E02",
          "exercise": "Pull-up",
          "sets": 2,
          "repetitions_or_duration": "5–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-A-E03",
          "exercise": "DB overhead press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W01-D02",
      "week": 1,
      "day": 2,
      "date": "2026-11-03",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W01-D03",
      "week": 1,
      "day": 3,
      "date": "2026-11-04",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W01-D04",
      "week": 1,
      "day": 4,
      "date": "2026-11-05",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W01-B-E01",
          "exercise": "Barbell back squat",
          "sets": 2,
          "repetitions_or_duration": "4–6",
          "rir": "3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E03",
          "exercise": "DB bench press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E05",
          "exercise": "DB farmer carry",
          "sets": 2,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W01-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W01-D05",
      "week": 1,
      "day": 5,
      "date": "2026-11-06",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W01-D06",
      "week": 1,
      "day": 6,
      "date": "2026-11-07",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W01-D07",
      "week": 1,
      "day": 7,
      "date": "2026-11-08",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 35,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W02-D01",
      "week": 2,
      "day": 1,
      "date": "2026-11-09",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W02-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 1,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-A-E02",
          "exercise": "Pull-up",
          "sets": 2,
          "repetitions_or_duration": "5–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-A-E03",
          "exercise": "DB overhead press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W02-D02",
      "week": 2,
      "day": 2,
      "date": "2026-11-10",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "steady",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 20,
          "effort": "EASY"
        },
        {
          "action": "Controlled steady segment",
          "duration_minutes": 5,
          "effort": "STEADY"
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 5,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W02-D03",
      "week": 2,
      "day": 3,
      "date": "2026-11-11",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W02-D04",
      "week": 2,
      "day": 4,
      "date": "2026-11-12",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W02-B-E01",
          "exercise": "Barbell back squat",
          "sets": 2,
          "repetitions_or_duration": "4–6",
          "rir": "3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E03",
          "exercise": "DB bench press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E05",
          "exercise": "DB farmer carry",
          "sets": 2,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W02-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W02-D05",
      "week": 2,
      "day": 5,
      "date": "2026-11-13",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit."
      ]
    },
    {
      "session_id": "LW10K-W02-D06",
      "week": 2,
      "day": 6,
      "date": "2026-11-14",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest / travel",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W02-D07",
      "week": 2,
      "day": 7,
      "date": "2026-11-15",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 40,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 40,
      "work_distance_metres": null,
      "notes": [
        "Treadmill until 13 November inclusive; 15 November Korea outdoor if conditions permit.",
        "Travel variant: 25 minutes EASY, or rest, if travel fatigue/poor sleep. Athlete explicitly accepts; no make-up minutes."
      ]
    },
    {
      "session_id": "LW10K-W03-D01",
      "week": 3,
      "day": 1,
      "date": "2026-11-16",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W03-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 2,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-A-E02",
          "exercise": "Pull-up",
          "sets": 3,
          "repetitions_or_duration": "5–8",
          "rir": "2",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-A-E03",
          "exercise": "DB overhead press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W03-D02",
      "week": 3,
      "day": 2,
      "date": "2026-11-17",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "threshold_time",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Threshold repetitions",
          "repetitions": 3,
          "work_minutes": 4,
          "work_effort": "THRESHOLD",
          "recovery_minutes": 2,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 8,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 36,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W03-D03",
      "week": 3,
      "day": 3,
      "date": "2026-11-18",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 30,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W03-D04",
      "week": 3,
      "day": 4,
      "date": "2026-11-19",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W03-B-E01",
          "exercise": "Barbell back squat",
          "sets": 3,
          "repetitions_or_duration": "4–6",
          "rir": "2–3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "2–3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E03",
          "exercise": "DB bench press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E04",
          "exercise": "One-arm DB row",
          "sets": 3,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E05",
          "exercise": "DB farmer carry",
          "sets": 3,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W03-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W03-D05",
      "week": 3,
      "day": 5,
      "date": "2026-11-20",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 22,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W03-D06",
      "week": 3,
      "day": 6,
      "date": "2026-11-21",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W03-D07",
      "week": 3,
      "day": 7,
      "date": "2026-11-22",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 45,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 45,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W04-D01",
      "week": 4,
      "day": 1,
      "date": "2026-11-23",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W04-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 1,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-A-E02",
          "exercise": "Pull-up",
          "sets": 2,
          "repetitions_or_duration": "5–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-A-E03",
          "exercise": "DB overhead press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W04-D02",
      "week": 4,
      "day": 2,
      "date": "2026-11-24",
      "weekday": "Tuesday",
      "type": "running",
      "title": "5K benchmark",
      "kind": "test5",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Warm-up strides",
          "repetitions": 3,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        },
        {
          "action": "Very easy settle jog",
          "duration_minutes": 2,
          "effort": "RECOVERY"
        },
        {
          "action": "Measured time trial",
          "distance_metres": 5000,
          "effort": "Best sustainable evenly paced effort; no early sprint"
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": null,
      "work_distance_metres": 5000,
      "notes": [
        "Flat measured course or track preferred. Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause.",
        "First kilometre controlled; settle into sustainable effort; build only in final 1–2 km. If not ready for maximal running, replace WHOLE running session with 35 minutes EASY and leave benchmark unavailable."
      ]
    },
    {
      "session_id": "LW10K-W04-D03",
      "week": 4,
      "day": 3,
      "date": "2026-11-25",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W04-D04",
      "week": 4,
      "day": 4,
      "date": "2026-11-26",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W04-B-E01",
          "exercise": "Barbell back squat",
          "sets": 1,
          "repetitions_or_duration": "4–6",
          "rir": "3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 1,
          "repetitions_or_duration": "6–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E03",
          "exercise": "DB bench press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E05",
          "exercise": "DB farmer carry",
          "sets": 2,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W04-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W04-D05",
      "week": 4,
      "day": 5,
      "date": "2026-11-27",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 22,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W04-D06",
      "week": 4,
      "day": 6,
      "date": "2026-11-28",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W04-D07",
      "week": 4,
      "day": 7,
      "date": "2026-11-29",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 40,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 40,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W05-D01",
      "week": 5,
      "day": 1,
      "date": "2026-11-30",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W05-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 2,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-A-E02",
          "exercise": "Pull-up",
          "sets": 3,
          "repetitions_or_duration": "5–8",
          "rir": "2",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-A-E03",
          "exercise": "DB overhead press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W05-D02",
      "week": 5,
      "day": 2,
      "date": "2026-12-01",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "threshold_time",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Threshold repetitions",
          "repetitions": 3,
          "work_minutes": 6,
          "work_effort": "THRESHOLD",
          "recovery_minutes": 2,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 44,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W05-D03",
      "week": 5,
      "day": 3,
      "date": "2026-12-02",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 35,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W05-D04",
      "week": 5,
      "day": 4,
      "date": "2026-12-03",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W05-B-E01",
          "exercise": "Barbell back squat",
          "sets": 3,
          "repetitions_or_duration": "4–6",
          "rir": "2–3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "2–3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E03",
          "exercise": "DB bench press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E04",
          "exercise": "One-arm DB row",
          "sets": 3,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E05",
          "exercise": "DB farmer carry",
          "sets": 3,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W05-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W05-D05",
      "week": 5,
      "day": 5,
      "date": "2026-12-04",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 27,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W05-D06",
      "week": 5,
      "day": 6,
      "date": "2026-12-05",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W05-D07",
      "week": 5,
      "day": 7,
      "date": "2026-12-06",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 50,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 50,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W06-D01",
      "week": 6,
      "day": 1,
      "date": "2026-12-07",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W06-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 2,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-A-E02",
          "exercise": "Pull-up",
          "sets": 3,
          "repetitions_or_duration": "5–8",
          "rir": "2",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-A-E03",
          "exercise": "DB overhead press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W06-D02",
      "week": 6,
      "day": 2,
      "date": "2026-12-08",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "threshold_time",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Threshold repetitions",
          "repetitions": 3,
          "work_minutes": 8,
          "work_effort": "THRESHOLD",
          "recovery_minutes": 2,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 50,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W06-D03",
      "week": 6,
      "day": 3,
      "date": "2026-12-09",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 35,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W06-D04",
      "week": 6,
      "day": 4,
      "date": "2026-12-10",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W06-B-E01",
          "exercise": "Barbell back squat",
          "sets": 3,
          "repetitions_or_duration": "4–6",
          "rir": "2–3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "2–3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E03",
          "exercise": "DB bench press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E04",
          "exercise": "One-arm DB row",
          "sets": 3,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E05",
          "exercise": "DB farmer carry",
          "sets": 3,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W06-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W06-D05",
      "week": 6,
      "day": 5,
      "date": "2026-12-11",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 23,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 6,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W06-D06",
      "week": 6,
      "day": 6,
      "date": "2026-12-12",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W06-D07",
      "week": 6,
      "day": 7,
      "date": "2026-12-13",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 55,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 55,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W07-D01",
      "week": 7,
      "day": 1,
      "date": "2026-12-14",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W07-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 1,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-A-E02",
          "exercise": "Pull-up",
          "sets": 2,
          "repetitions_or_duration": "5–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-A-E03",
          "exercise": "DB overhead press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W07-D02",
      "week": 7,
      "day": 2,
      "date": "2026-12-15",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "threshold_time",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Threshold repetitions",
          "repetitions": 2,
          "work_minutes": 8,
          "work_effort": "THRESHOLD",
          "recovery_minutes": 3,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 41,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W07-D03",
      "week": 7,
      "day": 3,
      "date": "2026-12-16",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 30,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W07-D04",
      "week": 7,
      "day": 4,
      "date": "2026-12-17",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W07-B-E01",
          "exercise": "Barbell back squat",
          "sets": 1,
          "repetitions_or_duration": "4–6",
          "rir": "3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 1,
          "repetitions_or_duration": "6–8",
          "rir": "3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E03",
          "exercise": "DB bench press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E05",
          "exercise": "DB farmer carry",
          "sets": 2,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W07-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "3",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W07-D05",
      "week": 7,
      "day": 5,
      "date": "2026-12-18",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 22,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W07-D06",
      "week": 7,
      "day": 6,
      "date": "2026-12-19",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W07-D07",
      "week": 7,
      "day": 7,
      "date": "2026-12-20",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 45,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 45,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W08-D01",
      "week": 8,
      "day": 1,
      "date": "2026-12-21",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W08-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 2,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-A-E02",
          "exercise": "Pull-up",
          "sets": 3,
          "repetitions_or_duration": "5–8",
          "rir": "2",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-A-E03",
          "exercise": "DB overhead press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W08-D02",
      "week": 8,
      "day": 2,
      "date": "2026-12-22",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "pace_distance",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 15,
          "effort": "EASY"
        },
        {
          "action": "Current 10K-effort repetitions",
          "repetitions": 4,
          "work_metres": 1000,
          "work_effort": "TEN_K",
          "recovery_minutes": 2,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": null,
      "work_distance_metres": 4000,
      "notes": [
        "Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available."
      ]
    },
    {
      "session_id": "LW10K-W08-D03",
      "week": 8,
      "day": 3,
      "date": "2026-12-23",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 40,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 40,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W08-D04",
      "week": 8,
      "day": 4,
      "date": "2026-12-24",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W08-B-E01",
          "exercise": "Barbell back squat",
          "sets": 3,
          "repetitions_or_duration": "4–6",
          "rir": "2–3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 2,
          "repetitions_or_duration": "6–8",
          "rir": "2–3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E03",
          "exercise": "DB bench press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E04",
          "exercise": "One-arm DB row",
          "sets": 3,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E05",
          "exercise": "DB farmer carry",
          "sets": 3,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W08-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W08-D05",
      "week": 8,
      "day": 5,
      "date": "2026-12-25",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 23,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 6,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W08-D06",
      "week": 8,
      "day": 6,
      "date": "2026-12-26",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W08-D07",
      "week": 8,
      "day": 7,
      "date": "2026-12-27",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 60,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 60,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W09-D01",
      "week": 9,
      "day": 1,
      "date": "2026-12-28",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A",
      "exercises": [
        {
          "exercise_occurrence_id": "W09-A-E01",
          "exercise": "DB reverse lunge",
          "sets": 1,
          "repetitions_or_duration": "5/leg",
          "rir": "3",
          "rest_seconds": "90",
          "notes": "Small maintenance dose; controlled step, no soreness chasing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-A-E02",
          "exercise": "Pull-up",
          "sets": 3,
          "repetitions_or_duration": "5–8",
          "rir": "2",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-A-E03",
          "exercise": "DB overhead press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-A-E05",
          "exercise": "DB lateral raise",
          "sets": 2,
          "repetitions_or_duration": "12–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-A-E06",
          "exercise": "Side plank",
          "sets": 2,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W09-D02",
      "week": 9,
      "day": 2,
      "date": "2026-12-29",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "pace_distance",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 15,
          "effort": "EASY"
        },
        {
          "action": "Current 10K-effort repetitions",
          "repetitions": 3,
          "work_metres": 1600,
          "work_effort": "TEN_K",
          "recovery_minutes": 3,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": null,
      "work_distance_metres": 4800,
      "notes": [
        "Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available."
      ]
    },
    {
      "session_id": "LW10K-W09-D03",
      "week": 9,
      "day": 3,
      "date": "2026-12-30",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 35,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 35,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W09-D04",
      "week": 9,
      "day": 4,
      "date": "2026-12-31",
      "weekday": "Thursday",
      "type": "strength",
      "title": "Strength B",
      "exercises": [
        {
          "exercise_occurrence_id": "W09-B-E01",
          "exercise": "Barbell back squat",
          "sets": 1,
          "repetitions_or_duration": "4–6",
          "rir": "2–3",
          "rest_seconds": "150–180",
          "notes": "Familiar stance/depth; no grinding.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E02",
          "exercise": "Barbell Romanian deadlift",
          "sets": 1,
          "repetitions_or_duration": "6–8",
          "rir": "2–3",
          "rest_seconds": "120",
          "notes": "Controlled hinge; stop before spinal position changes.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E03",
          "exercise": "DB bench press",
          "sets": 3,
          "repetitions_or_duration": "6–10",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Flat bench; comfortable shoulder range.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E04",
          "exercise": "One-arm DB row",
          "sets": 3,
          "repetitions_or_duration": "8–12/side",
          "rir": "2",
          "rest_seconds": "90",
          "notes": "Support free hand on bench; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E05",
          "exercise": "DB farmer carry",
          "sets": 2,
          "repetitions_or_duration": "40 sec",
          "rir": "N/A",
          "rest_seconds": "90",
          "notes": "Heavy enough to challenge grip with tall posture.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E06",
          "exercise": "Standing single-leg DB calf raise",
          "sets": 2,
          "repetitions_or_duration": "10–15/leg",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Use prescribed calf tempo; rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W09-B-E07",
          "exercise": "Reverse crunch",
          "sets": 2,
          "repetitions_or_duration": "10–15",
          "rir": "2",
          "rest_seconds": "60",
          "notes": "Controlled pelvic curl, no swing.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "40–60",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W09-D05",
      "week": 9,
      "day": 5,
      "date": "2027-01-01",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 22,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 30,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W09-D06",
      "week": 9,
      "day": 6,
      "date": "2027-01-02",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W09-D07",
      "week": 9,
      "day": 7,
      "date": "2027-01-03",
      "weekday": "Sunday",
      "type": "running",
      "title": "Long easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 50,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 50,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W10-D01",
      "week": 10,
      "day": 1,
      "date": "2027-01-04",
      "weekday": "Monday",
      "type": "strength",
      "title": "Strength A — test-week reduced upper body",
      "exercises": [
        {
          "exercise_occurrence_id": "W10-A-E02",
          "exercise": "Pull-up",
          "sets": 2,
          "repetitions_or_duration": "5–8",
          "rir": "3–4",
          "rest_seconds": "120",
          "notes": "Bodyweight or athlete-selected added load/assistance.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W10-A-E03",
          "exercise": "DB overhead press",
          "sets": 2,
          "repetitions_or_duration": "6–10",
          "rir": "3–4",
          "rest_seconds": "90",
          "notes": "Comfortable range; neutral grip permitted.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W10-A-E04",
          "exercise": "One-arm DB row",
          "sets": 2,
          "repetitions_or_duration": "8–12/side",
          "rir": "3–4",
          "rest_seconds": "90",
          "notes": "Rest after both sides.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W10-A-E05",
          "exercise": "DB lateral raise",
          "sets": 1,
          "repetitions_or_duration": "12–15",
          "rir": "3–4",
          "rest_seconds": "60",
          "notes": "No swinging.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        },
        {
          "exercise_occurrence_id": "W10-A-E06",
          "exercise": "Side plank",
          "sets": 1,
          "repetitions_or_duration": "30–40 sec/side",
          "rir": "N/A",
          "rest_seconds": "45",
          "notes": "Stop before posture loss.",
          "tempo": "Shared standard; calf-specific tempo if calf raise"
        }
      ],
      "expected_duration_minutes": "25–35",
      "instructions": [
        "Apply shared warm-up, tempo, load-selection and progression rules."
      ]
    },
    {
      "session_id": "LW10K-W10-D02",
      "week": 10,
      "day": 2,
      "date": "2027-01-05",
      "weekday": "Tuesday",
      "type": "running",
      "title": "Main run",
      "kind": "pace_distance",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Current 10K-effort repetitions",
          "repetitions": 3,
          "work_metres": 800,
          "work_effort": "TEN_K",
          "recovery_minutes": 2,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": false
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 8,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": null,
      "work_distance_metres": 2400,
      "notes": [
        "Use current fitness/accepted benchmark estimate, never aspirational sub-40 pace. No exact total duration can be known before run pace is available."
      ]
    },
    {
      "session_id": "LW10K-W10-D03",
      "week": 10,
      "day": 3,
      "date": "2027-01-06",
      "weekday": "Wednesday",
      "type": "running",
      "title": "Easy run",
      "kind": "easy",
      "steps": [
        {
          "action": "Continuous run; first 5 minutes particularly gentle",
          "duration_minutes": 25,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": 25,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W10-D04",
      "week": 10,
      "day": 4,
      "date": "2027-01-07",
      "weekday": "Thursday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W10-D05",
      "week": 10,
      "day": 5,
      "date": "2027-01-08",
      "weekday": "Friday",
      "type": "running",
      "title": "Easy run / strides",
      "kind": "strides",
      "steps": [
        {
          "action": "Easy run",
          "duration_minutes": 12,
          "effort": "EASY"
        },
        {
          "action": "Strides",
          "repetitions": 4,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        }
      ],
      "prescribed_total_running_minutes": 20,
      "work_distance_metres": null,
      "notes": []
    },
    {
      "session_id": "LW10K-W10-D06",
      "week": 10,
      "day": 6,
      "date": "2027-01-09",
      "weekday": "Saturday",
      "type": "rest",
      "title": "Rest",
      "instructions": [
        "No required training. Normal walking and optional gentle mobility; do not make up missed sessions."
      ]
    },
    {
      "session_id": "LW10K-W10-D07",
      "week": 10,
      "day": 7,
      "date": "2027-01-10",
      "weekday": "Sunday",
      "type": "running",
      "title": "10K final assessment",
      "kind": "test10",
      "steps": [
        {
          "action": "Easy warm-up jog",
          "duration_minutes": 15,
          "effort": "EASY"
        },
        {
          "action": "Warm-up strides",
          "repetitions": 3,
          "work_seconds": 20,
          "work_effort": "STRIDE",
          "recovery_seconds": 100,
          "recovery_effort": "RECOVERY",
          "recovery_after_last": true
        },
        {
          "action": "Very easy settle jog",
          "duration_minutes": 2,
          "effort": "RECOVERY"
        },
        {
          "action": "Measured time trial",
          "distance_metres": 10000,
          "effort": "Best sustainable evenly paced effort; no early sprint"
        },
        {
          "action": "Easy cooldown jog",
          "duration_minutes": 10,
          "effort": "EASY"
        }
      ],
      "prescribed_total_running_minutes": null,
      "work_distance_metres": 10000,
      "notes": [
        "Flat measured course or track preferred. Record elapsed time, exact distance, route/surface, weather, splits, RPE and environment. Disable auto-pause.",
        "First 2 km controlled; km 3–7 even sustainable effort; assess at 7 km and increase only if able; commit in final kilometre. Use training evidence to select pace. If unwell/in pain, do not force the assessment; retain an unavailable result and review timing."
      ]
    }
  ]
}
```
