# General Hybrid 10K PB — active selected performance source

Running prescriptions selected 2026-11-03. Strength is unchanged. Full D8, founder usability, catalogue retention and Gate A remain open. No publication/assignment authority.

All session time includes prescribed timed preparation/recoveries/cooldown; permitted walking is not running volume. No external walks/drills are added to running.

## Exact strength setup, preparation and logging

Monday standard work: approximately 30° bilateral incline DB press 3×6–10, 2 RIR, 120 sec rest; strict shoulder-width overhand pull-up 3×5–8, 2 RIR, 120 sec rest, bodyweight initially; bilateral chest-supported DB row 3×8–12, 1–2 RIR, 90 sec rest; DB lateral raise 3×12–20, 1–2 RIR, 60 sec rest; standing square-stance cable Pallof at chest height, both hands on handle, no torso rotation, 2×10/side, controlled, 45–60 sec rest, no RIR/failure requirement.

Thursday standard selected work: barbell RDL 2×5–6, 2–3 RIR, 120–180 seconds rest; two DBs at sides, neutral grip reverse lunge 1×6/leg, 2–3 RIR, one side then the other, 90 sec rest after both; seated near-upright back-supported two-DB neutral strict press without leg drive 3×6–10, 2 RIR, 120 sec rest; free-hand bench-supported single-arm DB row 3×8–12/side, 1–2 RIR, 90 sec after both sides; bilateral machine standing calf 2×10–15, 2 RIR, 60–90 sec rest; bodyweight side plank 2×30–45 sec/side, 45–60 sec rest, stop before posture loss, no failure target.

Gym preparation (retained proposal except the W10 Thursday restriction): 5 minutes brisk walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles in each direction. For the first loaded lower-body exercise add 2–4 progressively loaded warm-up sets; for each new upper-body pattern add 1–2 light sets as needed. No warm-up set to failure. W10 Thursday: upper-body preparation only, 1–2 light sets per new upper-body pattern as needed; no squat/hinge or loaded lower-body work inserted. Finish every gym session with 3–5 minutes easy walking.

Retained proposed tempo: controlled lowering approximately 2 seconds, no forced pause, purposeful lift; lateral raises controlled both ways; calves approximately 2 sec up, 1 sec at top, 2 sec down through comfortable range. Pallof uses controlled execution and side plank a controlled hold. RIR means reps left with good technique; core work has no RIR/failure requirement. Each per-side dose applies to EACH side; both sides form one set. D4 and Thursday row rest follows both sides; no extra intra-side rest or fixed transition duration is invented.

Choose actual loads from current ability; no guessed kg. DB load is external load **per dumbbell** (including bilateral rows), barbell RDL is total external barbell load. Machine/cable resistance retains actual displayed unit and setup; do not assume cross-machine equivalence. Bodyweight is the initial pull-up branch. Added load is conditional on an exact retained supported weighted identity and explicit selection; do not silently change canonical exercise identity as “progression”. Foot-assisted and machine-assisted branches remain unresolved and separate; never encode assistance as negative added load. Do not prefill actuals.

Retained proposed progression: once ALL work sets reach the top of the rep range at target RIR on two exposures, the athlete may accept the smallest available load increase (typically 1–2 kg per DB, 2–2.5 kg upper-body barbell or 2.5–5 kg lower-body barbell), returning to the bottom of the range. Never force a load jump or progress automatically. Maintain if running quality/recovery is affected. No 1RM or failure tests. Week-specific no-planned-load-increase instructions override this generic proposal (W4 RDL; W8 lower-body work). This is D8 review content, not automatic runtime authority.

## Approved personalised quality-target rules — exact retained behaviour

