# Phase 1.2–1.7 — Staging Manual Athlete-Flow Verification (v1)

**Status:** STOPPED before hosted test mutation — verification **not accepted**;
STOP evidence accepted by Lee Webber for prerequisite resolution  
**Recorded:** 2026-08-09  
**Branch:** `codex/b4d21b-rebind-path`  
**Baseline HEAD (pre-plan commit):** `e348f9cf3d99a5c807c367670c0a336e924cef88`  
**Staging-plan commit:** `7f19ef2a1e8f2a76c91ddeb3b5627efca425cc2c`  
**Worktree at verification start after plan commit:** clean (CLI `.temp` link noise restored)

```text
STAGING_UPLIFT_PLAN_ACCEPTED=true
STAGING_UPLIFT_PLAN_COMMITTED=true
STAGING_UPLIFT_PLAN_COMMIT=7f19ef2a1e8f2a76c91ddeb3b5627efca425cc2c
STAGING_MANUAL_VERIFICATION_AUTHORISED=true
STAGING_PROJECT=Cohort_Staging
STAGING_PROJECT_REF=tsbadngzgvsyfqjupkng
STAGING_REGION=eu-west-2
STAGING_PROJECT_IDENTITY_PROVEN=true
STAGING_BACKUP_OR_RECOVERY_READY=false
STAGING_APPLICATION_TARGET_PROVEN=false
TEST_ATHLETE_NAMESPACE=none
MANUAL_TESTS_REQUIRED=12
MANUAL_TESTS_PASSED=0
MANUAL_TESTS_FAILED=0
MANUAL_TESTS_BLOCKED=12
STAGING_ATHLETE_FLOW_VERIFIED=false
ATHLETE_C_ACCESSED=false
ATHLETE_C_CHANGED=false
ATHLETE_A_OR_B_CHANGED=false
ATHLETE_D_CHANGED=false
TEST_NAMESPACE_ESCAPED=false
STAGING_TEST_DATA_RETAINED=false
STAGING_TEST_DATA_CLEANED=false
MIGRATIONS_APPLIED=0
MIGRATION_HISTORY_REPAIRED=false
PHASE_3_1F_SEED_APPLIED=false
FIELD_MANUAL_MUTATION_PERFORMED=false
APPLICATION_CODE_CHANGED=false
APPLICATION_CODE_DEPLOYED=false
FIRST_CONSUMER_RECOMMENDED=founder_programme_yaml_import
FIRST_CONSUMER_IMPLEMENTED=false
STAGING_STOP_EVIDENCE_ACCEPTED=true
FIELD_MANUAL_UPLIFT_AUTHORISED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

This report does **not** claim Staging acceptance. No Athlete E namespace was created.
No hosted mutation was performed.

**Follow-on (prerequisite resolution, separate document):**  
[`Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md`](./Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md)
records the accepted logical recovery artifact and Athlete E bootstrap design.
That follow-on does **not** execute T1–T12 or create hosted Athlete E.

---

## 1. Founder authorisation

Lee accepted the Staging uplift plan and authorised isolated Athlete E T1–T12
verification through supported application/RPC paths only.

Not authorised: `supabase db push`; migrations; Phase 3.1F seed; Field Manual
mutation; ledger repair; arbitrary SQL DML/DDL; Athlete C/D reuse; Athlete A/B
mutation; first-consumer implementation; app deploy; production promotion.

---

## 2. Baseline commit and branch

| Item | Value |
|------|-------|
| Branch | `codex/b4d21b-rebind-path` |
| HEAD before this task | `e348f9cf3d99a5c807c367670c0a336e924cef88` |
| Staging plan commit (task A) | `7f19ef2a1e8f2a76c91ddeb3b5627efca425cc2c` |
| Reconciliation commit | `e348f9cf3d99a5c807c367670c0a336e924cef88` |

---

## 3. Staging identity and region

| Check | Result |
|-------|--------|
| Linked name | **Cohort Staging** |
| Ref | `tsbadngzgvsyfqjupkng` |
| Region | `eu-west-2` |
| Status | ACTIVE_HEALTHY |
| Not Field Manual | Proven (`otnhhdxs…` / eu-west-1 distinct) |
| Operator API env host | `tsbadngzgvsyfqjupkng.supabase.co` (staging; not production) |

CLI was restored to **Cohort Field Manual** after Staging inspection. No Field
Manual mutation occurred.

---

## 4. Backup / PITR / recovery evidence — **NOT READY**

Command: `supabase backups list --project-ref tsbadngzgvsyfqjupkng`

| Field | Observed |
|-------|----------|
| region | `eu-west-2` |
| `pitr_enabled` | **false** |
| `walg_enabled` | true |
| `backups` | **[]** (empty) |
| `physical_backup_data` | **{}** (empty) |

**STAGING_BACKUP_OR_RECOVERY_READY=false**

Per stop rules, hosted test mutation must not proceed until founder-approved
backup/PITR (or equivalent restore) readiness is established and recorded.

---

## 5. Preflight migration and aggregate state (unchanged vs audit)

| Check | Result |
|-------|--------|
| Ledger count | **43** |
| Ledger max | **`20260803180000`** |
| Nine Phase 1.2–1.7 versions present | **9/9** |
| Later migrations | **0** |
| Phase 3.1F seed in ledger | **0** |
| EX-128…EX-132 rows | **0** |
| Prerequisite tables + key RPCs | Present |
| Aggregates | assignments=6, versions=6, lineages=6, tsr=3, projections=3, occurrences=6, operations=14 |

No evidence another operator changed relevant Staging state since the uplift audit.

---

## 6. Athlete E namespace — **NOT CREATED**

### Capability inventory (repository)

| Capability | Present? |
|------------|----------|
| `tool/staging/create_*athlete*e*` | **No** |
| `lib/main_*athlete*e*` | **No** |
| Product onboarding path authorised for Staging Athlete E without new code | **No** (not implemented for this task) |
| Existing Athlete D creator (`create_s17_athlete_d_fixture.sh`) | Yes — **forbidden** to reuse/mutate Athlete D |
| Existing Flutter staging verify targets (s13/s14/s15/s17) | Yes — bound to prior athlete fixtures / Athlete D resume, not Athlete E |

### Why STOP (setup)

Task rules require Athlete E via a **normal supported authentication/onboarding
path** (or an already accepted harness that needs **no code changes** and does
not reuse Athlete D). No such Athlete E path exists. Implementing a new creator,
UI, or SQL-manufactured auth user is **out of scope**.

**TEST_ATHLETE_NAMESPACE=none**

---

## 7. Application build and configuration classification

| Item | Status |
|------|--------|
| Application code changed | false |
| Staging binary deployed | false |
| Flutter app launched against Staging | **Not launched** (stopped before mutation) |
| Staging target proven in running app | **false** |
| Commit that would have been used | `7f19ef2a1e8f2a76c91ddeb3b5627efca425cc2c` |

Existing stores exist for Plan Package import and catalogue enrolment under
`lib/features/…`, but without Athlete E + Staging app launch they were not
exercised hosted.

---

## 8. T1–T12 results

All twelve tests are **BLOCKED** before execution. No UI or DB write evidence.

| Test | Result | Reason |
|------|--------|--------|
| T1 Founder Plan Package import | **BLOCKED** | Backup/recovery not ready; no Athlete E / founder Staging import session |
| T2 Catalogue visibility & enrolment | **BLOCKED** | Depends on T1 + Athlete E |
| T3 Plan materialisation | **BLOCKED** | Depends on T2 |
| T4 Materialisation write guard | **BLOCKED** | Depends on T3 |
| T5 Session completion & advance | **BLOCKED** | Depends on T3/T4 |
| T6 Schedule projection | **BLOCKED** | Depends on T5 |
| T7 Move and swap | **BLOCKED** | Depends on T6 |
| T8 Push and skip | **BLOCKED** | Depends on T6 |
| T9 Undo horizon | **BLOCKED** | Depends on T7/T8 |
| T10 Restore/reopen | **BLOCKED** | Depends on prior tests + app launch |
| T11 Failure behaviour | **BLOCKED** | Depends on Athlete E namespace |
| T12 Preservation checks | **BLOCKED** | No test mutations; baseline aggregates confirmed at preflight only |

**Passed=0, Failed=0, Blocked=12**  
**STAGING_ATHLETE_FLOW_VERIFIED=false**

---

## 9. UI evidence

None. Application was not launched against Staging.

---

## 10. Database evidence

Read-only preflight only (see §5). No Athlete E writes. No partial transactions.

---

## 11. Failure / blocked-test evidence

Primary blockers (either alone is sufficient to STOP):

1. **Backup/PITR readiness not established** (`pitr_enabled=false`, empty backup list).
2. **Missing Athlete E supported creation path** (no code changes authorised; Athlete D harness forbidden).

No ambiguous hosted mutation occurred.

---

## 12. Existing-data preservation

| Check | Result |
|-------|--------|
| Preflight aggregates match uplift plan | Yes |
| Hosted mutation after preflight | **None** |
| Athlete C accessed/modified | **false** |
| Athlete A/B modified | **false** |
| Athlete D reused/modified | **false** |
| Namespace escape | **false** (no namespace created) |

Post-test aggregate re-query was unnecessary for mutation proof because no
mutation ran; ledger/seed checks in §5 stand as the preservation baseline.

---

## 13. Migration-ledger preservation

| Check | Result |
|-------|--------|
| Ledger max still `20260803180000` | Yes (preflight) |
| Migrations applied this task | **0** |
| History repaired | **false** |

---

## 14. Phase 3.1F seed status

| Check | Result |
|-------|--------|
| Seed in ledger | Absent |
| EX-128…EX-132 rows | 0 |
| `db push` run | **No** |

---

## 15. Automated validation results

| Suite | Result |
|-------|--------|
| Phase 2 consolidation safety gate | **PASS** `groups_passed=6` |
| Focused Plan Package / programme / schedule / supabase migration contracts / architecture | **300 passed**, 0 failed, 0 skipped |

No application code or tests were edited.

---

## 16. Athlete E retention status

No Athlete E records created. Cleanup not applicable.  
**STAGING_TEST_DATA_RETAINED=false** (nothing to retain)  
**STAGING_TEST_DATA_CLEANED=false**

---

## 17. Production-promotion recommendation

**Do not authorise Field Manual Phase 1.2–1.7 uplift** based on this report.

Staging athlete-flow verification did **not** pass. Production promotion remains
blocked until T1–T12 pass under an accepted Staging recovery posture and a
supported Athlete E path.

---

## 18. Smallest next founder authorisation

Authorise a narrow setup sprint that, in order:

1. Establishes and records **Cohort Staging backup/PITR (or equivalent restore)
   readiness** with listable restore points (or an accepted alternate recovery
   procedure).
2. Authorises **implementation of a dedicated Athlete E Staging creator/harness**
   (namespaced; fail-closed; no Athlete C/D reuse; no Field Manual contact;
   no `db push`), **or** authorises use of an existing product onboarding path
   proven against Staging without new SQL auth manufacture.
3. Re-authorises execution of T1–T12 only after (1) and (2) are complete.

Phase 3.1F seed and `founder_programme_yaml_import` remain separately controlled.

---

## 19. Confirmations

- No `supabase db push`.
- No migrations applied or repaired.
- No Phase 3.1F seed applied.
- No Field Manual mutation.
- No application deployment.
- No first consumer implemented.
- Historical evidence not rewritten.
- Athlete C not accessed.
- Secrets/credentials not recorded in this document.
