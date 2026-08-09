# Phase 1.2–1.7 — Cohort Staging Uplift Plan (v1)

**Status:** ACCEPTED by Lee Webber — schema uplift not required; next gate is
isolated Athlete E manual verification (separately authorised)  
**Recorded:** 2026-08-09  
**Prerequisite commits:**
- Reconciliation docs: `e348f9cf3d99a5c807c367670c0a336e924cef88`
- Rollout plan: `e8e45796ff658b5af8b71aee1f7a92996919d1d7`
- Part 2 seed (local only): `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc`

```text
STAGING_UPLIFT_PLAN_ACCEPTED=true
STAGING_READ_ONLY_AUDIT_AUTHORISED=true
STAGING_PROJECT_IDENTITY_PROVEN=true
STAGING_READ_ONLY_INSPECTION_COMPLETED=true
STAGING_MIGRATIONS_ABSENT=0
STAGING_MIGRATIONS_EXACTLY_REPRESENTED=9
STAGING_MIGRATIONS_PARTIALLY_REPRESENTED=0
STAGING_MIGRATIONS_CONFLICTING=0
STAGING_MIGRATIONS_INDETERMINATE=0
STAGING_DEPLOYMENT_AUTHORISED=false
STAGING_MUTATION_PERFORMED=false
MIGRATIONS_APPLIED=0
PHASE_3_1F_SEED_INCLUDED=false
PHASE_3_1F_SEED_APPLIED=false
FIELD_MANUAL_UPLIFT_AUTHORISED=false
FIELD_MANUAL_MUTATION_PERFORMED=false
MIGRATION_HISTORY_REPAIRED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

This document does **not** authorise applying migrations to Staging or Field Manual,
applying the Phase 3.1F catalogue seed, application deployment, or first-consumer work.
Manual T1–T12 execution requires a separate founder authorisation.

---

## 1. Why direct production A1 was not authorised

Lee accepted the Field Manual reconciliation conclusion: the nine Phase 1.2–1.7
migrations are ledger-absent **and** effect-`ABSENT` on **Cohort Field Manual**,
so ledger repair would be false history and A1 (apply all nine) remains the
long-term production path.

Direct Field Manual A1 is **not** authorised yet because:

- Field Manual is treated as production;
- the nine migrations implement substantial athlete programme workflows;
- historical controls required staging deployment + manual athlete-flow verification
  before production rollout;
- live Staging migration state had not been reconfirmed in this Phase 3.1F line;
- rollback is by verified backup/PITR readiness, not destructive down migrations.

Therefore this sprint prepared a **Staging** read-only audit and uplift/verification
plan before any production apply.

---

## 2. Staging project identity evidence

| Check | Evidence |
|-------|----------|
| Intended name | **Cohort Staging** |
| Project ref (full) | `tsbadngzgvsyfqjupkng` |
| Region | `eu-west-2` (pooler host `aws-1-eu-west-2.pooler.supabase.com`) |
| Proven from CLI link | `supabase/.temp/linked-project.json` name=`Cohort Staging`, ref=`tsbadngzgvsyfqjupkng` |
| Proven from repo guards | `tool/staging/lib/s17_staging_guard.py` (`STAGING_HOST_MARKER`, `STAGING_REF_PREFIX=tsbadngz`); staging runners assert full ref |
| Matches prior accepted docs | `Sprint_1_4B_Staging_Self_Test_1.md` — Cohort Staging (`tsbadngz…`, eu-west-2) |
| Distinct from production | Production ref prefix `otnhhdxs…` / **Cohort Field Manual** (`eu-west-1`) — confirmed different |

**Field Manual identity before relink (this task):** Cohort Field Manual /
`otnhhdxstdnwccehacku` / `eu-west-1` (prior linked target; credentials not recorded).

No new credentials were created. Relink to Staging was used only for read-only
inspection and dry-run.

---

## 3. Staging ledger state

| Fact | Value |
|------|-------|
| Ledger table | `supabase_migrations.schema_migrations` |
| Ledger count | **43** |
| Ledger min / max | `20260713140000` … **`20260803180000`** |
| Nine Phase 1.2–1.7 versions in ledger | **All nine present** |
| Later migrations after `20260803180000` | **None** |
| Phase 3.1F Part 2 seed (`20260809160000`) in ledger | **Absent** |

Ledger window (≥ `20260730150000`) includes templates seed plus the nine in order
through undo/horizon.

---

## 4. Baseline prerequisites

Required pre-existing tables (additive chain assumptions):

| Object | Present on Staging |
|--------|--------------------|
| `public.programme_versions` | Yes |
| `public.programme_assignments` | Yes |
| `public.programme_version_session_slots` | Yes |
| `public.training_session_records` | Yes |
| `public.exercises_v2` | Yes |
| `public.programme_lineages` | Yes |

Baseline prerequisites are **present**. No evidence that core tables need
reconstruction.

### Staging data that must be preserved (aggregates only; no PII)

| Aggregate | Count |
|-----------|------:|
| `programme_assignments` | 6 |
| `programme_versions` | 6 |
| `programme_lineages` | 6 |
| `training_session_records` | 3 |
| `programme_schedule_projections` | 3 |
| `programme_schedule_occurrences` | 6 |
| `programme_schedule_operations` | 14 |

Existing Sprint/Athlete fixtures (including historical Athlete C / Athlete D
artefacts) must **not** be modified by future verification. Use a **new isolated
test athlete** only.

### Catalogue (relevant, not blocking the nine)

| Fact | Staging |
|------|---------|
| Published `EX-*` count | **55** (`EX-073`…`EX-127` band) |
| `EX-128`…`EX-132` | **0** (Phase 3.1F seed not applied) |

Staging catalogue is **not** identical to Field Manual’s contiguous 127-row
production catalogue. That difference is expected for this staging fixture set
and does **not** change the nine-migration classification. Phase 3.1F seed
remains separately authorised and must not ride along.

---

## 5. Nine-migration hosted-effect classifications (Staging)

Material probes (metadata / function presence / constraint checks; no athlete PII):

| # | Migration | Ledger | Hosted effect | Classification |
|---|-----------|--------|---------------|----------------|
| 1 | `20260731120000_authored_plan_package_import.sql` | Present | Package cols; child tables; `import_authored_plan_package` / publish helpers | `EXACTLY_REPRESENTED` |
| 2 | `20260801120000_athlete_catalogue_enrolment.sql` | Present | `enrolment_source`; `enrol_athlete_in_catalogue_programme_version` | `EXACTLY_REPRESENTED` |
| 3 | `20260801140000_athlete_plan_materialisation.sql` | Present | materialisation cols; `materialise_athlete_plan_from_enrolment`; protect trigger | `EXACTLY_REPRESENTED` |
| 4 | `20260801150000_harden_materialisation_write_guard.sql` | Present | `programme_assignments_protect_materialisation` + protect function present | `EXACTLY_REPRESENTED` |
| 5 | `20260801160000_complete_programme_session_and_advance.sql` | Present | `programme_slot_outcomes` completion identity cols; `complete_programme_session_and_advance` | `EXACTLY_REPRESENTED` |
| 6 | `20260803120000_add_programme_schedule_projection.sql` | Present | schedule tables; `ensure_programme_schedule_projection`; `schedule_revision` | `EXACTLY_REPRESENTED` |
| 7 | `20260803140000_apply_programme_schedule_move_swap.sql` | Present | `apply_programme_schedule_operation`; op types include move/swap; RPC write guard | `EXACTLY_REPRESENTED` |
| 8 | `20260803160000_apply_programme_schedule_push_skip.sql` | Present | apply RPC + op-type check includes push/skip | `EXACTLY_REPRESENTED` |
| 9 | `20260803180000_apply_programme_schedule_undo_horizon.sql` | Present | `scheduling_horizon_end`; undo columns; apply RPC mentions undo/horizon | `EXACTLY_REPRESENTED` |

**Counts:** ABSENT=0; EXACTLY_REPRESENTED=9; PARTIAL=0; CONFLICTING=0; INDETERMINATE=0.

No partial or conflicting effects were found. Therefore the STOP condition for
partial/conflicting schema does **not** fire for migration effects.

---

## 6. Exact proposed staging deployment set (dry-run)

Command (non-mutating): `supabase db push --linked --dry-run` while linked to
Cohort Staging.

**Would push:**

1. `20260809160000_founder_exercise_library_phase_3_1f_part2.sql`

**Would not push:** any of the nine Phase 1.2–1.7 migrations (already on ledger).

### Consequences

| Question | Answer |
|----------|--------|
| Is the dry-run set exactly the nine? | **No** — the nine are already applied |
| Is the Phase 3.1F seed excluded from “future nine-migration uplift”? | **Yes by intent** — seed must stay separately authorised |
| Can standard `db push` isolate the nine from the seed? | **N/A for the nine** (nothing to apply). For any seed apply: dry-run shows **only** the seed — but seed apply is **not** authorised here |
| Deployment-design blocker for “apply the nine on Staging”? | **Nine-migration apply is unnecessary** — Staging already represents them |
| Deployment-design blocker if someone runs unconstrained `db push`? | **Yes** — it would apply the Phase 3.1F seed unless separately authorised |

**Staging “uplift” of the nine is therefore reclassified:** schema uplift appears
**already complete** on Cohort Staging. The remaining Staging work before
production Field Manual A1 is **isolated manual athlete-flow verification** (and
backup/PITR readiness), not re-application of the nine SQL files.

Do **not** rename migrations, repair history, or execute SQL out of band to force
a nine-file dry-run.

---

## 7. Dependency order (verification / future production)

Verification and any future Field Manual apply must respect:

1. Authored Plan Package import  
2. Athlete catalogue enrolment  
3. Athlete plan materialisation  
4. Materialisation write-guard  
5. Session completion + automatic advancement  
6. Schedule projection  
7. Move / Swap  
8. Push / Skip  
9. Undo + horizon rejection  

Phase 3.1F catalogue seed remains **after** and **separate** from this chain.

---

## 8. Manual staging test plan (not executed in this task)

**Athlete rule:** create a **new isolated test athlete** (e.g. “Staging Uplift
Athlete E”). Do **not** use or modify Athlete C, Athlete D, or other historical
fixtures. Preserve existing aggregate programme/session/schedule rows.

**App/runtime:** use existing staging harness patterns
(`CONFIRM_COHORT_STAGING=1`, temporary staging env) where applicable; no
persistent app deploy in this plan’s authorisation.

### Test matrix

#### T1 — Founder Plan Package import

| Field | Content |
|-------|---------|
| Setup | Isolated founder/service path; new unpublished package payload with unique content hash; Staging identity confirmed |
| User action | Import authored plan package via authorised import path |
| Expected UI | Success acknowledgement; package version visible in catalogue/admin path used by staging harness |
| Expected DB | New `programme_versions` row with package provenance cols; package child rows; no mutation of unrelated versions |
| Prohibited | Touching existing 6 versions/assignments; catalogue EX seed; Field Manual |
| Cleanup/retention | Retain imported version labelled for uplift test; do not delete historical fixtures |
| Evidence | Version id, content hash, import timestamp, before/after version_count |

#### T2 — Catalogue visibility and enrolment

| Field | Content |
|-------|---------|
| Setup | Published catalogue version from T1 (or dedicated published test version); new athlete E |
| User action | Athlete browses catalogue and enrols |
| Expected UI | Version visible; enrolment succeeds once |
| Expected DB | `programme_assignments` row with `enrolment_source` set; assignment_count +1 for athlete E only |
| Prohibited | Enrolment of/against Athlete C/D; commercial payment paths |
| Cleanup/retention | Keep athlete E assignment for later tests |
| Evidence | Assignment id, enrolment_source, athlete id (internal uuid only) |

#### T3 — Plan materialisation

| Field | Content |
|-------|---------|
| Setup | Athlete E enrolled, not yet materialised |
| User action | Trigger materialisation |
| Expected UI | Plan materialised; cursor/authority surfaces ready |
| Expected DB | `materialised_at` / `materialisation_source` (and related cols) set; slot outcomes as designed |
| Prohibited | Rematerialising other athletes’ plans |
| Cleanup/retention | Retain |
| Evidence | materialised_at, source, package hash match |

#### T4 — Materialisation write-guard

| Field | Content |
|-------|---------|
| Setup | Materialised athlete E assignment |
| User action | Attempt direct/client write to protected materialisation fields outside RPC |
| Expected UI / client | Failure / rejected |
| Expected DB | No change to protected columns |
| Prohibited | Disabling triggers; bypassing with ad-hoc SQL in verification |
| Cleanup/retention | N/A |
| Evidence | Error code/message; before/after column snapshot |

#### T5 — Session completion and automatic advancement

| Field | Content |
|-------|---------|
| Setup | Prepared session for athlete E first slot |
| User action | Complete session through authorised complete/advance path |
| Expected UI | Completion confirmed; next session advances |
| Expected DB | `programme_slot_outcomes` row with logical/idempotency/programmed keys; cursor advanced |
| Prohibited | Rewriting other athletes’ TSR/outcomes |
| Cleanup/retention | Retain completion for schedule tests |
| Evidence | outcome keys, cursor position, idempotent replay result |

#### T6 — Schedule projection

| Field | Content |
|-------|---------|
| Setup | Materialised + at least one completion context for athlete E |
| User action | Open schedule / ensure projection |
| Expected UI | Projection shows programmed occurrences |
| Expected DB | `programme_schedule_projections` / occurrences for athlete E; `schedule_revision` baseline |
| Prohibited | Mutating other athletes’ projections |
| Cleanup/retention | Retain |
| Evidence | projection id, occurrence count, revision |

#### T7 — Move and swap

| Field | Content |
|-------|---------|
| Setup | Projection with ≥2 movable occurrences inside horizon |
| User action | Exact-preview Move; exact-preview Swap |
| Expected UI | Preview then apply success; calendar updates |
| Expected DB | `programme_schedule_operations` rows type `move`/`swap`; revision increments; occurrences updated |
| Prohibited | Applying without matching preview fingerprint |
| Cleanup/retention | Retain ops for undo tests |
| Evidence | op ids, fingerprints, before/after occurrence dates |

#### T8 — Push and skip

| Field | Content |
|-------|---------|
| Setup | Projection with pushable/skippable occurrence |
| User action | Push; Skip (exact preview) |
| Expected UI | Success; schedule reflects push/skip |
| Expected DB | ops type `push`/`skip`; revision increments |
| Prohibited | Silent apply on fingerprint mismatch |
| Cleanup/retention | Retain |
| Evidence | op types, revision chain |

#### T9 — Undo horizon and out-of-horizon rejection

| Field | Content |
|-------|---------|
| Setup | Recent undoable op within horizon; separately an op or target outside `scheduling_horizon_end` |
| User action | Undo within horizon; attempt undo/apply outside horizon |
| Expected UI | In-horizon undo succeeds; out-of-horizon rejected |
| Expected DB | undo consumed fields set on success; no occurrence change on rejection |
| Prohibited | Extending horizon via ad-hoc SQL during test |
| Cleanup/retention | Retain |
| Evidence | undo_expires_at, horizon_end, rejection error |

#### T10 — Restore/reopen after app restart

| Field | Content |
|-------|---------|
| Setup | Athlete E mid-journey after T5–T9 |
| User action | Kill/reopen app (or harness); sign in as athlete E |
| Expected UI | Same cursor, schedule revision, and pending session as before restart |
| Expected DB | No spurious new ops/completions from reopen alone |
| Prohibited | Local cache inventing schedule authority |
| Cleanup/retention | N/A |
| Evidence | UI screenshots/logs + revision/cursor equality |

#### T11 — Failure behaviour (duplicate / malformed / unauthorised)

| Field | Content |
|-------|---------|
| Setup | Known-good athlete E paths |
| User action | Duplicate idempotency completion; malformed payload; unauthorised athlete/assignment |
| Expected UI | Clear failure; no partial success |
| Expected DB | No duplicate outcomes; no revision bump on hard fail |
| Prohibited | Swallowing errors as success |
| Cleanup/retention | N/A |
| Evidence | error codes; row counts unchanged |

#### T12 — Preservation of existing athlete and programme data

| Field | Content |
|-------|---------|
| Setup | Record pre-test aggregates (assignments/versions/tsr/schedule counts) and known fixture identifiers (non-PII) |
| User action | After T1–T11, re-query aggregates + fixture presence |
| Expected UI | N/A |
| Expected DB | Historical fixture rows unchanged; only athlete E / new test artefacts added |
| Prohibited | Deletes/updates to Athlete C/D or shared bank protocols beyond additive test seeds |
| Cleanup/retention | Document whether athlete E retained for audit or soft-deactivated later under separate auth |
| Evidence | Before/after aggregate table; fixture id checklist |

**Tests are not executed in this task.**

---

## 9. Backup and rollback requirements (before any future Staging mutation)

Required evidence **before** any authorised Staging deploy (seed or otherwise):

1. **Staging identity confirmation** — linked name Cohort Staging, ref
   `tsbadngzgvsyfqjupkng`, region eu-west-2; not Field Manual.
2. **Backup / PITR readiness** — dashboard/CLI proof that point-in-time recovery
   (or fresh logical backup) covers the pre-change timestamp; record retention
   window and restore owner.
3. **Exact dry-run** — captured stdout of `supabase db push --linked --dry-run`
   matching the **authorised** migration set only (for a nine-migration apply:
   must be empty or exactly those nine; today it is **only** the Part 2 seed —
   which must **not** be applied under a “nine uplift” authorisation).
4. **Clean worktree + accepted commits** — no unrelated dirty files; plan/report
   commits accepted by founder.
5. **Test-athlete isolation** — athlete E (or successor) created; Athlete C/D
   untouched.
6. **Recovery process** — if apply fails or is ambiguous: stop; do not “fix
   forward” without auth; restore from backup/PITR to pre-change point; re-verify
   ledger max and effect probes.
7. **No destructive down migrations** — rollback is restore, not `DOWN` SQL.
8. **Post-deploy checks** — ledger versions; effect probes for authorised
   migrations only; catalogue EX-128…132 still absent unless seed authorised;
   aggregate fixture preservation.

**PITR/backup readiness must be re-confirmed at deploy time**; this audit did not
mutate Staging and did not execute a restore drill.

---

## 10. Production promotion gate (Field Manual A1)

Promote to Field Manual **only after**:

| Gate | Requirement |
|------|-------------|
| Staging schema | Nine migrations remain `EXACTLY_REPRESENTED` (or freshly applied + verified) |
| Manual tests | T1–T12 pass on isolated athlete E with evidence pack |
| Dry-run on Field Manual | Pending set is exactly the nine (Part 2 seed sequencing decided separately) |
| Backup/PITR | Field Manual restore readiness recorded |
| Explicit founder auth | “Field Manual Phase 1.2–1.7 nine-migration apply” |
| Exclusions | No Phase 3.1F seed; no first-consumer wiring; no app deploy unless listed |

Production A1 remains **separately authorised** and is **not** granted by this plan.

---

## 11. Continued separation of Phase 3.1F catalogue seed

| Item | Status |
|------|--------|
| Seed file | `20260809160000_founder_exercise_library_phase_3_1f_part2.sql` |
| Staging ledger | Absent |
| Staging EX-128…132 | Absent |
| Field Manual EX-128…132 | Absent (prior audit) |
| Included in nine-migration uplift? | **No** |
| Standard Staging `db push` today | Would apply **only** the seed — still **not authorised** |

First consumer remains recommended `founder_programme_yaml_import` and is **not
implemented**.

---

## 12. Smallest next founder authorisation

**Preferred next auth (narrow):**

> Authorise **isolated Cohort Staging manual athlete-flow verification** (T1–T12)
> against the already-present Phase 1.2–1.7 schema, using a **new test athlete
> only**, with backup/PITR readiness recorded first. **Do not** run
> `supabase db push` (it would apply the Phase 3.1F seed). **Do not** apply
> Field Manual A1. **Do not** apply the Phase 3.1F seed.

**After T1–T12 pass:** separately authorise Field Manual A1 (nine migrations only),
with dry-run proof that Part 2 seed is either still deferred or handled in its
own Stage 1 auth.

---

## 13. Confirmations

- No Staging mutation performed in this audit.
- No Field Manual mutation performed.
- Migration history not repaired.
- No application code deployed.
- No first consumer implemented.
- No secrets recorded in this document.
- Phase 3.1 incomplete; Phase 3.2 not started.