| Source/rule | Exact admitted behaviour |
|---|---|
| `five_k` / `alpha_5k_8w_riegel_1_06_v1` | Athlete-entered representative sustained 5K, date and explicit sustained-effort confirmation. P5=T5/5; estimatedT10=T5×2^1.06; P10=estimatedT10/10. Threshold: P10×1.02..1.06; 10K-specific: P10×0.99..1.02; short-5K: P5×1.00..1.03. |
| `manual_threshold` / `alpha_manual_threshold_pm2_v1` | Explicit athlete selection only for threshold-labelled work. Entered pace in seconds/km ×0.98..1.02. Origin is manual entry or manually read from Garmin; neither means a Garmin connection. Founder approved this exact window in the reply above. |
| `authored_rpe` / `authored_rpe_v1` | Explicit alternative only if every marked work step contains a valid authored `fallback_rpe` (integer CR10 1..10). No estimated pace, automatic fallback or invented RPE. |

Pace bounds use **seconds per kilometre**, rounded independently to nearest whole
second with **exact halves upward**: floor(x+0.5) for positive values. Calculate
from unrounded intermediate values. Lower is the faster bound, upper the slower;
require positive integers and lower < upper after rounding. SQL uses numeric power
and arithmetic; Dart uses equivalent calculations, with exact integer-ratio rounding
for manual/short-5K boundaries. SQL is the authoritative frozen calculation; client
checks the approved bounds. Full intermediate decimal values are retained as strings
so JSON round-trip does not weaken exact snapshot equality.

The preceding eight weeks means **0 through 56 local civil days inclusive**, in the
confirmed training/assignment IANA timezone. Today and exactly 56 days ago qualify;
57 days and future dates do not. It is a versioned alpha rule, not a physiological
guarantee. No rolling UTC-hour/DST cutoff. Server transaction time determines today;
clients cannot backdate it. A timezone change/mismatch requires reconfirmation in the
matching training timezone. Review hashes include the evaluation date/timezone; a
new start across midnight may need renewed review. Frozen starts do not expire.

Inputs accept whole seconds in 1..86400 as a structural one-day bound, not an entry
standard or suitability decision; reject windows that collapse after rounding. No
age-based Zone 2 formula, manual-threshold elapsed-time expiry, automatic completed
activity ingestion or general benchmark evidence reclassification is introduced.
The athlete must confirm inputs, review the selected source/targets/limitations and
explicitly accept the exact review before a new start. Later replacement/withdrawal
changes only future starts after review. Started/completed prescriptions stay frozen.

## Catalogue and approval boundary

All 20 complete strength sessions remain blocked by 28 occurrences across the three missing exact library setups. Strength/evidence bytes are unchanged; no catalogue identities, publication or assignment are fabricated. Full D8 and usability acceptance remain pending.

## Week 1 — Performance foundation
Timed session total: 192:30.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Threshold intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
10. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
12. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
13. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
14. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
15. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 42:30.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 35:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 45:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 30:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 40:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 55:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 65:00.

## Week 2 — Threshold build
Timed session total: 206:00.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Threshold intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Threshold running — 8:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **Threshold running — 8:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **Threshold running — 8:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 46:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 35:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 45:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 35:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 45:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 60:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 70:00.

## Week 3 — Threshold build
Timed session total: 219:00.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Threshold intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Threshold running — 9:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **Threshold running — 9:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **Threshold running — 9:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 49:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 40:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 50:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Easy run with relaxed strides

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 29:40**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
4. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
5. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
6. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
7. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
8. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
9. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
10. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
11. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 45:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 65:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 75:00.

## Week 4 — Consolidation
Timed session total: 187:30.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 2 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 2 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 2 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 2 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Consolidation threshold

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
10. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
12. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
13. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
14. **Threshold running — 5:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
15. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 42:30.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 30:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 40:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. No planned load increase this week. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 2 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 2 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 30:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 40:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 55:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 65:00.

## Week 5 — Threshold development
Timed session total: 222:00.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Threshold intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Threshold running — 10:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **Threshold running — 10:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **Threshold running — 10:00**. Personalised threshold. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 52:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 40:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 50:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Easy run with relaxed strides

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 29:40**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
4. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
5. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
6. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
7. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
8. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
9. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
10. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
11. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 45:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 65:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 75:00.

