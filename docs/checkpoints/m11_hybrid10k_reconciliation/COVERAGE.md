# M1.1 general Hybrid 10K — reconciled source and actual local admission

2026-10-30 (Asia/Makassar), base `0f0c40d`. **M1.1 PARTIAL / GATE A OPEN.**
[Current source](../../programmes/hybrid_10k/general_draft_2026_10_30/README.md),
[ordered review](../../programmes/hybrid_10k/general_draft_2026_10_30/ORDERED_REVIEW.md),
[arithmetic](../../programmes/hybrid_10k/general_draft_2026_10_30/AUDIT.json),
[actual probe output](ADMISSION.json).

## Discrepancy resolutions

| Earlier retained material | Current controlling resolution |
|---|---|
| Lee-specific return-to-running / travel / treadmill start framed as source purpose | General fit-runner Hybrid 10K PB scope. Personal assumptions/variants remain historical and separate; no general entry workload is invented. Unselected doses remain draft. |
| 40 runs / 19 strength / 11 rest | **40 / 20 / 10**. Week 10 Thursday restored: two comfortable sets of retained shoulder press and bench-supported row each, at least 3 RIR, no lower-body lifting. Original rep ranges/rests retained; no invented upper RIR bound. |
| W4 Tue: measured 5K with 12-minute warm-up, strides/settle and 10-minute cooldown | Founder-selected 13-minute warm-up + **4×5-minute threshold** with three 90-second recoveries + 5-minute run/walk cooldown = **42:30**. No in-programme 5K test. |
| W8 Tue: 4×1 km | Same selected warm-up + **3×9-minute current-10K** with two 2-minute recoveries + selected cooldown = **49:00**. |
| W9 Tue: 3×1600 m | Same warm-up + **3×6-minute current-10K**, two 2-minute recoveries + cooldown = **40:00**. |
| W10 Tue: 3×800 m | Same warm-up + **3×2-minute current-10K**, two 2-minute recoveries + cooldown = **28:00**. |
| Five distance bodies | **39 timed runs / one distance-ended final 10K**. The first four changes use explicit founder doses, not pace-derived time substitutions. |
| RPE-led easy work / observational HR | Confirmed Zone 2 is primary on main EASY work. Supporting effort instructions remain; missing configuration/review refuses start rather than falling back silently. |
| Do not derive threshold pace from the 5K reference; only after W4 test | Superseded by the unchanged approved M2.3 source/rule/selection contracts. No in-programme benchmark or automatic ingestion is required/invented. |
| Four founder questions from 28 October | Scope, W10, primary Zone 2 and governing quality rules are now resolved. Detailed blanket content/publication approval remains absent. |

The selected warm-up is exactly 10 minutes easy plus three 20-second relaxed
accelerations each followed by 40 seconds very easy running: **13 minutes**.
All selected recoveries occur between work repetitions only. Accelerations,
warm-up, easy recoveries and the chosen run/walk cooldown gain no fixed pace.
No extra mandatory walk phase is appended to these selected exact bodies.

## Exact weekly totals

Programmed durations include all phases/recoveries and the four five-minute
run-or-walk cooldowns. Running volume excludes any actual walking. All other
retained timed totals are rechecked; the final distance elapsed time stays unknown.

| Week | Programmed minutes | Running-minute bounds | Strength |
|---|---:|---:|---|
| 1 | 110 | 110 | Two retained draft sessions |
| 2 | 120 | 120 | Two; personal travel alternatives excluded |
| 3 | 141 | 141 | Two |
| 4 | 137:30 | 132:30–137:30 | Two |
| 5 | 164 | 164 | Two |
| 6 | 175 | 175 | Two |
| 7 | 146 | 146 | Two |
| 8 | 184 | 179–184 | Two |
| 9 | 155 | 150–155 | Two |
| 10 | 106 + actual elapsed 10K | 101–106 + actual elapsed 10K | Two upper-body sessions; Thursday has four work sets |

Totals across the source: **1438:30 programmed fixed minutes + actual elapsed 10K**;
running fixed volume **1418:30–1438:30 + actual elapsed 10K**. These are bounds for
the stated cooldown choice, not a claim about actual completed volume. Additional
walking substitutions within recovery would reduce actual running further and must
remain actual observations. Generic extra walks/drills outside retained core
workouts and gym ramp sets/transitions are not included in these programmed sums.

There are **124 strength exercise occurrences and 263 work sets**. Existing gym
40–60-minute estimates remain estimates. W10 Monday retains 25–35 minutes; no new
Thursday total is fabricated. There is no exact all-training elapsed weekly total.

## Unique strength variants and identity evidence

The intake deduplicates **16 possible exact/underspecified variants across 12 source
labels**, rather than treating 124 occurrences as independent founder decisions.
Pull-up bodyweight/weighted/foot-assisted/machine-assisted options stay distinct.
Monday's support-unspecified DB row and Thursday's bench-supported row are not
silently merged. [Full evidence and occurrence bindings](../../programmes/hybrid_10k/general_draft_2026_10_30/IDENTITY_INTAKE.json).

