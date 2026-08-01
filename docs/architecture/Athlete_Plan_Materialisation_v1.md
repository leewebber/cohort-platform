# Athlete Plan Materialisation v1 — Sprint 1.4A

**Status:** Binding for Sprint 1.4A foundation  
**Depends on:** Sprint 1.3 catalogue enrolment (`Athlete_Catalogue_Enrolment_v1.md`)

---

## Why `programme_assignments` is reused

Sprint 1.3 already made `programme_assignments` the durable exact-version
enrolment record with cursor fields. Sprint 1.4A extends that same row rather
than creating a parallel `athlete_plans` table.

One durable row still has an **explicit lifecycle**:

1. **Enrolled** — `materialised_at IS NULL` (not executable)
2. **Materialised** — `materialised_at IS NOT NULL` (authoritative executable plan)
3. **Prepared** — Sprint 1.4B (first prepared session; not this sprint)
4. **Completed** — later completion attribution

Enrolment alone must not appear executable in product UI.

---

## Explicit Start Programme

Materialisation occurs only when the athlete selects **Start Programme** on an
enrolled programme.

It must not occur during enrolment, catalogue browse, programme open/load,
Home/today, or the legacy Plan Library path.

RPC: `materialise_athlete_plan_from_enrolment(p_programme_assignment_id, p_timezone)`

---

## Enrolment-time `started_at` is inert

Catalogue enrolment still writes `started_at = CURRENT_DATE`, but that value is
**not** the execution schedule anchor before materialisation.

- `created_at` already records enrolment creation provenance — no duplicate
  `enrolled_at` column.
- On successful materialisation, `started_at` is **reset** to athlete-local
  **today** in the validated programme timezone.
- Time elapsed since enrolment must not advance the programme.
- Cursor is reinitialised to the first authored executable slot of the exact
  enrolled version.

---

## Start-today semantics

v1 / Self-Test 1 supports only **Start today**.

“Today” = `(CURRENT_TIMESTAMP AT TIME ZONE <validated_iana_timezone>)::date`.

Timezone resolution order:

1. Optional RPC `p_timezone` when valid
2. Else assignment `timezone`
3. Else fail closed (`timezone_unavailable`)

No start-date picker or future scheduling system in 1.4A.

---

## Exact-version and package-hash provenance

Materialisation:

- Uses only the assignment’s existing `programme_version_id`
- Never resolves “latest”
- Snapshots `materialised_package_content_hash` (and optional schema version)
  from the server-authoritative `programme_versions` row
- Does not copy immutable package content into athlete-owned tables

---

## Initial cursor authority

Server resolves the first **executable** authored slot:

- non-rest day
- non-null `protocol_id`
- published session revision present

Client cannot supply week/day/slot.

---

## Idempotency and concurrency

- Same already-materialised assignment → `already_materialised` with the same
  identity
- Transaction advisory lock per athlete + row `FOR UPDATE`
- Partial unique index:
  `programme_assignments_one_active_materialised_per_athlete`
  (`athlete_id` where `status = 'active' AND materialised_at IS NOT NULL`)

---

## Active materialised uniqueness

The database authoritatively enforces at most one **active materialised**
programme assignment per athlete.

---

## Legacy Plan Library conflict (client-only)

Legacy `PlanAssignment` / `AthleteProfileSession.hasActivePlan` is local memory
and **cannot** be inspected by the database RPC.

Flutter preflight blocks Start Programme when `hasActivePlan` is true and
explains that switching is not available yet.

This is compatibility protection only — not a cross-device database invariant.

---

## Preparation (Sprint 1.4B)

1.4A materialises the durable plan only. Sprint 1.4B connects that row to
deterministic preparation — see `Athlete_First_Prepared_Session_v1.md`.

```text
materialised assignment
→ authored slot resolution
→ programme-shaped ProgrammedSessionKey
→ deterministic bank compilation (SessionExecutionLoader)
→ PreparedExecutionPackage
→ Home/today
```

Coach Brain and generative `ProgrammedSessionResolver` remain excluded from the
authored Plan Package path.

---

## Security

- `SECURITY DEFINER` RPC with `search_path = public, pg_temp`
- Identity from `auth.uid()` only
- `EXECUTE` for `authenticated`; revoked from `anon` / `PUBLIC`
- Trigger blocks direct authenticated updates to materialisation-controlled
  columns. Bypass requires transaction-local GUC
  `cohort.allow_materialisation_write=on` **and** `current_user` in
  (`postgres`, `supabase_admin`) — satisfied by the `SECURITY DEFINER` RPC,
  not by an athlete calling `set_config`
- Corrective migration `20260801150000_harden_materialisation_write_guard.sql`
  closes the authenticated-GUC bypass found during staging verification
- No import/publish/approve grant expansion
- No client service-role use

---

## Cohort Staging verification

Synthetic Sprint 1.3 fixtures remain the staging substrate. After Sprint 1.4A
hosted verification, Athlete A’s retained enrolment
(`dcb723e3-f0b1-4606-85d7-b446813b38d2` on `PROG-S13-ELIG` /
`e9bd7e19-6eb9-4f7e-abf6-d08ac4368748`) is **materialised** with
`materialisation_source = athlete_start_programme`.

Presence check (fail-closed staging guard):

```bash
CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh --dry-run
CONFIRM_COHORT_STAGING=1 ./tool/staging/validate_s13_catalogue_fixtures.sh
```

Flutter reconciliation against staging (temporary staging `.env` + secrets
overwrite; restore afterward; never commit credentials):

```bash
CONFIRM_COHORT_STAGING=1 ./tool/staging/run_s14a_flutter_staging_verify.sh
```

Fresh Start Programme UI submit is not re-run against Athlete A after hosted
materialisation. Hosted DB probes own fresh-success evidence; Flutter verifies
already-materialised reconciliation + legacy preflight.
