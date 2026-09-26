# Lee Bali Hybrid Base — implementation contract

**Status:** Local programme authored. Awaiting founder visual review.
Do not publish hosted or change Lee’s assignment.
**Base:** `origin/main` `ae5028a02229d8c6b8f15d4fedf1f6dcbf350b61`
**Source authority:** founder-supplied DOCX
`Cohort_Bali_8_Week_Hybrid_Base_Programme.docx` (not edited; not copied
into the repository).
**Audit:**
[`../checkpoints/LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md`](../checkpoints/LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md)
**Handoff:**
[`../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md`](../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md)

```text
PRIVATE_PROGRAMME_INFRASTRUCTURE=APPROVED
LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_VISUAL_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=true
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Live status is `BLOCKED_PENDING_INFRASTRUCTURE` until the authorised
calendar and private-enrol slice lands. This contract does **not** mean
the programme was authored, compiled, published, or assigned.

This is **not** commercial HYROX Base. Do not name or classify it as
such. The general `PROGRAMME_CONTENT_AUTHORING_AUTHORISED` flag remains
false.

---

## Existing runtime authorities (unchanged)

| Concern | Authority |
|---------|-----------|
| Catalogue pin | Plan Package v1 + immutable `programme_version` |
| Executable session | `performance_protocols` + `session_blocks` |
| Timer / execution | `WorkoutFormat` + `TimerConfiguration` |
| Calendar placement | `ensure_programme_schedule_projection` → `programme_schedule_occurrences.scheduled_date` |
| Current programme | one active `programme_assignments` row |
| Catalogue enrolment | `enrol_athlete_in_catalogue_programme_version` (requires `cohort_global` + `approved_for_global`) |

Apollo remains the current production internal programme. This task
must not delete, falsely complete, or overwrite Apollo history.

---

## Intended product identity (when authoring is later authorised)

- Title: Bali Hybrid Base
- Athlete: Lee
- Classification: Internal / athlete-specific
- Visibility: private / withheld from public catalogue
- Duration label: 8-week hybrid base
- Environment: functional or CrossFit-style gym
- Running required: no
- Start date: Saturday 26 September 2026
- Timezone: Asia/Makassar
- First session: Week 1 Saturday, Strength A — Heavy Lower + Pull

---

## Phase 1 verdict

**Do not author the Plan Package, protocols, Studio fixture, or hosted
publication until the two blocking gaps below are authorised.**

The source can be expressed as Plan Package v1 **text and slot
structure**. It cannot yet be executed or assigned without distortion
or public-catalogue eligibility.

### Blocking gap 1 — calendar placement of same-day sessions

Plan Package v1 already supports multiple slots on one day
(`session_order`, optional `time_of_day` `morning` / `afternoon`).
The compiler does not omit or reorder those slots.

`ensure_programme_schedule_projection` (latest:
`supabase/migrations/20260803180000_apply_programme_schedule_undo_horizon.sql`)
assigns `scheduled_date = started_at + v_day_offset` and increments
`v_day_offset` **once per executable slot**, not once per authored
day. Sunday AM BikeErg and Sunday PM upper strength would receive
**consecutive calendar dates**. Week 1’s nine sessions would occupy
nine dates instead of seven. That is execution distortion.

Week 8’s testing spillover (Saturday through the following Sunday;
58 calendar days from 26 September 2026) is representable in the
package as **eight weeks**, with week 8 carrying nine contiguous
`day_order` values. The validator does not require exactly seven days
per week. The same per-slot date increment would still mis-place those
days. Do not relabel the programme as nine weeks.

### Blocking gap 2 — private assignment transition

The only integrity-preserving **product** transaction that marks the
prior assignment `reassigned`, sets `superseded_by_assignment_id`, and
creates a new exact-version pin is
`enrol_athlete_in_catalogue_programme_version(..., p_replace_active)`.
It requires catalogue eligibility: published + `cohort_global` +
`owner_type = global` + `approved_for_global`. That would expose Bali
on the public athlete catalogue.

`coach_assigned` / `dual_role_self` are reserved enrolment-source
labels. Dual-role INSERT RLS is not a lifecycle transaction: it does
not reassign Apollo, materialise a pin, or start the programme. Raw
SQL / service-role DML is forbidden as a substitute.

Hosted Lee identity and the live Apollo assignment were **not**
queried (hosted contact is not authorised until local compile +
private publication plan exist). Transition design does not depend on
guessing an athlete UUID.

---

## Smallest integrity-preserving follow-on (not authorised here)

1. **Calendar:** replace per-slot date increment with authored-day
   placement:
   `scheduled_date = started_at + (week_number - 1) * 7 + (day_order - 1)`.
   Slots that share `week_number` + `day_order` share a date. This is a
   targeted replace of `ensure_programme_schedule_projection` plus
   tests for same-day AM/PM and a week with more than seven days. It
   is **not** a Plan Package schema change.
2. **Private enrol:** add or extend one SECURITY DEFINER transaction
   that applies the same replace-active / reassigned semantics to a
   published **non-catalogue** version (`coach_private` or equivalent),
   without `approved_for_global`, and without listing the version in
   athlete catalogue RLS. Enrolment source should be an existing
   reserved label (`coach_assigned` or `dual_role_self`), not a new
   programme authority.

After both land, author Bali from the DOCX without weakening it.

---

## Non-goals (still in force)

No B2 pace formulas, Garmin, metrics profiles, commercial HYROX Base,
Apollo prescription edits, public catalogue, Studio authoring
redesign, or hosted mutation.

---

## Acceptance gates (deferred)

Fidelity tests, Studio review, compile hash, and Apollo-hash
regression are specified in the task brief and remain **unrun**
because no programme source was added.