| Class | Exact movement / identity | Meaning |
|---|---|---|
| Verified local slot match | Barbell back squat `EX-073`; barbell RDL `EX-078`; bilateral DB farmer carry `EX-101`; side plank `EX-116` | Full explicit published catalogue row declarations from pinned Wave 1 SQL, file/row hashes and source revision. **37 occurrences** resolve through existing v1/v2 intake. |
| Verified local option, not selected | Weighted pull-up `EX-095` | Exact local row exists; generic pull-up slots also allow other options, so the weighted identity is not assigned automatically. |
| Candidate only | Bodyweight pull-up `EX-053`; DB strict/overhead press `EX-037`; Monday/Thursday one-arm DB row `EX-038`; DB lateral raise `EX-044` | Approved bridge and/or historical export leads retained with full fields/hash. Missing exact setup/branch or admissible runtime row evidence is not replaced by display-name matching. |
| Missing exact retained variant | DB reverse lunge; foot-assisted pull-up; machine-assisted pull-up; flat DB bench press; standing single-leg DB calf raise; reverse crunch | No exact matching local runtime identity established. No allocation, version or approval event invented. |

The historical Field Manual CSV was inspected as candidate evidence only. Its
`Published=Yes` flag does not become a current trusted runtime row, authoritative
version or hosted-state claim. The separately prohibited review-only raw export
was not loaded. HYROX's unpublished definition proposals were not adopted.

The four actual bound movements use exact declared rows and explicit supported
references (approved transitional bridge for squat/RDL/carry; exact row slug for
side plank), not exercise display names. Row identity from repository declarations
is a **local v1/v2 catalogue match**, not canonical ExerciseDefinition version/event
retention or live catalogue verification. `exercises_v2` has no version column;
no new version field or deferred v3 producer dependency is manufactured.

## Actual local contract results

| Attempt | Actual result | Limit |
|---|---|---|
| Full schedule compiler v1/v2 | Both pass, **60 session references**, 70 dated source days and ten rests; canonical artifacts reverify | Draft compilation, not content approval or publication |
| Full reviewed graph admission using available running bodies | Both refuse `protocol_graph_scope_mismatch` | Twenty strength sessions still lack complete exact-bound graphs. No null-ID/empty-body placeholder submitted. |
| Individual exact running graphs | **39 timed bodies pass both schemas**; final 10K refuses `unsupported_timed_running_body` | Structural local validation only |
| Source target/plan serialization | All 39 timed plans preserve exact bodies/markers through the existing codec | No real athlete inputs, review packet or session fabricated |
| Start without accepted personal targets | Refuses for all marked genuine timed bodies | Explicit owner confirmation/review/acceptance and canonical freeze remain required |
| Trusted importer identity resolution | **37 resolved / 87 unresolved occurrences**, four exact bound IDs | Five historical candidate variants and six missing variants stay unassigned; weighted option stays unselected |
| Native prescription validation/round-trip | **124 pass** with per-side reps/holds, exact/range rest and RIR, kg interpretation, tempo and source details | No guessed load, reduced rest range or invented RIR bound; source-specific minimum RIR remains explicit in cue/details |

The approved versions remain `alpha_5k_8w_riegel_1_06_v1`,
`alpha_manual_threshold_pm2_v1`, `authored_rpe_v1`. Their exact bytes/formulas,
0..56 matching-IANA civil-day freshness, half-up nearest-second bounds, retained
decimal intermediates, explicit threshold-only manual selection, review/acceptance
and frozen started/completed prescriptions are unchanged. No scalar `fallback_rpe`
is authored from a range. The source has no automatic fallback.

Existing native fields already represent the source's ranges, per-side doses and
load labels. No demonstrated runtime/schema intake defect required implementation.
The bounded source tool corrects the earlier empty-catalogue attempt by using exact
pinned legitimate repository rows, and the reviewed-JSON path avoids the automatic
founder builder's lossy range/identity conversion. No generic infrastructure added.

## Short unresolved list

Eight source labels remain unbound: DB reverse lunge; pull-up option set; DB overhead
press; one-arm DB row setup(s); DB lateral raise; flat DB bench; single-leg DB calf
raise; reverse crunch. Resolve exact variants and legitimate catalogue evidence;
do not substitute walking lunge, barbell/incline/floor bench, cable/bilateral row,
cable lateral raise, front plank or bilateral/machine calf raise.

General entry workload and the remaining detailed programme still need exact content
review. The four selected run replacements, weekly counts, Zone 2 primacy and M2.3
rule precedence do **not** need to be asked again. An integer authored-RPE fallback
is a separate content choice only if desired, not a required new formula decision.

## Final test and release dependencies

Final Sunday remains a measured **10,000 m** test with 33 minutes of retained timed
warm-up/strides/settle/cooldown outside its measured segment. The time-only runner
cannot execute that ending. The smallest follow-up remains an explicit distance-
ending phase through existing admission/controller/cursor/UI/persistence/restore,
with reviewed measured-distance confirmation, actual segment elapsed time, pauses
and no duplicate completion. A timed estimate is not an acceptable substitute.
Validated benchmark ingestion, complete observation fields and comparison authority
remain separate; no actual/result is invented from a prescribed distance.

No complete genuine programme was published, acquired, started, completed or
restored canonically. Exact identity completion, complete graph/content review,
compatible-client acceptance, separately authorised publication/recipient eligibility,
held M1.2/Zone 2/quality/retry migrations, authenticated device acceptance, adaptation,
distribution, feedback and inherited bootstrap triage remain Gate A dependencies.
Hosted Supabase state remains unknown; no hosted operation or keep-alive occurred.

M2.5 implementation/verification was not repeated. Founder-supplied facts now name
Forerunner 255 and application not submitted, with firmware/Connect/HR source still
unknown. Access/contracts and authoritative binary FIT proof remain external gates.
