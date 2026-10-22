# HYROX Base approved decisions and bounded delivery

2026-10-22. Founder supplied and approved the [exact retained brief](FOUNDER_BRIEF.txt).
This supersedes the source-absence decision only for the facts and doses supplied here.
The [earlier decision](../hyrox_base_source_readiness/DECISION.md), source inventory and
readiness report remain an accurate dated record. No earlier report is rewritten into
approval. Remote main was freshly verified at `fa5186fab8c1038fdb1972aea75a3880935c2d2f`.

## Approved programme purpose and schedule

Eight weeks of aerobic and basic strength development before specific HYROX preparation.
Base means purpose, not beginner status: developing and advanced athletes can participate.
Minimum running ability is 45 continuous minutes. Six training days, one session/day,
generally 60–90 minutes; Sunday rest. Weeks 1–3 build, Week 4 mainly reduces gym volume
and finishers with modest running reduction, Weeks 5–7 build, Week 8 consolidates.
No compulsory post-Base assessment; representative benchmarks are needed before the next
plan. Athletes choose within duration windows by feel/recovery without level bands.

| Day | Approved order/content |
| --- | --- |
| Monday Gym A | Back squat; strict overhead press + pull-ups; suitcase carry; rowing intervals |
| Tuesday | Easy run |
| Wednesday Gym B | RDL; incline DB press + chest-supported row; long-lever plank; mixed conditioning |
| Thursday | Quality run |
| Friday Gym C | Front-rack reverse lunge; DB shoulder press + split-stance single-arm cable row; Pallof press; SkiErg/wall balls |
| Saturday | Long easy run |
| Sunday | Rest |

All three aerobic sessions intend running. Eligible bike substitutions preserve effort
and duration, never running pace, and require verified existing app rules plus athlete
acceptance. No new exercise substitution mappings or identities are supplied here.
Wall balls use chosen race division weight and standard height; exact current division
mappings remain an unverified source input. No default or copied race rule is invented.

## Approved shared benchmark set

10 km run completion time; 2 km row completion time; back squat 5RM total external load;
strict overhead press 5RM total external load; maximum strict pull-ups (zero valid).
Every entry requires its own test date and clear source/type. No freshness cutoff is
approved or inferred. Known results can be entered and Base can start with missing
metrics; missing never means zero. Numeric targets stay unavailable when prerequisites
are absent. Effort fallbacks apply only where authored below.

Optional HYROX Test Week is a **separate current programme before Base**. Its exact
sessions/protocols have not been authored/approved; this task implements no Test Week,
assessment attempt, completion claim or automatic insertion of tests into Base.

## Approved eight-week doses

All running durations below are minutes; quality recoveries are two minutes easy
jogging **between** repetitions. Warm-up/cooldown are additional; aim to keep full
sessions within about 90 minutes. Row recoveries are seconds, between repetitions only.
Squat percentages refer to 5RM external load, never estimated 1RM.

| Week | Easy run | Quality run | Long run | Dedicated row | Back squat | %5RM | RIR |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 45–60 | 4×4 | 50–70 | 6×2 min / 90 s | 3×8 | 80 | 3 |
| 2 | 45–65 | 5×4 | 55–75 | 7×2 / 90 s | 3×8 | 82.5 | 2–3 |
| 3 | 50–65 | 4×6 | 60–80 | 5×3 / 90 s | 4×6 | 87.5 | 2 |
| 4 | 45–60 | 4×4 | 55–70 | 4×2 / 90 s | 2×6 | 70 | 4 |
| 5 | 50–65 | 5×5 | 60–80 | 6×2 / 75 s | 4×6 | 87.5 | 3 |
| 6 | 50–70 | 4×7 | 65–80 | 7×2 / 75 s | 4×5 | 90 | 2–3 |
| 7 | 55–70 | 3×10 | 65–80 | 5×3 / 75 s | 4×4 | 95 | 2 |
| 8 | 45–60 | 4×5 | 55–75 | 4×2 / 90 s | 2×5 | 75 | 3–4 |

