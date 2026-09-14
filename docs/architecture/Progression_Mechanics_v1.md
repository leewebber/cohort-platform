# Progression Mechanics v1

**Status:** Binding for Progression Mechanics Validation — Sprint 1  
**Baseline:** `origin/main` `4725c8ced4e13757c7ac206415ee5115c9199acd`  
**Founder build:** Cohort Platform 1.0.0 (5)  
**Does not modify:** [`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md), [`Architecture_Freeze_v1.md`](./Architecture_Freeze_v1.md)

This is the first product phase after Phase 1 Integration Closeout. It is
**observational**. It does not author prescriptions, apply adaptation, or
advance a programme.

```text
PROGRESSION_MECHANICS_V1_AUTHORISED=true
PROGRESSION_IS_OBSERVATIONAL=true
AUTHORED_PRESCRIPTION_REMAINS_AUTHORITY=true
ADAPTATION_REMAINS_ACCEPTANCE_GATED=true
ESTIMATED_1RM_IS_NOT_PRIMARY_VERDICT=true
```

---

## Purpose

Prove that Cohort can turn repeated training records into accurate, useful,
and honest progression information:

```text
Perform → Record → Recall → Compare → Explain → Display in Progress
```

Phase 1 already owns **perform / record / recall** for programme strength
history. This contract owns **compare / explain / display**.

## Frozen dependencies (do not duplicate)

| Concern | Binding source |
|---|---|
| Authored programme vs adaptation | [`Canonical_Programme_Architecture_Freeze_v1.md`](./Canonical_Programme_Architecture_Freeze_v1.md) |
| Acceptance-gated adaptation | [`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md) |
| Adaptation may not rewrite the programme | [`Adaptation_Policy_v1.md`](./Adaptation_Policy_v1.md) |
| Calendar occurrences | [`Athlete_Controlled_Programme_Scheduling_v1.md`](./Athlete_Controlled_Programme_Scheduling_v1.md) |
| Completion records athlete actuals | Phase 1 completion / training-session record contracts |
| Previous strength recall | Programme Active Session + `PreviousStrengthPerformanceService` (hotfix `be4d421`) |
| Athletic time | `PerformanceChronology` / `TrainingSessionRecord.performanceChronologyAt` |

Previous-performance **display before capture** remains available even when
prescriptions differ. That recall path must not be rewritten by this sprint.

---

## Observational boundary

The engine may show previous performance, factual deltas, personal bests,
trends, and a repeated decline/recovery **signal** for later adaptation work.

It must not:

- force progression
- change authored loads, reps, exercise selection, or RPE targets
- prefill today’s actuals
- tell the athlete to add load because last time went well
- treat attendance or session count as Strength / Endurance / Power
- compare incompatible sessions
- fabricate PBs or regression
- auto-apply adaptation or schedule change
- mark the athlete as failing

If adaptation hooks already exist, emit only typed evidence. Do not apply.

---

## Evidence eligibility

Progression may use only valid athlete performance evidence.

**Eligible**

- completed training-session records
- completed exercises/sets inside a valid partially completed record
- live performances
- valid Backfill performances (`entry_mode = backfill`)
- the canonical corrected result (not superseded drafts)
- ended-early evidence where the metric still supports an honest comparison
  (for example more work before a cap)

**Excluded**

- prescription without actuals
- incomplete drafts / in-progress records as “previous”
- abandoned records
- invalidated or replaced correction versions
- duplicate/idempotent retry records
- another athlete’s data
- preview fixtures in production
- values inferred only from timer progress
- empty warm-up sets with no meaningful actual (no load, no reps)

The current session/record is never its own previous result.

The engine must keep these layers distinct:

1. prescribed target
2. completed actual
3. outcome / completion context (complete, partial, ended early, time-capped)
4. athlete effort (RPE when present)
5. provenance (live, Backfill, correction)
6. evidence confidence

---

## Chronology

Use **one** shared implementation: `PerformanceChronology`.

| Mode | Athletic time |
|---|---|
| Live | truthful performed / start / completion chronology already on the record |
| Backfill | `performed_on` (date precision) |

Never use Backfill `created_at`, `recorded_at`, or upload time as athletic
chronology.

Rules:

- latest means latest **performed**, not latest uploaded
- older Backfill inserts into historical order
- same-date date-only evidence is ordered deterministically by `record_id`
  without inventing clock precision
- a correction replaces the effective result; it is not a new performance
- Progress, completed-session comparison, and workout-player history sort
  with the same comparator

---

## Comparison identity

Display title is never the sole identity.

| Evidence | Comparison key |
|---|---|
| Strength | canonical `exercises_v2.exercise_id` plus load-kind / unit context |
| Intervals | protocol/benchmark family (`comparisonFamily`) + work duration + pace unit + scoring format |
| Circuit / EMOM / AMRAP / for-time | format + scoring contract + compatible station/prescription signature (`comparisonFamily`) |
| Steady-state endurance | format + prescribed objective (duration vs distance vs intensity aim) |

