# Phase 3.1F — Pending Migration Reconciliation (Read-Only)

**Status:** COMPLETE for Option C audit — **accepted and committed**  
**Recorded:** 2026-08-09  
**Committed:** `e348f9cf3d99a5c807c367670c0a336e924cef88`  
**Temporary founder decision:** Option **C** — defer Stage 1 catalogue seed until the nine
earlier pending migrations are reconciled  
**Hosted project:** Cohort Field Manual (`eu-west-1`)  
**Rollout-plan commit:** `e8e45796ff658b5af8b71aee1f7a92996919d1d7`  
**Part 2 commit:** `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc`

```text
PENDING_MIGRATION_AUDIT_AUTHORISED=true
TEMPORARY_DECISION=defer_stage_1
EXACT_PENDING_MIGRATION_COUNT=9
HOSTED_READ_ONLY_INSPECTION_COMPLETED=true
MIGRATIONS_ABSENT=9
MIGRATIONS_EXACTLY_REPRESENTED=0
MIGRATIONS_PARTIALLY_REPRESENTED=0
MIGRATIONS_CONFLICTING=0
MIGRATIONS_INDETERMINATE=0
MIGRATION_HISTORY_REPAIRED=false
MIGRATIONS_APPLIED=0
HOSTED_MUTATION_PERFORMED=false
PHASE_3_1F_SEED_APPLIED=false
CANONICAL_ROWS_INSERTED=0
AUTHORITATIVE_CANONICAL_CATALOGUE_COUNT=127
AUTHORITATIVE_CANONICAL_ID_RANGE=EX-001..EX-127
RECOMMENDED_RECONCILIATION_OUTCOME=A1
RECONCILIATION_REPORT_COMMITTED=true
RECONCILIATION_REPORT_COMMIT=e348f9cf3d99a5c807c367670c0a336e924cef88
```

---

## 1. Founder decision and why “pending” ≠ “missing”

Lee selected temporary **Option C**: defer the Phase 3.1F five-row catalogue deploy
until the nine earlier migrations reported by `supabase db push --dry-run` are
reconciled.

A missing ledger row proves only that
`supabase_migrations.schema_migrations` does not record the file. It does **not**
prove the intended database effects are absent. This audit inspected both the
ledger and the named hosted objects.

**Result on Cohort Field Manual:** the nine migrations are absent from the ledger
**and** their material intended effects are absent from the database. That is
stronger than “ledger gap only,” but applying them remains a major Phase 1.2–1.7
programme-runtime uplift and still requires separate founder authorisation.

---

## 2. Exact nine pending migrations (before Part 2 seed)

From dry-run + repository order (filenames exact):

1. `20260731120000_authored_plan_package_import.sql`
2. `20260801120000_athlete_catalogue_enrolment.sql`
3. `20260801140000_athlete_plan_materialisation.sql`
4. `20260801150000_harden_materialisation_write_guard.sql`
5. `20260801160000_complete_programme_session_and_advance.sql`
6. `20260803120000_add_programme_schedule_projection.sql`
7. `20260803140000_apply_programme_schedule_move_swap.sql`
8. `20260803160000_apply_programme_schedule_push_skip.sql`
9. `20260803180000_apply_programme_schedule_undo_horizon.sql`

Then (authorised seed, also not on ledger):  
`20260809160000_founder_exercise_library_phase_3_1f_part2.sql`

Dry-run and ledger gap agree on these nine.

---

## 3. Purpose of each migration (plain English)

| # | Migration | Purpose |
|---|-----------|---------|
| 1 | authored_plan_package_import | Sprint 1.2: Plan Package provenance columns, package child tables, catalogue RLS tighten, immutability triggers, service-role import/publish/approve RPCs |
| 2 | athlete_catalogue_enrolment | Sprint 1.3: `enrolment_source` on assignments; athlete catalogue enrolment RPC (non-commercial test path) |
| 3 | athlete_plan_materialisation | Sprint 1.4: materialisation columns + `materialise_athlete_plan_from_enrolment` RPC + write guards |
| 4 | harden_materialisation_write_guard | Sprint 1.4 corrective: tighten materialisation write-guard trigger after staging probe |
| 5 | complete_programme_session_and_advance | Sprint 1.5: completion identity columns + atomic complete/advance RPC |
| 6 | add_programme_schedule_projection | Sprint 1.7C: schedule projection/occurrence/operation tables + ensure projection RPC + schedule_revision |
| 7 | apply_programme_schedule_move_swap | Sprint 1.7D: exact-preview Move/Swap apply RPC + RPC-only table guards |
| 8 | apply_programme_schedule_push_skip | Sprint 1.7E: extend apply RPC with Push/Skip |
| 9 | apply_programme_schedule_undo_horizon | Sprint 1.7F: scheduling horizon column + Undo in apply RPC |

