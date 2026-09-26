# Lee Bali Hybrid Base — Phase 1 model-capability audit

**Recorded:** 2026-09-26
**Branch:** `feat/lee-bali-hybrid-base-v1`
**Base:** `origin/main` `ae5028a02229d8c6b8f15d4fedf1f6dcbf350b61`
**Source:** `/Users/leewebber/Downloads/Cohort_Bali_8_Week_Hybrid_Base_Programme.docx`
(entire document read; DOCX not edited; `(1)` copy not present)
**Verdict:** **STOP before authoring.**

```text
LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
```

---

## Preflight

| Check | Result |
|-------|--------|
| `origin/main` / start HEAD | `ae5028a02229d8c6b8f15d4fedf1f6dcbf350b61` |
| Worktree before branch | clean |
| Running Workout B1 | on `origin/main` (operationally complete) |
| Programme Studio Stage 1 | complete |
| B2 | not present |
| Programme-content branch | none; this branch created locally |
| `.env` SHA-256 | `869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816` |
| Hosted access | none |

---

## Source inventory (as written)

Eight-week endurance-led hybrid base. Saturday start. No running required.
Primary outcome is the platform for a later 16-week elite HYROX race phase.

### Weekly pattern (Weeks 1–3, 5–7)

| Day | Session 1 | Session 2 |
|-----|-----------|-----------|
| Saturday | Strength A — Heavy Lower + Pull | — |
| Sunday | Long Aerobic — BikeErg (AM) | Upper Strength (PM) |
| Monday | Threshold A — BikeErg (AM) | Muscular Endurance (PM) |
| Tuesday | Aerobic Efficiency — BikeErg | — |
| Wednesday | VO2max — BikeErg | — |
| Thursday | Strength C — Lower + Pull + running prep | — |
| Friday | RowErg sub-threshold (W1–3) or Threshold B (W5–7) | — |

Week 1: **9 sessions**. Weeks 2–3 and 5–7: same nine slots with authored
progressions (duration, density, load, interval count).

### Week 4 — consolidation + testing (8 sessions)

No muscular-endurance, no dedicated VO2, no second threshold. Monday
20-min BikeErg benchmark; Wednesday 2 km Row; Friday aerobic-efficiency
test. Sunday still AM + PM.

### Week 8 — taper + exit testing spillover

Week 8 begins Saturday and continues through the **following** Saturday
and Sunday (strength primer → easy aerobic → 20-min Bike → recovery →
2 km Row → easy + running prep → relative-strength tests → recovery →
aerobic-efficiency test). That is **nine authored days** in week 8 and
**58 calendar days** from Saturday 26 September 2026 through Sunday
22 November 2026. The document does not call this a ninth week.

### Other source requirements

Progression and recovery rules; morning monitoring; session logging;
Week 3 Friday expendable-to-Z2 rule; Weeks 5–7 protection tiers;
`90–95% P20` as authored guidance after the Week 4 Bike test; athlete-
selected strength loads; RPE/RIR; benchmark machine/settings metadata;
Programme Execution Notes for Cohort. No extra finishers.

---

## 1. Multiple sessions on one calendar day

**Package:** supported. A training day may have multiple slots;
`session_order` must be contiguous from 1; `time_of_day` may be
`morning` / `afternoon`. Identities (`session_key`, `slot_key`,
`session_lineage_id`) are stable across compile.

**Materialisation / calendar:** **not faithful.**
`ensure_programme_schedule_projection` walks executable slots in
week/day/session order and sets

`scheduled_date = started_at + v_day_offset`

then increments `v_day_offset` per slot. Two Sunday slots become
Sunday and Monday. Home and Daily Journey resolve by
`scheduled_date`, so AM/PM order would appear as two different days.

**Stop condition hit:** double sessions cannot be executed on the
authored calendar day.

---

## 2. Final-week spillover

**Package:** representable as eight weeks. Validator requires
contiguous `week_number` from 1 and contiguous `day_order` from 1 per
week. It does **not** cap days-per-week at 7. `duration_weeks: 8`
matches eight week records. Week 8 can carry `day_order` 1–9 without
relabelling the programme as nine weeks.

**Calendar:** the honest placement is

`started_at + (week_number - 1) * 7 + (day_order - 1)`

which puts week 8 day 9 on start+57 (22 November 2026) and keeps weeks
1–7 on a Saturday-start 7-day grid. The **current** per-slot increment
does not implement that formula.

**Stop condition hit:** spillover cannot be executed faithfully until
calendar placement uses authored days.

---

## 3. Session structures

Strength (sets, reps, RPE/RIR, rest), time-based Bike/Row intervals,
2 km Row tests, 20-min Bike tests, fixed-output efficiency tests,
carries/sled/mixed ME, recovery/optional days, and comparison metadata
are all **authorable** as protocol blocks + Plan Package assessments
without changing Plan Package schema. `%P20` and “Zone 2” remain
prose/guidance. No invented watts, HR zones, or loads.

Founder YAML + Plan Package is the existing pipeline (Apollo schedule
package + committed protocols). No second programme format is required.

---

## 4. Existing execution support

| Kind | Today |
|------|--------|
| Strength sets/reps/RPE | Structured capture |
| Time-based Bike/Row intervals | Existing interval / endurance timers and capture |
| Steady aerobic / 20-min Bike | Endurance capture; watts/HR as entered actuals |
| 2 km Row | For-time / endurance capture + notes for splits |
| Sled / carry / mixed ME | Largely notes + manual loads; do not invent GPS distance steps |
| Benchmark damper/drag/bodyweight | Notes / session fields; no metrics-profile work |
| RunningWorkout B1 | Projection only; not execution authority; no B2 |
| Adaptive tiering / replace Friday | Coaching notes only; no adaptation engine |

---

## 5. Assignment transition (code only; no hosted read)

| Mechanism | Preserves Apollo as `reassigned`? | Keeps Bali private? |
|-----------|-----------------------------------|---------------------|
| `enrol_athlete_in_catalogue_programme_version` + `p_replace_active` | Yes (exact-version pin; prior row retained) | **No** — version must be catalogue-eligible |
| Dual-role / coach INSERT RLS | No lifecycle semantics | Possibly, but not a product transaction |
| Service-role DML | Forbidden | Forbidden |

**Stop condition hit:** no supported transaction makes Bali current
**and** keeps it withheld from the public catalogue.

Lee’s live Apollo assignment was not inspected. Identity must come
from authenticated profile authority at the later approved hosted
step, never from a guessed UUID.

---

## Stop conditions evaluated

| Condition | Hit? |
|-----------|------|
| Double sessions cannot be represented faithfully | **Yes** (calendar/execution) |
| Week 8 spillover cannot be represented faithfully | **Yes** (calendar/execution) |
| Compiler would omit or reorder sessions | No |
| Unapproved schema/runtime change required | **Yes** (projection date rule; private enrol RPC) |
| Second programme authority | Avoided by stopping |
| Apollo must be deleted / falsely completed | Not required if replace-active is used later |
| No supported private Apollo→Bali transition | **Yes** |
| Materially ambiguous prescription | No — source is executable as written |
| Private publication cannot be guaranteed via existing enrol | **Yes** |

---

## Smallest integrity-preserving next work

See
[`../architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md`](../architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md).
Do not weaken the source (no combining AM/PM, no dropping spillover
days, no nine-week relabel, no public-catalogue workaround).