Do not require identical week, day, session title, block ID, protocol-step ID,
or programmed session key. Authored week-to-week progression must still be able
to show last-time facts.

When the prescription changes as authored progression:

- still show last-time facts
- explain what changed
- limit the verdict (`Mixed`, `Not comparable`, or `Insufficient evidence`)
- do not erase history

Do not compare a Zone 2 run to threshold intervals merely because both have
distance and time.

---

## Canonical vocabulary

One shared outcome vocabulary. Widgets must not invent a second scoring
language.

| Outcome | Meaning |
|---|---|
| First performance | No eligible prior comparable evidence |
| Improved | At least one primary comparable dimension improved without a material opposing decline |
| Matched | Materially equivalent completed performance within tolerance |
| Below last performance | Lower performance under a genuinely comparable prescription and completion context |
| Mixed | One meaningful dimension improves while another declines, or prescription change prevents a clean verdict |
| Not comparable | Incompatible identity, format, or technique/load kind |
| Insufficient evidence | Missing actuals or context required for the claimed outcome |

These are **observations**, not instructions. Every comparison also exposes
factual deltas, for example:

- `+5 kg at the same reps`
- `+2 reps at the same load`
- `Same result at RPE 7 vs 8`
- `12 sec faster`
- `1 additional interval completed`
- `Matched last performance`
- `Prescription changed — comparison limited`

Do not reduce every result to a single positive/negative score.

Estimated 1RM is **not** the primary v1 conclusion. Existing Epley helpers may
remain as optional secondary facts only. A dedicated 1RM contract is out of
scope.

### Tolerance (v1)

Numeric match uses the existing Phase 1 band unless a format defines otherwise:

- relative `1%` of the previous value, or
- absolute `0.5` in the metric’s unit (kg, seconds of pace, etc.)

whichever is larger. Integer reps match exactly unless stated.

RPE:

- comparable effort when both values are missing, or differ by less than 1
- meaningfully lower effort: previous − current ≥ 1
- materially higher effort: current − previous ≥ 2 (forces Mixed when other
  work improved)

---

## Strength

Primary identity: canonical exercise ID.

Factual dimensions:

- completed set count
- top-set load (heaviest completed external load; ties broken by reps)
- top-set reps
- load at a matched rep count
- reps at a matched load
- total valid external-load volume (`load × reps` of completed sets)
- prescribed-set completion when known
- RPE when available
- partial / end-early context

**Improved** examples:

- heavier load for equal or greater reps at comparable effort
- more reps at the same load at comparable effort
- same load/reps at meaningfully lower RPE

**Matched:** equivalent top-set load and reps within tolerance.

**Below last performance:** lower comparable top-set work.

**Mixed** examples:

- heavier load but materially fewer reps
- greater volume but lower top-set performance
- improved work at materially higher RPE
- volume up only because more sets were prescribed or completed

**Not comparable / insufficient:** variant mismatch, missing actuals, bodyweight
vs external load, empty warm-up sets.

Volume increase alone is never Strength **Improved** when the extra volume is
an extra prescribed (or extra completed) set.

Previous-performance ghosts remain positional and do not prefill actuals.

---

## Personal bests

Distinct metrics, never a generic “PB” badge on every set.

| Type | Definition |
|---|---|
| Heaviest completed load | Max completed external load for that exercise |
| Most completed reps at a specified load | Most completed reps at a load that already has prior completed evidence |
| Highest valid comparable session volume | Highest `load × reps` session total, only when not merely caused by additional prescribed or extra completed sets |

A PB must use actual completed evidence, name its metric and exercise, keep the
performed date, survive Backfill chronology, recalculate after correction, and
never derive from a prescription. Variants stay separate.

**Announcement priority (dedupe):** when one session creates multiple
technically valid bests, announce in this order and drop redundant labels:

1. **Heaviest completed load** — only if the load is strictly heavier than
   every prior eligible session. A first visit to a load is this type, not a
   reps-at-load best.
2. **Most completed reps at a specified load** — only if a prior completed set
   exists at that same load, and the current reps exceed that prior. Do not
   infer this type from insufficient history. Do not label every improved set
   as a PB: more reps at an already-established heaviest load is this type, not
   a second heaviest-load badge.
3. **Highest valid comparable session volume** — only when the volume increase
   is not merely additional prescribed or extra completed sets, and is not
   already explained by the load/rep bests.

Never announce a generic “PB” on every improved set.

---

## Intervals and running

Require structured protocol identity and compatible prescription (same family,
work duration, pace unit).

Evaluate: intervals prescribed/completed, distance, work/total duration,
average pace, interval pace, consistency (pace spread), recovery duration,
completion state, RPE, time-cap / ended-early.

**Improved:** faster average pace with comparable effort and no material
consistency loss; more prescribed work completed before stopping; same work at
lower RPE.

**Mixed:** faster average but materially worse consistency; faster at materially
higher RPE; more work under changed recovery.