DDL/DML character: primarily **DDL + function/policy/trigger DML-definition**; not
catalogue exercise seed data. Touch **programme / assignment / session / schedule /
completion** surfaces. Do **not** touch `exercises_v2` catalogue rows or payments.

Idempotency patterns: heavy use of `IF NOT EXISTS`, `CREATE OR REPLACE`,
`DROP … IF EXISTS` — still **not** treated as proof of safe re-apply.

---

## 4. Repository-history evidence

| Migration | Introducing commit (evidence) | Deployment status in docs |
|-----------|-------------------------------|---------------------------|
| 1 | `f8c9e11` (+ later edits) | Believed deployed on **Staging** without primary `db push` apply transcript; **Hosted Field Manual deliberately unapplied** (3.1F isolation stop) |
| 2 | `a23ddb3` | Same pattern (Staging Self-Test 1.3) |
| 3 | `b97477d` | Staging materialisation verify |
| 4 | `d24c57e` | Corrective **after** staging probe of #3 |
| 5 | `7f4da35` | Staging Self-Test 2 / completion docs |
| 6 | `17a12ce` | Scheduling v1 / Athlete D |
| 7 | `596f36a` | Scheduling Move/Swap |
| 8 | `0a2b51b` | Scheduling Push/Skip |
| 9 | `5555920` | Scheduling Undo / horizon |

Constraints preserved: additive chain over pre-existing hosted schema; no fake
baseline; no editing accepted migration files; EX-* / `exercises_v2` authority;
`protocol_steps` compatibility layer untouched by these nine.

Later `lib/` stores call the RPCs/tables these migrations define (Plan Package
import, enrolment, materialisation, completion, schedule). That means **application
code expects these effects where those features run** — typically Staging — while
Field Manual ledger+schema show they were never applied there.

---

## 5. Hosted migration ledger (read-only)

| Fact | Value |
|------|-------|
| Project | Cohort Field Manual / eu-west-1 / ACTIVE_HEALTHY |
| Ledger table | `supabase_migrations.schema_migrations` |
| Ledger count | **34** |
| Ledger max | `20260730150000` (`seed_cohort_session_templates`) |
| Nine pending versions in ledger | **0** |
| Part 2 seed in ledger | **0** |
| Later migrations recorded despite gap | **No** (clean trailing gap after `20260730150000`) |

Query hashes (sha256-16): ledger_all=`1b5242b6dff2412a`; gap_window=`465b353e5f7dcc96`;
summary=`ccfdf7eb88b856fd`.

---

## 6. Hosted-effect verification (read-only)

Base tables from earlier migrations **do** exist:
`programme_versions`, `programme_assignments`, `programme_version_session_slots`,
`training_session_records`, `exercises_v2`.

Material effects of the nine are **not** present:

| Probe | Hash | Result |
|-------|------|--------|
| Package columns on `programme_versions` | `fd288ba2ef69917d` | empty |
| Package child + schedule tables | `7359c526a9a015ed` | empty |
| Key RPCs/functions (import, enrol, materialise, complete, schedule) | `bfe3a48db10a2d31` | empty |
| Session-slot package columns | `653c74ec563fa76d` | empty |
| `enrolment_source` / `schedule_revision` | `3b82ae00866fed90` | empty |
| `scheduling_horizon_end` | `b91617d70093b6da` | empty |
| Related materialisation/schedule/immutability triggers | `c6e028e819fb5de8` | empty |
| Existence booleans | `a9ea91e927eb96e4` | all false / 0 |
| Materialisation cols count | (existence query) | 0 |
| Completion identity cols count | (existence query) | 0 |

Catalogue check (unchanged): published **127**, range `EX-001`…`EX-127`;
`EX-128`…`EX-132` count **0** (hashes `7ba52f6d20b3a967`, `208898a3d57d68a6`).

No athlete personal data retrieved.

---

## 7. Classification matrix

| Order | Migration | Purpose | Ledger status | Hosted effect status | Evidence | Reapply risk | Recommended treatment |
|------:|-----------|---------|---------------|----------------------|----------|--------------|------------------------|
| 1 | `20260731120000_authored_plan_package_import.sql` | Plan Package import/RLS/immutability | Missing | `ABSENT` | No package cols/tables/RPCs | High — policies + service RPCs | Apply only under dedicated Stage-1.2–1.7 auth |
| 2 | `20260801120000_athlete_catalogue_enrolment.sql` | Catalogue enrolment | Missing | `ABSENT` | No `enrolment_source` / enrol RPC | High — athlete assignment path | Same |
| 3 | `20260801140000_athlete_plan_materialisation.sql` | Plan materialisation | Missing | `ABSENT` | No materialise RPC/cols | High — plan materialisation | Same |
| 4 | `20260801150000_harden_materialisation_write_guard.sql` | Harden write guard | Missing | `ABSENT` | Guard objects absent with #3 | Medium — depends on #3 | Same (after #3) |
| 5 | `20260801160000_complete_programme_session_and_advance.sql` | Complete + advance | Missing | `ABSENT` | No complete RPC / identity cols | High — completion/cursor | Same |
| 6 | `20260803120000_add_programme_schedule_projection.sql` | Schedule projection | Missing | `ABSENT` | No schedule tables / ensure RPC | High — new schedule schema | Same |
| 7 | `20260803140000_apply_programme_schedule_move_swap.sql` | Move/Swap apply | Missing | `ABSENT` | No apply RPC / RPC-only triggers | High — athlete schedule mutations | Same |
| 8 | `20260803160000_apply_programme_schedule_push_skip.sql` | Push/Skip apply | Missing | `ABSENT` | Apply RPC absent | High — replaces apply body | Same |
| 9 | `20260803180000_apply_programme_schedule_undo_horizon.sql` | Undo + horizon | Missing | `ABSENT` | No horizon col / undo path | High — replaces apply body | Same |

