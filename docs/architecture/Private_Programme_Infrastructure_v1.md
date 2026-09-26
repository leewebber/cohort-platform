# Private programme infrastructure — implementation contract

**Status:** Authorised enabling slice. Not programme authoring.
**Base:** `feat/lee-bali-hybrid-base-v1` `70afeb3a5b256be520f04fc324d566f6ab909142`
**Parent stop (superseded status only):**
[`../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md`](../checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md)

```text
LEE_BALI_HYBRID_BASE=INFRASTRUCTURE_IN_PROGRESS
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

The dated Phase 1 handoff previously set
`LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_APPROVAL`. That value is
**superseded**. No programme was authored. The correct historical reading of
that stop is `BLOCKED_PENDING_INFRASTRUCTURE`.

This slice does **not** author Bali Hybrid Base or commercial HYROX Base.

---

## Gap 1 — authored calendar offset

Authoritative rule (`week_number` is the package week order):

```text
calendar_offset_days = ((week_number - 1) * 7) + (day_order - 1)
occurrence_date      = assignment.started_at + calendar_offset_days
```

`started_at` is the assignment’s athlete-local civil date. Adding integer
days does not apply clock-time DST. “Today” continues to be
`(now AT TIME ZONE assignment.timezone)::date`.

Slots that share `week_number` and `day_order` share a date. Distinct
`session_order` (and optional `time_of_day` display) keep identities.
Duplicate `session_order` on the same authored day fails closed.

`day_order` is not clamped to 1–7. Week 8 `day_order` 8 and 9 are the
following Saturday and Sunday on a Saturday start. Duration remains
eight weeks.

Do not derive dates from global slot index.

---

## Gap 2 — private exact-version enrol

New SECURITY DEFINER transaction
`enrol_athlete_in_private_programme_version(version_id, timezone, replace_active)`.

Existing fields are sufficient. No new lifecycle column:

| Need | Existing field |
|------|----------------|
| Immutable snapshot | `lifecycle_status = published` and `archived_at IS NULL` |
| Withheld from catalogue | `library_scope IN (coach_private, organisation)` — catalogue still requires `cohort_global` + `approved_for_global` |
| Not a draft | reject `draft` |

Eligibility must **not** require `cohort_global` or `approved_for_global`.
The public enrol RPC is unchanged.

Athlete authority: caller is `auth.uid()`, must be an athlete, and must
own the version (`owner_id`) **or** have an active coach–athlete
relationship with the owning coach. Coaches cannot nominate another
athlete. Unrelated athletes are denied.

`enrolment_source` is `dual_role_self` when the caller owns the version,
otherwise `coach_assigned`.

Replace-active matches catalogue semantics: lock the active row, mark
`reassigned`, insert the new active pin, set `superseded_by_assignment_id`,
then materialise the new assignment and ensure its schedule projection.
Prior rows, occurrences, sessions, and outcomes are not rewritten.

Idempotent retry: already active on the same version → `already_enrolled`.
`replace_active=false` + different active → `active_enrolment_exists`.

---

## Non-goals

No Bali YAML, no Studio catalogue entry, no hosted apply, no B2, no
public catalogue visibility change, no Lee UUIDs.