## Week 6 — 10K specificity plus short-5K Friday
Timed session total: 201:30.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — 10K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
14. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
15. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 48:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 40:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 50:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Short-5K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
3. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
4. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
5. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
6. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
7. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
8. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
10. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
12. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 28:30.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 65:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 75:00.

## Week 7 — Standard build; not consolidation
Timed session total: 204:00.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — 10K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **10K pace running — 8:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **10K pace running — 8:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **10K pace running — 8:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 46:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 40:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 50:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5–6; RIR 2–3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 2–3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Short-5K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Short-5K pace running — 2:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
3. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
4. **Short-5K pace running — 2:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
5. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
6. **Short-5K pace running — 2:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
7. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
8. **Short-5K pace running — 2:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **Short-5K pace running — 2:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 33:00.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 65:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 75:00.

## Week 8 — Peak Tuesday specificity; lighter Friday
Timed session total: 192:30.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 3 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 3 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 3 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 3 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 2 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Peak 10K specificity

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **10K pace running — 9:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **10K pace running — 9:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **10K pace running — 9:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 49:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 35:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 45:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 2 × 5; RIR 3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. No planned load increase this week. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB reverse lunge**: 1 × 6/leg; RIR 3; rest 90 sec. Two dumbbells at sides, neutral grip; complete one side then the other. Rest 90 seconds after both sides. Log external load per dumbbell. No planned load increase this week. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 3 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 3 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 2 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. No planned load increase this week. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 2 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Short-5K intervals — lighter Friday

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
3. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
4. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
5. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
6. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
7. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
8. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 23:30.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 65:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 75:00.

## Week 9 — Reduce fatigue
Timed session total: 168:30.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 2 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 2 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 2 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 2 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 1 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — 10K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **10K pace running — 6:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 40:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 35:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 45:00.

### Thursday — Thursday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Barbell Romanian deadlift**: 1 × 5; RIR 3; rest 120–180 sec. Thursday barbell RDL; controlled hinge, stop before spinal position changes. Log total external barbell load. Membership and dose explicitly selected. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Seated back-supported neutral-grip DB press**: 2 × 6–10; RIR 2; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 2 × 8–12/side; RIR 1–2; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral machine standing calf raise**: 1 × 10–15; RIR 2; rest 60–90 sec. Standing calf machine, bilateral; no unilateral DB substitution. Record actual machine resistance with its displayed unit/setup; no invented load or cross-machine equivalence. Tempo: ~2 seconds up, 1-second top pause, ~2 seconds down; full comfortable range (retained proposed tempo)
- **Bodyweight side plank**: 1 × 30–45 sec/side; RIR N/A; rest 45–60 sec. Each side 30–45 seconds; both sides form one set. Stop before posture loss; no external load or failure requirement. Tempo: Controlled hold; stop before posture loss
3–5 minutes easy walking; retained proposed finish.

### Friday — Short-5K intervals

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
3. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
4. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
5. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
6. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
7. **Easy recovery — 1:30**. Authored effort, no fixed pace/HR. Easy effort.
8. **Short-5K pace running — 1:00**. Personalised short-5K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 23:30.

### Saturday — Rest

Rest.

### Sunday — Long Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 50:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 60:00.

## Week 10 — Taper and distance-ended 10K test
Timed session total: 103:00 + actual 10K elapsed time.

### Monday — Monday selected strength

