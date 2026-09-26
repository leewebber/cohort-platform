# Private programme infrastructure — handoff

**Recorded:** 2026-09-26
**Status:** Implemented locally. Awaiting founder approval.
**Branch:** `feat/lee-bali-hybrid-base-v1` (local only)
**Start SHA (preflight):** `70afeb3a5b256be520f04fc324d566f6ab909142`
**Parent:** `origin/main` `ae5028a02229d8c6b8f15d4fedf1f6dcbf350b61`
**Contract:**
[`../architecture/Private_Programme_Infrastructure_v1.md`](../architecture/Private_Programme_Infrastructure_v1.md)
**Phase 1 stop (historical, superseded live flag):**
[`./LEE_BALI_HYBRID_BASE_HANDOFF.md`](./LEE_BALI_HYBRID_BASE_HANDOFF.md)

This is a **narrow enabling slice**. It does **not** author Bali Hybrid
Base, assign Lee, start B2, or contact hosted systems.

```text
LEE_BALI_HYBRID_BASE=INFRASTRUCTURE_IMPLEMENTED_AWAITING_FOUNDER_APPROVAL
LEE_BALI_HYBRID_BASE_PRIVATE=true
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false
BALI_PROGRAMME_CONTENT_AUTHORISED=false
COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
PACE_CALCULATION_B2=NOT_AUTHORISED
RUNNING_DEVICE_INTEGRATION_AUTHORISED=false
HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

The dated Phase 1 handoff originally recorded
`IMPLEMENTED_AWAITING_FOUNDER_APPROVAL`. That value is **superseded**
and remains only as a marked historical error. No programme was
authored. Live status moved
`BLOCKED_PENDING_INFRASTRUCTURE` → `INFRASTRUCTURE_IN_PROGRESS` → this
stop.

---

## Schema / RPC decision

Existing publication fields are sufficient. **No new lifecycle column.**

| Need | Existing authority |
|------|--------------------|
| Immutable snapshot | `lifecycle_status = published` and `archived_at IS NULL` |
| Withheld from catalogue | `library_scope IN (coach_private, organisation)` — catalogue still requires `cohort_global` + `approved_for_global` |
| Not a draft | reject `draft` |

Private assignment must **not** require `cohort_global` or
`approved_for_global`. Catalogue discovery is unchanged. The public
enrol RPC is unchanged.

`materialise_athlete_plan_from_enrolment` now accepts a catalogue-eligible
**or** private-assignable published version so private enrol can
materialise without becoming a public catalogue write.

### Migrations (forward-only, not hosted)

| File | Purpose |
|------|---------|
| `supabase/migrations/20260926120000_authored_occurrence_calendar_dates.sql` | Authored-day date helpers; `ensure_programme_schedule_projection` and calendar week JSON |
| `supabase/migrations/20260926130000_private_exact_version_enrolment.sql` | Private eligibility helpers + `enrol_athlete_in_private_programme_version` |

---

## Occurrence-date rule

```text
calendar_offset_days = ((week_number - 1) * 7) + (day_order - 1)
occurrence_date      = assignment.started_at + calendar_offset_days
```

`week_number` is the package week order. `started_at` is the
assignment’s athlete-local civil date. Integer day addition does not
apply clock-time DST. “Today” remains
`(now AT TIME ZONE assignment.timezone)::date`.

Dates are **not** inferred from global slot index. `day_order` is **not**
clamped to 1–7. Week 8 `day_order` 8 and 9 are the following Saturday
and Sunday on a Saturday start. Duration remains labelled eight weeks.

Duplicate `session_order` on the same authored day fails closed
(`ambiguous_same_day_order`). Distinct occurrence and programmed-session
identities are retained.

Asia/Makassar start Saturday 26 September 2026:

| Authored | Date |
|----------|------|
| W1 D1 | 2026-09-26 |
| W1 D2 AM/PM | 2026-09-27 |
| W1 D3 AM/PM | 2026-09-28 |
| W8 D7 | 2026-11-20 |
| W8 D8 | 2026-11-21 |
| W8 D9 | 2026-11-22 |

DST-observing check: Europe/London civil +1 day across 2026-03-29.

---

## Same-day UX

AM/PM is **ordering and display metadata**, not a new clock-time
scheduler.

- Home lists every non-rest session due today (`todaySessions` /
  `prioritizedTodaySessions`). Completing AM leaves PM visible and
  actionable (`todayOccurrence` is the next remaining today session).
- Calendar month/agenda use `occurrencesOnDate`.
- Daily Journey resolver reports
  `multipleSessionsScheduled` instead of silently picking one.
- Week JSON exposes `occurrences[]` for same-date slots.
- Future Train-today swap fails closed when more than one incomplete
  session is due today (`duplicate_scheduled_dates` remains fail-closed
  on the server for same-day programmes).
- Read resolution does not mutate occurrences, sessions, or outcomes.

---

## Private version eligibility

`cohort_programme_version_is_private_assignable`:

- published, not archived
- `library_scope` in `coach_private` / `organisation`
- **not** catalogue-eligible

`cohort_athlete_may_enrol_private_programme_version`:

- `auth.uid()` present and athlete
- caller owns `owner_id` **or** has an active coach–athlete link to
  the owning coach

Catalogue versions return `use_catalogue_enrolment`. Drafts and
unapproved/unpublished versions return `version_not_private_eligible`.

---

## Transaction, locking, idempotency

`enrol_athlete_in_private_programme_version(version_id, timezone, replace_active)`:

1. Authenticate and authorise.
2. `pg_advisory_xact_lock` on the athlete + `SELECT … FOR UPDATE` the
   active assignment.
3. Same version already active → `already_enrolled` (idempotent retry).
4. Different active + `replace_active=false` → `active_enrolment_exists`.
5. `replace_active=true` marks the locked row `reassigned`, inserts the
   new active pin, sets `superseded_by_assignment_id`, materialises, and
   ensures projection. Prior pin, occurrences, sessions, and outcomes
   are not rewritten.
6. Any materialise/projection failure raises and rolls back the
   transaction (no two-active intermediate). Unique index
   `programme_assignments_one_active_per_athlete` remains.

---

## Grants

`REVOKE ALL … FROM PUBLIC, anon` then
`GRANT EXECUTE … TO authenticated, service_role` on the helpers and
enrol RPC. Anon execute is denied (`42501`). No service-role manual DML
workflow. No Lee UUIDs. No generic unrestricted client assigner.

---

## What did not ship

Bali YAML, protocols, Studio catalogue entry, Lee assignment, B2,
commercial HYROX Base, hosted apply, public visibility change.

## Next approval required

1. Accept this infrastructure.
2. Separately authorise Bali authoring from the DOCX.
3. Separately authorise hosted private publication and any replace of
   Lee’s current assignment.

## Verification (local)

| Check | Result |
|-------|--------|
| Changed-file `flutter analyze` | No issues found |
| `git diff --check` | Clean |
| Local DB reset + full gate (incl. Gate BB ×2 and BB concurrency) | `ALL LOCAL DB GATE CHECKS PASSED` |
| Phase 2 consolidation safety gate | `PHASE2_CONSOLIDATION_SAFETY_GATE=PASS` (6/6 groups) |
| Full `flutter test` (uncontended, final HEAD) | `+3296` passed, `~6` skipped, `0` failed |

An earlier full-suite attempt timed out one unrelated staging loopback
HTTP proof (`s17_jd_nontest_runtime_proof_test`). Isolated retry passed;
the uncontended rerun is the recorded suite.

Apollo Plan Package hash remains
`810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83`.

### Migration SHA-256

| File | SHA-256 |
|------|---------|
| `20260926120000_authored_occurrence_calendar_dates.sql` | `dc7da2c16af2798532f6420927c40b7101b45715e984a2e69525ae2163098ecd` |
| `20260926130000_private_exact_version_enrolment.sql` | `664b84f13ef1a0c84904c1c72f590470db4d7f92a0916807bc4f153c5fb5ff3a` |

`.env` SHA-256
`869a01b1e4ee6b0559face678843f0df9ce57cbaf30febadb90f796c2a161816`.

`HOSTED_SYSTEMS_CONTACTED=false`. `HOSTED_MUTATIONS=0`.

## Non-actions

No push. No hosted contact. No B2. No commercial programme-content
flag change.