Run 10 km pace = completion seconds / 10 (seconds/km). The controlled interval
starting windows multiply **pace** by 1.00–1.05 for 4–5 min, 1.02–1.07 for 6–7 min,
and 1.03–1.08 for 10 min. Lower pace bound is faster. They are Base-specific authored
starting windows, approximate RPE 7/repeatable, not measured physiological thresholds.
Easy/long effort is conversational / RPE about 3–4; established athlete HR guidance
may be used if available. No HR zones are manufactured.

Row 2 km split = completion seconds / 4 (seconds/500 m). Add 10–15 s for two-minute
reps, 12–18 s for three-minute reps. Week 4 overrides to +18–23 s, Week 8 to +15–20 s.
These windows apply only to dedicated intervals, never rowing inside mixed WODs.
No missing-row numerical or newly authored effort fallback is supplied.

Squat load = 5RM × authored percentage, rounded to the **configured available total
barbell increment**, nearest, ties down. No increment is guessed. Missing benchmark
or increment gives unavailable numerical load plus authored RIR; technique/RIR govern
athlete adjustments. Prescribed versus actual loads stay separate. Other strength uses
its own authored sets/reps/RIR and previous relevant performance: no squat-to-RDL/lunge
conversion, press derivation or pull-up load calculation is authorised by these rules.

A benchmark replacement needs explicit acceptance before future targets change. Started
and completed prescriptions/results remain immutable. Completion never triggers automatic
progression. Local selection must be deliberate; no latest/best inference is introduced.

## Engineering choices, distinct from content approval

The delivered rule identifier is `hyrox-base-personalisation-v1`. Every preview includes
the exact retained brief SHA-256, selected benchmark identity/source/date/value/digest,
week, authored values and exact calculated values. This is a local review format,
**not** a canonical programme, approval token, production binding or writable actuals API.

Input decimals have at most ten whole digits and six fractional digits. Durations
normalise exactly to integer milliseconds; loads to integer micrograms; counts remain
integer. Pounds convert exactly by 1 lb = 453.59237 g. Unrepresentable precision refuses,
never silently rounds a benchmark. Technical storage limits are 1e9 ms/count and 1e15
micrograms (no physiological eligibility/freshness meaning). Equipment increments are
explicit positive integer grams, at most 1e9. Exact rational arithmetic and BigInt
intermediates preserve deterministic results on VM and JavaScript; display rounds pace
to nearest tenth-second only, while exact rational bounds remain in review snapshots.

Synthetic owners are fixed to `synthetic-a`/`synthetic-b`. Entries are immutable and
append-only by ID; replacement gets a new ID and explicit selection consent. Source
type is an athlete declaration, not source/assessment verification. Invalid input is
explicit and invalidates current preview/consent. Selection/configuration/edit/disposal
and newer reviews invalidate pending work; replies must match the captured calculation.
Local started snapshots retain full prescription objects and remain independent of new
benchmarks. Local completion can record separate actual squat grams through the controller;
it never changes selections or prescription. All local state is memory-only; reload or
switching synthetic scenario discards that scenario's state. No persistence is delivered.

## Remaining exact source inputs

The approved brief is a partial source, **not a publishable 48-session package**. Still
needed: sets/reps/RIR/rest/tempo/cues and progression for strict press/pull-ups, suitcase
carry, RDL, incline DB press/row, plank, lunges, DB press/cable row and Pallof; exact
Wednesday mixed conditioning, Friday SkiErg/wall-ball work and finisher progression;
warm-up/cooldown/supporting work; exact exercise variants and caller-supplied authoritative
published definition versions; accepted source-to-canonical bindings; capture/scoring
fields; complete immutable week/day/session sources; truthful equipment/prerequisite
and exclusion copy; and only such substitution variants as already verified or separately
authored/approved. Squat rest/tempo/supporting instructions are also not supplied.

No exact current race-division wall-ball standard is verified. That remains input work,
not an assumed mapping. Test Week needs its own complete authored protocols and approval.
A complete programme still needs compiler/import/representation proof for every distinct
block/timer, coaching/editorial review, production-path completion/history/device checks,
immutable publication runbook and separate hosted operation authority. Broader Stage 2,
Sprint C, native browser gaps and four phone checks remain open.
