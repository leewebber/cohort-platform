# Phase 1.2–1.7 — Staging Verification Prerequisites (v1)

**Status:** ACCEPTED by Lee Webber — prerequisites complete; Gate 1 separately authorised  
**Recorded:** 2026-08-09  
**STOP-report commit:** `5496afb7abf467e85b0bfe03a15f8f240388cebc`  
**Staging-plan commit:** `7f19ef2a1e8f2a76c91ddeb3b5627efca425cc2c`

```text
STAGING_STOP_EVIDENCE_ACCEPTED=true
STAGING_STOP_REPORT_COMMITTED=true
STAGING_STOP_REPORT_COMMIT=5496afb7abf467e85b0bfe03a15f8f240388cebc
STAGING_NATIVE_PITR_ENABLED=false
STAGING_NATIVE_BACKUPS_AVAILABLE=false
LOGICAL_RECOVERY_MECHANISM_ACCEPTED=true
LOGICAL_BACKUP_CREATED=true
LOGICAL_BACKUP_COMMITTED=false
LOCAL_RESTORE_REHEARSAL_PASSED=true
AUTH_RECOVERY_COVERED=true
ATHLETE_E_BOOTSTRAP_IMPLEMENTED=true
ATHLETE_E_BOOTSTRAP_HOSTED_EXECUTED=false
TEST_ATHLETE_NAMESPACE=none
STAGING_HOSTED_MUTATION_PERFORMED=false
FIELD_MANUAL_MUTATION_PERFORMED=false
MANUAL_TESTS_EXECUTED=0
PREREQUISITES_COMPLETE=true
FIELD_MANUAL_UPLIFT_AUTHORISED=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

Hosted Athlete E create and Gate 1 T1–T12 require the separate Gate 1 founder
authorisation (not granted by this document alone).

---

## 1. Founder acceptance of the STOP

Lee accepted the STOP from
[`Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md`](./Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md):
preflight passed; native backup/PITR unavailable; Athlete E path missing; T1–T12
BLOCKED (0 FAIL); no hosted mutation; safety gate 6/6; focused suite 300 passed.

This sprint resolved those two blockers only.

---

## 2. STOP-report commit

`5496afb7abf467e85b0bfe03a15f8f240388cebc` —
`Phase 1.2-1.7: document blocked staging verification`

---

## 3. Staging identity (re-proven read-only)

| Check | Result |
|-------|--------|
| Name | Cohort Staging |
| Ref | `tsbadngzgvsyfqjupkng` |
| Region | `eu-west-2` |
| Health | ACTIVE_HEALTHY |
| Not Field Manual | Proven |
| Ledger count / max | **43** / **`20260803180000`** |
| Nine migrations | Present |
| Phase 3.1F seed | Absent |
| Protected aggregates | 6/6/6/3 + schedule 3/6/14 unchanged |

CLI restored to Cohort Field Manual after work. No Field Manual mutation.

---

## 4. Native backup/PITR status

| Field | Value |
|-------|-------|
| `pitr_enabled` | **false** |
| Listable backups | **[]** |
| Paid feature change | **Not performed** (forbidden) |

Native PITR remains unavailable. Logical recovery is the accepted substitute for
T1–T12 risk containment on Staging.

---

## 5. Logical backup scope

Private artifact directory (mode **700**, outside Git):

`/tmp/cohort_staging_logical_backup.20260809T094540Z.5Q91TxZV`

**Not committed. Not placed in docs. Contents not logged.**

| Schema | Schema dump | Data dump | Purpose |
|--------|-------------|-----------|---------|
| `public` | yes | yes (COPY) | Programme/package, assignments, versions, lineages, slots, schedule, completions, TSR, RPCs/triggers/policies |
| `auth` | yes | yes (includes `auth.users`) | Authentication identity recovery |
| `supabase_migrations` | yes | yes | Ledger preservation (43 / max `20260803180000`) |

Source inventory: **34** public tables, **23** auth tables, auth_users=**7**.

---

## 6. Backup artifact handling and hashes (SHA-256)

| File | SHA-256 | Bytes |
|------|---------|------:|
| `public.sql` | `be9676313398e00238d9abc5801df4fb94d54bed434317f4d9375f67e003f7bf` | 361259 |
| `public_data.sql` | `7907b45cf044ffb4b7f0eb37bf63052c44f426b56d2fbf91560da4c038404499` | 87895 |
| `auth.sql` | `384b9181a7fb38ee5e281967d62079e517d999149ac8c841d4adf2ddaa4780d4` | 46591 |
| `auth_data.sql` | `7bc521ee51d1f3d5f3d5d2728e99f8fe61cde9cb67efaaa5f3457ee2b53f0ba1` | 42908 |
| `supabase_migrations.sql` | `18b99fbbb3ec9fbb964bb255a56171329acd99b6977ece2addd89fdf5aa5105b` | 887 |
| `supabase_migrations_data.sql` | `fc2760d2b22d62da6294fe0baf78befa80a5aba4a2811ce9f5e016b24076acb8` | 573184 |
| `source_manifest.json` | `c74ced21734a2e9d5e7635ffd2982c10f1de3a5b3da2c233b17abe2cbf945fe5` | 6242 |
| `restore_validation.txt` | `b8c842d58dbbb56b7b192c2843a94b1f06b157a44fbd282af2de24423f5857ee` | 230 |
| `recovery_manifest.json` | `a8e06d3d30eb206b1e912d03f56854ac609376549b36e938e47a2eeaf1dd3690` | (manifest) |

Retention: keep artifact until founder review and completion of authorised T1–T12.
Do not commit. Destroy only under later founder authorisation.

---

## 7. Local restore-rehearsal result

| Step | Result |
|------|--------|
| Disposable DB | Docker `postgres:15-alpine` on `127.0.0.1` only |
| Restore target | **Not** Cohort Staging; **Not** Field Manual |
| Aggregate match | **Yes** — assignments/versions/lineages/tsr/schedule/ledger/auth_users |
| Required RPCs present | **Yes** — import, enrol, materialise, complete, ensure projection, apply |
| Disposable DB destroyed | **Yes** |
| Non-blocking noise | missing `dashboard_user` role; `maintain` privilege; `transaction_timeout` GUC |

**LOCAL_RESTORE_REHEARSAL_PASSED=true**

---

## 8. Recovery limitations

1. Restore into hosted Staging was **not** rehearsed (forbidden). Hosted restore would
   need a separate founder authorisation and operational runbook.
2. Privilege/role statements from Supabase dumps are incomplete on plain Postgres;
   data + function recovery still validated.
3. Circular FK on `programme_assignments` requires trigger-disabled data load
   (`session_replication_role=replica`) during rehearsal.
4. Native PITR remains preferable long-term if later enabled under separate auth;
   this logical artifact is the accepted interim mechanism.

**AUTH_RECOVERY_COVERED=true** (auth schema + `auth.users` data included and restored
to count 7).

---

## 9. Athlete E bootstrap design

Test-only administration infrastructure (not product onboarding):

| Path | Role |
|------|------|
| `tool/staging/lib/s17e_athlete_e_bootstrap.py` | Fail-closed planning/guards |
| `tool/staging/create_s17_athlete_e_fixture.sh` | Operator entrypoint |
| `test/staging/s17e_athlete_e_bootstrap_test.py` | Non-hosted unit tests |
| `test/staging/s17e_athlete_e_bootstrap_dart_test.dart` | Thin Flutter test wrapper |

Bootstrap creates (when separately authorised for hosted mode) only:

- auth user (Admin Auth API)
- athlete profile row sufficient for normal sign-in

It does **not** auto-enrol, materialise, complete, or schedule (those remain T1–T12).

---

## 10. Project and namespace guards

| Guard | Behaviour |
|-------|-----------|
| Exact Staging ref | Must be `tsbadngzgvsyfqjupkng` |
| Field Manual | Explicit reject (`otnhhdxs…` / name) |
| Unknown project | Reject |
| Protected namespaces | Reject Athlete A/B/C/D tokens and known fixture ids |
| Email pattern | `s17e_stage_<stamp>_<hex>.athlete.e@example.invalid` |
| Secrets | Never printed; redacted in manifests |
| `db push` / migrations | Hard refuse |
| Cleanup/delete | Not implemented; refuse |
| Hosted create | Requires `S17E_HOSTED_CREATE=1` **and** still refuses until separate founder auth removes the task-level hard stop |

---

## 11. Local bootstrap validation

Hosted create was **not** executed. Dry-run path and unit tests only.

| Suite | Result |
|-------|--------|
| `s17e_athlete_e_bootstrap_test.py` | **11 passed** |
| `s17e_athlete_e_bootstrap_dart_test.dart` | **3 passed** |
| Phase 2 safety gate | **PASS 6/6** |
| Focused Plan Package / programme / schedule / architecture | **257 passed** |

---

## 12. UI availability classification for T1–T12

Two gates are required. Do not silently redefine a UI test as harness-only.

### Gate 1 — Phase 1.2–1.7 backend/RPC contract verification

Uses application services / RPCs / accepted staging harness patterns with Athlete E.

### Gate 2 — Later athlete product-UI end-to-end verification

When dedicated product UI exists beyond staging harness entrypoints.

| Test | Classification | Notes |
|------|----------------|-------|
| T1 Founder Plan Package import | **SUPPORTED_HARNESS_REQUIRED** | Import store/RPC exists; founder product UI not the Staging verify path. Use founder/service import contract + harness. |
| T2 Catalogue visibility & enrolment | **SUPPORTED_HARNESS_REQUIRED** | Enrolment service/store + RPC; s13/s17 harnesses cover catalogue/enrol patterns (Athlete E adaptation required). |
| T3 Plan materialisation | **SUPPORTED_HARNESS_REQUIRED** | Materialisation service/RPC; existing staging harness pattern. |
| T4 Materialisation write guard | **SUPPORTED_HARNESS_REQUIRED** | Guard is DB trigger/RPC contract; negative path via rejected client write, not product settings UI. |
| T5 Session completion & advance | **SUPPORTED_HARNESS_REQUIRED** | Completion harness (`s17_completion_harness`) / RPC; not full product player E2E claim. |
| T6 Schedule projection | **SUPPORTED_HARNESS_REQUIRED** | Projection store + restore service in s17 verify. |
| T7 Move and swap | **SUPPORTED_HARNESS_REQUIRED** | Apply service/RPC in s17; athlete calendar product UI not claimed as UI_AVAILABLE. |
| T8 Push and skip | **SUPPORTED_HARNESS_REQUIRED** | Same apply RPC family via harness. |
| T9 Undo horizon | **SUPPORTED_HARNESS_REQUIRED** | Undo diagnosis/harness + RPC. |
| T10 Restore/reopen | **SUPPORTED_HARNESS_REQUIRED** | App/harness restart against Staging; local persistence + server restore. |
| T11 Failure behaviour | **SUPPORTED_HARNESS_REQUIRED** | Contract rejection paths via services/RPCs. |
| T12 Preservation checks | **SUPPORTED_HARNESS_REQUIRED** | Read-only aggregate/ledger verification (no UI). |

**No T1–T12 item is currently `UI_AVAILABLE` as a production athlete/founder UI path
independent of staging harnesses.** None are `NOT_YET_IMPLEMENTED` at the
backend/RPC contract layer for Phase 1.2–1.7.

Therefore the next authorised verification should be explicitly labelled:

> **Gate 1:** Phase 1.2–1.7 backend/RPC + staging-harness verification for Athlete E  
> **Gate 2 (later):** Product UI E2E when those surfaces ship

Do not claim end-to-end athlete UI verification for harness-only tests.

---

## 13. Prerequisites satisfied?

| Prerequisite | Status |
|--------------|--------|
| STOP report committed | **Yes** |
| Logical recovery artifact | **Yes** |
| Local restore rehearsal | **Yes** |
| Auth recovery covered | **Yes** |
| Athlete E bootstrap implemented | **Yes** |
| Bootstrap not hosted-executed | **Yes** |
| T1–T12 still unexecuted | **Yes** |
| UI vs harness boundaries documented | **Yes** |

**PREREQUISITES_COMPLETE=true** (for founder review; does not auto-authorise T1–T12).

---

## 14. Exact smallest next founder authorisation

Authorise a narrow sprint:

1. Confirm retention of the private logical backup artifact listed in §5–§6.
2. Authorise **hosted Athlete E create** via
   `CONFIRM_COHORT_STAGING=1 S17E_HOSTED_CREATE=1 ./tool/staging/create_s17_athlete_e_fixture.sh --hosted`
   after removing/superseding the prerequisite hard-stop in that script under that
   authorisation (or an equivalent one-line auth flag agreed in the sprint brief).
3. Authorise **Gate 1** execution of T1–T12 as backend/RPC + staging-harness
   verification against Athlete E only.
4. Keep Gate 2 product-UI E2E separately blocked.
5. Continue to forbid `supabase db push`, Field Manual mutation, Phase 3.1F seed,
   and Athlete A/B/C/D reuse.

---

## 15. Confirmations

- No Athlete E created on Staging.
- No T1–T12 executed.
- No hosted application-data mutation.
- No Field Manual mutation.
- No migrations applied/repaired.
- No Phase 3.1F seed applied.
- No production application-code behaviour changes (test/tooling only).
- No secrets committed.