**Not comparable:** different distance basis, interval/recovery structure, or
scoring contract.

---

## Steady-state endurance

Facts: prescribed duration completed, distance, average pace, RPE, completion
state. Heart rate is future (wearables).

Until intensity evidence exists, do **not** auto-label a faster Zone 2 run as
Improved. Use restrained language:

- `5 sec/km faster at the same reported RPE`
- `Completed the full prescribed duration`
- `Insufficient intensity evidence for a progression verdict`

Separate performance facts from training-quality claims.

---

## Circuit and conditioning

Format-specific scoring: EMOM, AMRAP, for-time, fixed-duration, chipper,
general circuit, time-capped work.

- **EMOM:** same interval duration, interval count, compatible station sequence
  and targets. Adjusted-target work is not silently identical to prescribed
  target work.
- **AMRAP:** rounds + additional reps in the same time domain and structure.
- **For-time:** completion status first, then time. Do not present a faster
  “completion” when neither attempt finished the prescription.
- **Time-capped / ended early:** more work before the cap may be reported.

---

## Evidence confidence

Internal only in v1. Do not show percentages.

| Level | When | Language |
|---|---|---|
| High | Same identity, compatible prescription, complete actuals | `Improved — 5 kg heavier for the same reps` |
| Moderate | Same identity, limited prescription variation | `More work completed; this week prescribed an additional set` |
| Low | Partial evidence or missing effort/context | `Last performance available, but comparison is limited` |
| None | Not comparable or first performance | `First comparable performance` / not-comparable copy |

Confidence controls wording, not a gamified score.

---

## Presentation

**Before capture (existing card):** last performed date, prior completed sets,
per-set ghosts. Never prefill. Never “beat this”.

**After exercise/session complete:** concise comparison summary, expandable
factual breakdown, first-performance and precise PBs, changed-prescription
limits.

**Home completed-today:** only the most useful session-level highlights.

**Progress:** programme-wide history — sessions completed, **Training
Discipline** (sessions due so far), recent performances, exercise bests,
comparison highlights, PBs, format histories, radar **framework**,
low-evidence states.

Live workout must not block Begin/Resume on optional history.

---

## Training Discipline (time-eligible)

Discipline is **not** programme completion.

Previous (incorrect) formula:

```text
completed sessions ÷ every required session in the programme
```

Corrected formula:

```text
completed eligible sessions ÷ all eligible sessions due so far
```

Example: 84 programme sessions, 7 due, 6 complete, 1 incomplete, 77 future
→ **6 / 7 = 86%**, not 6 / 84 = 7%.

**Eligibility** uses the assignment IANA timezone and Calendar occurrence
`scheduledDate` (effective date after reschedule). An occurrence is
denominator-eligible when its effective date is before athlete-local today,
or it is scheduled today and already terminal (complete, partial-complete,
explicit skip). Today Planned / In progress are excluded until terminal or
the local date rolls. Authored rest, empty dates, cancelled/`replaced`
slots, and future unfinished sessions are excluded.

**Partial completion:** binary count. `completed_partial` is a canonical
terminal completion (`isTerminal: true`, calendar state `COMPLETED`) so
numerator +1 and denominator +1. No 0.5 fraction. Show the partial count
in detailed evidence.

**Reschedule** counts one occurrence once on its effective date. **Swap**
keeps two independent occurrences. Backfill / Train today on a past
incomplete session change the numerator only.

---

## Progress radar

- Discipline may use the time-eligible due-so-far percentage. Future
  sessions must not suppress the axis.
- Strength, Endurance, Power, Threshold, Durability, Mobility must **not**
  fill from session count.
- Performance axes require suitable performance evidence. None exists as a
  founder-approved capability-scoring formula in this sprint, so those axes
  stay unavailable / provisional rather than inventing scores.
- Two completed strength sessions may show an initial **strength evidence
  list**. Session count alone must not raise a capability score.

---

## Correction and Backfill

Correction replaces the effective comparison source, recomputes affected
PBs/comparisons, keeps the audit trail, and does not appear as a new performed
session.

Backfill enters by `performed_on`, participates when valid, keeps Backfill
provenance, and is not newest merely because it was entered later.

---

## Architecture

```text
Persistence retrieves evidence
  → EligiblePerformanceEvidence + PerformanceChronology
  → format-specific comparison services (pure)
  → athlete-facing projection
  → widgets display only
```

Widgets must not independently decide Improved / Matched / Below.

---

## Retrieval (v1 operational, not long-term)

Client history bounded at 40 session records is acceptable for founder dogfood.
It is not the long-term design. See
[`Progression_Mechanics_v1_Retrieval_Proposal.md`](./Progression_Mechanics_v1_Retrieval_Proposal.md).
Do not raise the client limit indefinitely. Do not apply hosted RPCs without
founder approval.

---

## Out of scope

M9 Content Relationship Graph, new capability-scoring formula, wearables,
forced progression, hosted mutation, phone rebuild.
