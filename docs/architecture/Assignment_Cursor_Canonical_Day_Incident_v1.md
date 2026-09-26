# Assignment cursor canonical day — incident contract

**Status:** Active assignment integrity incident after private Bali
activation.
**Base:** `origin/main` `0ce94f4df88f46b49536963c898817f848c82c53`
**Branch:** `fix/assignment-cursor-canonical-day-v1`

```text
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
BALI_ASSIGNMENT_CURSOR_INCIDENT=OPEN
NEXT_IMPLEMENTATION_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
```

Home reported `assignment cursor references missing day day_1` after a
successful authenticated Bali activation. This is not an enrolment
failure and must not be repaired by re-enrolment, assignment
replacement, or a guessed cursor UPDATE.

---

## Read-only incident evidence (Field Manual)

Exactly one active assignment. It is Bali:

| Field | Value |
|-------|--------|
| Assignment id | `95ee6900-c3e2-4684-b704-dd261308458e` |
| Version | `b1a1b001-0000-4000-8000-ba11b0010001` |
| Hash | `f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b` |
| Start | `2026-09-26` |
| Timezone | `Asia/Makassar` |
| Cursor | week `1` / `day_1` / slot `1` |
| Occurrences | 71 (`2026-09-26` … `2026-11-22`) |
| Enrolment source | `dual_role_self` |

Pinned week 1 days include `day_1` titled Saturday with Strength A.
Sunday AM/PM share `2026-09-27`. Monday AM/PM share `2026-09-28`.

Apollo is `reassigned`, superseded by the Bali assignment, 84
occurrences / 11 records / 11 outcomes, pin unchanged. Bali is not
catalogue-eligible.

The cursor already names the canonical first authored day key.

---

## Root cause

Cursor namespace is `programme_version_days.day_key` (ordinal
`day_N` per week), not a day UUID and not a synthetic constant.

Private publication writes lineage `created_by` from the operational
importer (`private-exact-publisher`). Home loads the pinned graph
through PostgREST:

- versions / weeks: `cohort_programme_version_is_dev_coach_readable`
  (owner_id only) — visible
- days: `cohort_programme_week_is_dev_coach_readable` also requires
  `programme_lineages.created_by = auth.uid()` — **hidden**

Weeks therefore load with zero days. The resolver looks up
`assignment.current_day_key` (`day_1`) in an empty week and fails
closed. Catalogue programmes are unaffected because they use the
catalogue SELECT policies.

Identity involved: authored `day_key` on the pinned version graph.
The cursor must not be rewritten.

---

## Required fix

Assigned athletes must SELECT the pinned programme graph
(versions, phases, weeks, days, slots) for versions they are assigned
to. That is the existing Home / Daily Journey / Calendar authority.

Do not:

- invent a second cursor namespace
- hard-code `day_1` or Bali identities
- UPDATE the hosted cursor
- re-enrol or recreate the assignment
- complete or skip sessions

Affected hosted cursor-repair row count: **0**. The assignment is
already correct. Deploy the read authority; do not mutate assignment
rows.