Retained proposed preparation: 5 minutes walking/marching; 10 bodyweight squats; 8 unloaded hinges; 8 scapular pull-ups OR shoulder-blade movements; 8 arm circles each direction. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets; each new upper-body pattern: 1–2 light sets as needed; no failure. Bodyweight squats/unloaded hinges are preparation, not working squat/RDL prescriptions.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Bilateral incline DB press**: 2 × 6–10; RIR 2; rest 120 sec. Approximately 30° bench; bilateral dumbbells. Log external load per dumbbell. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Strict bodyweight pull-up**: 2 × 5–8; RIR 2; rest 120 sec. Shoulder-width overhand grip; strict. Bodyweight initially; no invented body mass or zero-kg actual. Added load requires the exact supported weighted identity and explicit selection; assistance remains separate. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bilateral chest-supported DB row**: 2 × 8–12; RIR 1–2; rest 90 sec. Bilateral dumbbells, chest supported. Log external load per dumbbell; not a unilateral or machine substitute. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **DB lateral raise**: 1 × 12–20; RIR 1–2; rest 60 sec. Bilateral dumbbells; no swinging. Log external load per dumbbell. Tempo: Controlled both ways
- **Square-stance cable Pallof press**: 1 × 10/side; RIR N/A; rest 45–60 sec. Standing square stance; cable at chest height, both hands on handle; press without torso rotation. Each side has 10 reps; both sides form one set. No failure requirement or invented RIR. Tempo: Controlled execution
3–5 minutes easy walking; retained proposed finish.

### Tuesday — Taper sharpening

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **10K pace running — 2:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
9. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
10. **10K pace running — 2:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
11. **Easy recovery — 2:00**. Authored effort, no fixed pace/HR. Easy effort.
12. **10K pace running — 2:00**. Personalised current 10K. Use the athlete’s separately reviewed and accepted personalised target.
13. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running or walking; walking is included in session time.

Total 28:00.

### Wednesday — Zone 2 run

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Zone 2 running — 25:00**. Athlete-confirmed Zone 2. Use the athlete-confirmed numerical Zone 2 range.
3. **Very easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Very easy running; walking permitted.

Total 35:00.

### Thursday — Upper-body taper exception

Upper-body preparation only; 1–2 light sets per new upper-body pattern as needed, no failure. No lower-body lifting or squat/hinge warm-up inserted.
Exact founder-selected standard and week-specific doses; full programme D8 review pending.
- **Seated back-supported neutral-grip DB press**: 2 × 6–10; RIR at least 3; rest 120 sec. Near-upright back support; seated, two dumbbells, neutral grip, strict without leg drive. External load per dumbbell. Comfortable upper-body work; at least 3 RIR, no invented upper bound; no lower-body lifting or additional working exercises. At least 3 RIR; no invented upper RIR bound. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
- **Bench-supported single-arm DB row**: 2 × 8–12/side; RIR at least 3; rest 90 sec. Free hand supported on bench; complete both sides, then rest 90 seconds. External load per dumbbell. Comfortable upper-body work; at least 3 RIR, no invented upper bound; no lower-body lifting or additional working exercises. At least 3 RIR; no invented upper RIR bound. Tempo: Retained controlled standard, ~2 seconds lowering, no forced pause, purposeful lift
3–5 minutes easy walking; retained proposed finish.

### Friday — Easy run with relaxed strides

1. **Very easy warm-up — 5:00**. Authored effort, no fixed pace/HR. Very easy running.
2. **Easy running — 6:00**. Authored effort, no fixed pace/HR. Easy running.
3. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
4. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
5. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
6. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
7. **Relaxed stride — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
8. **Very easy recovery — 1:00**. Authored effort, no fixed pace/HR. Very easy running.
9. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy running.

Total 20:00.

### Saturday — Rest

Rest.

### Sunday — 10K final assessment

1. **Easy warm-up — 10:00**. Authored effort, no fixed pace/HR. Easy running.
2. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
3. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
4. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
5. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
6. **Relaxed acceleration — 0:20**. Authored effort, no fixed pace/HR. Relaxed and controlled, not a sprint.
7. **Very easy recovery — 0:40**. Authored effort, no fixed pace/HR. Very easy running.
8. **Easy settling — 2:00**. Authored effort, no fixed pace/HR. Easy walking or jogging before the test.
9. **10,000 m test — 10,000 m (distance ended)**. Authored effort, no fixed pace/HR. Distance-ended test; confirm actual external distance.
10. **Easy cooldown — 5:00**. Authored effort, no fixed pace/HR. Easy walking or jogging. No additional walks or drills are appended.

Total 20:00 + actual 10K elapsed time.
