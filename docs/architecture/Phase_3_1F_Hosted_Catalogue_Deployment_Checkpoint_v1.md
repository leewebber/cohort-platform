# Phase 3.1F — Hosted Catalogue Deployment Checkpoint

**Status:** STOPPED before mutation — deployment isolation not proven; Option **C**
deferral continues pending founder review of the nine-migration reconciliation  
**Recorded:** 2026-08-09  
**Rollout-plan commit:** `e8e45796ff658b5af8b71aee1f7a92996919d1d7`  
**Part 2 implementation:** `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc`  
**Authorised migration:** `20260809160000_founder_exercise_library_phase_3_1f_part2.sql`  
**Reconciliation (read-only, uncommitted):**  
[`Phase_3_1F_Pending_Migration_Reconciliation_v1.md`](./Phase_3_1F_Pending_Migration_Reconciliation_v1.md)  
— all nine earlier pending migrations are ledger-absent **and** effect-`ABSENT` on
Cohort Field Manual; recommended next path **A1** under separate authorisation;
Phase 3.1F seed remains blocked.

```text
ROLLOUT_PLAN_ACCEPTED=true
ROLLOUT_PLAN_COMMITTED=true
ROLLOUT_PLAN_COMMIT=e8e45796ff658b5af8b71aee1f7a92996919d1d7
HOSTED_DEPLOYMENT_AUTHORISED=true
HOSTED_PROJECT=Cohort_Field_Manual
HOSTED_REGION=eu-west-1
HOSTED_PREFLIGHT_PASSED=true
DEPLOYMENT_ISOLATION_PROVEN=false
HOSTED_MUTATION_PERFORMED=false
CANONICAL_ROWS_INSERTED=0
AUTHORITATIVE_CANONICAL_CATALOGUE_COUNT=127
AUTHORITATIVE_CANONICAL_ID_RANGE=EX-001..EX-127
EX_128_TO_EX_132_VERIFIED=false
EX_001_TO_EX_127_CHANGED=false
OTHER_MIGRATIONS_APPLIED=0
APPLICATION_CODE_DEPLOYED=false
FIRST_CONSUMER_RECOMMENDED=founder_programme_yaml_import
FIRST_CONSUMER_IMPLEMENTED=false
PHASE_3_1F_COMPLETE=true
PHASE_3_1_COMPLETE=false
```

---

## 1. Founder authorisation (this checkpoint)

Authorised: review/commit rollout plan; read-only preflight on
`public.exercises_v2`; apply **exactly** the Part 2 seed migration if isolation
can be proven; post-verify; document.

Not authorised: first-consumer implementation; other migrations; schema DDL;
modifying EX-001…EX-127; app deploy; evidence rewrite.

---

## 2. Hosted access scope used

| Action | Used |
|--------|------|
| Project identity via linked CLI | Yes — **Cohort Field Manual**, `eu-west-1`, ACTIVE_HEALTHY |
| SELECT-only on `public.exercises_v2` | Yes (preflight) |
| `supabase migration list --linked` | Yes (isolation proof) |
| `supabase db push --linked --dry-run` | Yes (isolation proof; no apply) |
| Apply Part 2 migration | **No** — STOP |
| Other tables / RPCs / app deploy | **No** |

No credentials printed or stored.

---

## 3. Local SQL revalidation

File: `supabase/migrations/20260809160000_founder_exercise_library_phase_3_1f_part2.sql`  
Content hash (sha256-16): `69ebd998ae4da92e`

| Check | Result |
|-------|--------|
| Targets only `public.exercises_v2` | Pass |
| Exact EX-128…EX-132 definitions | Pass |
| No DDL schema objects | Pass |
| No `ON CONFLICT DO UPDATE` / silent `DO NOTHING` | Pass |
| Exact-match idempotent no-op + RAISE on mismatch/partial | Pass |
| Names match Dart seed map | Pass |
| No consumer / athlete / programme mutation | Pass |

---

## 4. Read-only preflight results

| Check | Result |
|-------|--------|
| Published count | **127** |
| ID range | `EX-001` … `EX-127` contiguous |
| EX-128…EX-132 present | **0 rows** |
| Equivalent name/slug collisions (Lat Pulldown, Running, Burpee Broad Jump, Sled Push, Sled Pull) | **0** |
| EX-050 Ski Erg | Present, published, slug `ski-erg` |
| EX-052 Wall Ball | Present, published, slug `wall-ball` |
| Duplicate / malformed IDs | **0** |

**HOSTED_PREFLIGHT_PASSED=true**

---

## 5. Deployment isolation — FAILED

`supabase db push --linked --dry-run` would apply **10** migrations, not one:

1. `20260731120000_authored_plan_package_import.sql`
2. `20260801120000_athlete_catalogue_enrolment.sql`
3. `20260801140000_athlete_plan_materialisation.sql`
4. `20260801150000_harden_materialisation_write_guard.sql`
5. `20260801160000_complete_programme_session_and_advance.sql`
6. `20260803120000_add_programme_schedule_projection.sql`
7. `20260803140000_apply_programme_schedule_move_swap.sql`
8. `20260803160000_apply_programme_schedule_push_skip.sql`
9. `20260803180000_apply_programme_schedule_undo_horizon.sql`
10. `20260809160000_founder_exercise_library_phase_3_1f_part2.sql` ← authorised only

Per stop rules: presence of additional pending migrations + inability to select
only the authorised migration → **STOP before mutation**.

Forbidden workarounds not used: rename, repair history, mark unrelated as
applied, or execute seed outside migration tracking.

**DEPLOYMENT_ISOLATION_PROVEN=false**  
**HOSTED_MUTATION_PERFORMED=false**

---

## 6. Smallest founder decision required

**Option C (temporary) accepted** — Stage 1 deferred for reconciliation.

Read-only reconciliation (see linked report) found the nine migrations are
**ABSENT** from both ledger and hosted effects on Field Manual. Recommended
follow-on (not authorised here): **A1** — dedicated Field Manual Phase 1.2–1.7
uplift applying the nine in order, then re-open Phase 3.1F catalogue Stage 1.

Do **not** repair the ledger, run raw INSERT for the catalogue seed, or wire
`founder_programme_yaml_import` until that review.

---

## 7. Confirmations

| Item | Status |
|------|--------|
| Application code deployed | false |
| Consumers migrated | false |
| Historical evidence rewritten | false |
| Schema changed | false |
| Mapping implies substitution/comparability | false |
| Comparison protocol sole positive authority | true |
| First consumer implemented | false |

---

## 8. Remaining work

1. Founder decision A/B/C above.
2. After isolated apply succeeds: post-verify count=132 and EX-128…132 exact match.
3. Separately authorised `founder_programme_yaml_import` implementation.

Manual testing: deferred until first executable consumer integration.