Counts: ABSENT=9; EXACTLY_REPRESENTED=0; PARTIAL=0; CONFLICTING=0; INDETERMINATE=0.

---

## 8. Dependency and data risk

| Risk | Assessment |
|------|------------|
| Later repo code assumes effects | **Yes** — `lib/` Supabase stores for Plan Package, enrolment, materialisation, completion, schedule |
| Later migrations assume effects | **Yes** — #4–#9 build on #1–#3 / #6 |
| Hosted Field Manual app currently depends on equivalent structures | **No evidence** of these objects on Field Manual; Staging is where Self-Tests/Athlete D exercised them |
| Apply could modify production data | **Yes** — new policies, triggers, RPCs become callable; assignment/completion/schedule behaviour changes if clients call them |
| Silent skip of conflicting structures | Possible via `IF NOT EXISTS` / `CREATE OR REPLACE` — still not “safe by default” |
| Duplicate seed data | Low for these nine (schema/RPC focused); not exercise catalogue seeds |
| Policy/permission changes | **Yes** (especially #1 catalogue RLS + many ENABLE RLS) |
| Legacy compatibility | Must not disturb `protocol_steps` / historical evidence — these migrations do not rewrite completions, but add new completion/schedule machinery |
| Rollback | **Not straightforward** — large function/policy surface; destructive to reverse |

These cannot be treated as a trivial “pending queue clear.”

---

## 9. Recommended reconciliation outcome: **A1**

**A1 — APPLY ALL NINE IN ORDER** (under a **new, separate founder authorisation**).

Why safest relative to alternatives:

- Hosted effects are **ABSENT**, not partial/conflicting — so ledger repair without apply
  would **lie** about history (reject C1).
- No supported CLI path applies only the Phase 3.1F seed while leaving these nine
  pending (reject B1 / A2 with current tooling).
- Forward correction (C2) is unnecessary when the intended objects are simply not present.
- Continued blind deferral (C3) is acceptable short-term but does not unblock Stage 1;
  evidence now supports a clear apply path **if** founder accepts Field Manual Phase 1.2–1.7 uplift.

**A1 is not authorised by this report.** It must be an explicit founder sprint that:

1. Reviews each of the nine as a Field Manual programme-runtime deploy.
2. Dry-runs `db push` and confirms the pending set is exactly these nine (+ optional Part 2 seed sequencing decision).
3. Applies them in order with post-verify per migration family.
4. Only then re-opens Phase 3.1F catalogue Stage 1 for
   `20260809160000_founder_exercise_library_phase_3_1f_part2.sql`.

Do **not** repair the ledger to pretend they were applied.

---

## 10. Effect on Phase 3.1F five-row seed

| Item | Status |
|------|--------|
| Seed file | Still local only |
| Hosted EX-128…EX-132 | **Absent** |
| Catalogue | Still **127** / `EX-001`…`EX-127` |
| Seed blocked by nine pending | **Yes** — established `db push` would apply the nine first |
| First consumer | Still recommended `founder_programme_yaml_import`; **not implemented**; bridge unwired |
| Identity bridge | Unwired to live consumers |

---

## 11. Confirmations

- No hosted mutation performed.
- Migration history not repaired.
- No application code deployed.
- No consumer migrated.
- Historical evidence not rewritten.
- Schema not changed by this audit.
- No credentials stored in this document.

---

## 12. Smallest next founder authorisation required

Authorise a dedicated sprint:

**“Field Manual Phase 1.2–1.7 migration uplift (nine migrations)”**

Scope: review + dry-run + apply exactly the nine files listed in §2 to Cohort Field
Manual; post-verify schema/RPC presence; **exclude** Phase 3.1F catalogue seed and
first-consumer wiring unless separately listed.

After that uplift succeeds, re-authorise Phase 3.1F Stage 1 catalogue seed in isolation
(dry-run must show only `20260809160000_…part2.sql`).
