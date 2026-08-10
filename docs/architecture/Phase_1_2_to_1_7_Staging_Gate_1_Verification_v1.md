# Phase 1.2–1.7 — Staging Gate 1 Backend/RPC Verification (v1)

**Status:** COMPLETE — reviewed for permanent evidence commitment  
**Classification:** `GATE_1_BACKEND_RPC` only (not product-UI Gate 2)  
**Recorded:** 2026-08-09  
**Worktree:** `[REDACTED_GATE_1_WORKTREE]`  
**Branch:** `codex/b4d21b-rebind-path`

```text
STAGING_GATE_1_AUTHORISED=true
STAGING_GATE_1_VERIFIED=true
PRODUCT_UI_GATE_2_VERIFIED=false
STAGING_GATE_1_REPORT_COMMITTED=true
MANUAL_TESTS_EXECUTED=12
MANUAL_TESTS_PASSED=12
MANUAL_TESTS_FAILED=0
MANUAL_TESTS_BLOCKED=0
```

---

## 1. Founder authorisation

Lee Webber authorised Phase 1.2–1.7 Staging Gate 1 backend/RPC verification,
including Athlete E namespace writes on Cohort Staging, T1–T12 contract tests,
read-only inspection, and an uncommitted Gate 1 report.

Explicitly **not** authorised (and not performed in this report phase): product-UI
Gate 2; `supabase db push`; migration apply/repair; Phase 3.1F seed; Field Manual
mutation; production uplift; application deployment; Athlete E cleanup; Athlete
A/B/C/D mutation; inventing missing evidence by re-running hosted Gate 1.

---

## 2. STOP-report commit

`5496afb7abf467e85b0bfe03a15f8f240388cebc` —
`Phase 1.2-1.7: document blocked staging verification`

---

## 3. Prerequisite commit and review result

| Item | Result |
|------|--------|
| Prerequisite commit | `33b0645f6557af7eadeb056a5924f35281a07823` |
| Message | `Phase 1.2-1.7: add staging verification prerequisites` |
| Committed **before** hosted Athlete E / Gate 1 writes | **Yes** (sequence preserved) |
| Review result | Accepted: logical recovery docs, restore rehearsal evidence, Staging-only guards, Athlete A–D rejection, no cleanup/db-push capability, Gate 1 vs Gate 2 separation |

No rewrite of the commit sequence was performed.

---

## 4. Baseline and final repository state

| Field | Value |
|-------|--------|
| Baseline HEAD (during Gate 1 + this report) | `33b0645f6557af7eadeb056a5924f35281a07823` |
| Branch | `codex/b4d21b-rebind-path` |
| New commits during hosted Gate 1 / evidence finalisation | **None** |
| Permanent evidence commitment | This report's commit; parent must be the prerequisite commit above |

**Permanent evidence set:**

- `docs/architecture/Phase_1_2_to_1_7_Staging_Gate_1_Verification_v1.md` (this report)
- `docs/architecture/README.md` (index line)
- `tool/staging/run_s17e_gate1_backend_rpc.py` (test-only, locally hardened orchestrator)
- `tool/staging/fixtures/athlete_e/` (Gate 1 package YAML)
- `test/staging/s17e_write_gate1_payload_test.dart` (compile/rebind helper)
- `test/staging/s17e_gate1_harness_guard_test.py` (local fail-closed guard tests)

Private (not in Git): Athlete E evidence under
`[REDACTED_PRIVATE_EVIDENCE_PATH]`
including `gate1_results.json`, `redacted_manifest.json`, `creation_state.json`.

`supabase/.temp/*` is local CLI metadata and is explicitly excluded from the
permanent evidence commit.

---

## 5. Staging identity and region

| Check | Result |
|-------|--------|
| Name | Cohort Staging |
| Ref | `tsbadngzgvsyfqjupkng` |
| Region | `eu-west-2` |
| Status | ACTIVE_HEALTHY |
| Not Field Manual | Proven |

CLI was temporarily linked to Staging for read-only post-checks, then restored to
**Cohort Field Manual** (`otnhhdxstdnwccehacku`).

---

## 6. Logical-backup integrity and retention

| Check | Result |
|-------|--------|
| Path | `[REDACTED_PRIVATE_BACKUP_PATH]` |
| Mode | `0700` |
| In Git | **No** |
| SHA-256 preflight | All expected dump/manifest hashes matched (`BACKUP_PREFLIGHT_OK`) |
| Coverage | `public`, `auth`, `supabase_migrations` |
| Prior restore rehearsal | Accepted in prerequisites |
| Retained privately | **Yes** |

---

## 7. Athlete E bootstrap result and redacted namespace

| Field | Value |
|-------|--------|
| Bootstrap tooling | Committed at `33b0645…` |
| Hosted create | **Once** (authorised Gate 1) |
| Status | `hosted_created` / stage `complete` |
| Namespace / run marker | `s17e_stage_20260809T101040Z_2ff4396a` |
| Athlete id prefix | `726e952a…` |
| Email (redacted) | `s17e_sta…@example.invalid` |
| Display name | S17E Staging Athlete E |
| Minimum records | `auth_user`, `athlete_profile` |
| Passwords/tokens in Git | **None** |
| Cleanup | **Not performed** (retained) |

---

## 8. Hosted record categories created (Gate 1 namespace)

Attributable to Athlete E and/or dedicated package `PROG-S17E-GATE1`:

| Category | Evidence (counts / prefixes) |
|----------|------------------------------|
| Auth user + profile | 1 each (`auth_e=1`, `profile_e=1`) |
| Programme lineage | `PROG-S17E-GATE1` |
| Programme versions | v1 draft (zero-hash) `3dd9367f…`; v2 published/approved `f954641a…` |
| Athlete assignment | 1 (`4c0678f3…`) |
| Materialised plan / projection / occurrences | Present for assignment |
| Training sessions / session records | `ts_e=3`, `tsr_e=1` |
| Slot outcomes (completions) | `outcomes_e=1` |
| Schedule operations | `ops_e=14` (includes Gate 1 move/swap/push/skip/undo activity) |

---

## 9. Gate 1 backend/RPC boundary

Gate 1 verified **backend/RPC/application-service contracts** via the
harness `tool/staging/run_s17e_gate1_backend_rpc.py` and existing hosted RPCs.

It did **not** verify finished product UI, Flutter restart UX, or founder UI.

Results classification throughout: `GATE_1_BACKEND_RPC`.

Primary preserved result artifact:
`[REDACTED_PRIVATE_EVIDENCE_PATH]/gate1_results.json` (`gate1_pass=true`, started
`2026-08-09T10:38:57Z`, ended `2026-08-09T10:39:43Z`).

---

## 10. T1–T12 individual results

### T1 — Plan Package — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `import_authored_plan_package`, `publish_cohort_global_programme_version`, `approve_cohort_global_programme_version` |
| Input (redacted) | Rebound package `PROG-S17E-GATE1` v2; content hash prefix `9a5e4cb39fbc5d2c…` |
| Result | `imported_draft` / catalogue publish+approve; version prefix `f954641a…` |
| DB effect | Published+approved v2 with 3 slots; duplicate/immutability exercised |
| Preservation | Unrelated catalogue fixtures retained; see §11 for v1 draft |
| Why PASS | Valid package accepted; genuine malformed probe rejected; immutability/duplicate handled; v2 catalogue-ready |

### T2 — Catalogue / enrolment — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `enrol_athlete_in_catalogue_programme_version` |
| Input | Athlete JWT; `p_programme_version_id=f954641a…` |
| Result | Enrol once; duplicate safe; anon HTTP **401** |
| DB effect | Assignment `4c0678f3…` for Athlete E only |
| Preservation | Other athletes’ assignment counts not reduced |

### T3 — Plan materialisation — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `materialise_athlete_plan_from_enrolment` |
| Result | Materialised; rematerialise idempotent; hash prefix `9a5e4cb39fbc5d2c` |
| DB effect | Materialisation columns set (`athlete_start_programme`) |

### T4 — Materialisation write guard — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | Direct REST PATCH of `programme_assignments` as athlete |
| Result | HTTP **403**; `materialisation_source` remained `athlete_start_programme` |
| Atomicity | Rejected tamper left authoritative materialisation unchanged |

### T5 — Completion / advancement — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `complete_programme_session_and_advance` (+ `training_sessions` create) |
| Result | Authoritative completion present; final successful harness run recorded resume `already_committed` after earlier commit in the Gate 1 session series |
| DB effect | `outcomes_e=1`; cursor advanced (assignment current day left day_1) |
| Limitation | Final `gate1_results.json` captures the **resume** path for T5, not the first-commit response body; first commit is evidenced by durable outcome row + prior run logs in the same Gate 1 authorisation window |

### T6 — Schedule projection — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `ensure_programme_schedule_projection` |
| Result | Stable revision across refresh (`revision=8` at final run snapshot) |

### T7 — Move / swap — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | `cohort_scheduling_apply_fingerprint` + `apply_programme_schedule_operation` |
| Result | `move_ok=true`, `swap_ok=true`, bad fingerprint rejected; revision advanced to 10 |

### T8 — Push / skip — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | Same apply RPC; push uses `fromSessionSlotId` + forward affected set; skip binds cursor |
| Result | Push+skip applied; revision 12 |

### T9 — Undo horizon — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | Undo via apply RPC using `prior_snapshot` for skip undo fingerprint |
| Result | `undo_ok=true`, `undo_code=applied`, stale undo rejected; revision 13 |

### T10 — Restore / reopen — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | Fresh password login + assignment SELECT + projection RPC |
| Result | Assignment restored for Athlete E; **not** a product-UI browser/Flutter restart test |

### T11 — Failure behaviour — **PASS**

| Field | Evidence |
|-------|----------|
| Contract | Malformed apply payload; unauthorised materialise (anon) |
| Result | Both rejected (`malformed_rejected`, `unauth_rejected`) |

### T12 — Preservation — **PASS**

| Field | Evidence |
|-------|----------|
| Result | Ledger 43 / max `20260803180000`; seed absent; E assignments=1; A=1; B=1; C accessed=false; D changed=false |

**Totals: executed 12 · passed 12 · failed 0 · blocked 0**

---

## 11. Zero-hash observation and resolution (complete)

### Locked contract behaviour

In `20260731120000_authored_plan_package_import.sql`,
`import_authored_plan_package`:

1. Validates `package_content_hash` matches **`^[0-9a-f]{64}$`** (lowercase hex format).
2. **Does not** recompute SHA-256 of canonical package JSON inside the RPC.
3. **Stores the caller-supplied hash** on the draft version.
4. Column comment documents the field as “Lowercase SHA-256 of canonical package JSON”; the **compiler/client** is responsible for computing that hash. The RPC trusts `service_role` callers on format + structural validation.

Therefore a 64-character zero hash is **format-valid** under the locked RPC contract.

### Why the zero-hash payload was accepted

An early Gate 1 harness probe substituted
`package_content_hash = "0" * 64` believing that was “malformed.”
The RPC returned success status `imported_draft` / `created_hidden_draft` and
persisted **PROG-S17E-GATE1 version 1** as a draft with hash prefix `0000000000000000`
and a full 3-slot graph (`version_prefix=3dd9367f…`, `lifecycle_status=draft`,
`approved_for_global=false`).

### Defect vs incorrect probe

| Classification | Conclusion |
|----------------|------------|
| RPC contract defect (format)? | **No** — format check correctly accepts any lowercase 64-hex string |
| Semantic hash equality enforced by RPC? | **No** — not implemented in locked migration |
| Incorrectly designed malformed-input probe? | **Yes** — wrong-hash is not an RPC-invalid payload |

T1 is **not** reclassified to FAIL for accepting the zero hash: acceptance matches the
locked RPC format contract. The probe design error is documented as a discrepancy.

### Genuine malformed-input assertion (final T1)

| Item | Value |
|------|--------|
| Payload | Same structural package with **`sessions: []`** |
| Expected | Pre-write `session_resolution_failure` / `sessions_required` |
| Harness record | `malformed_rejected=true` |
| Partial write from this probe | **None required/observed** — empty sessions fail before atomic write section; no additional version beyond the already-existing v1 draft |

### Corrected version-2 package

| Item | Value |
|------|--------|
| Lineage | `PROG-S17E-GATE1` |
| Version number | **2** (explicit bump; not an overwrite of v1) |
| Hash prefix | `9a5e4cb39fbc5d2c…` |
| Version id prefix | `f954641a…` |
| Lifecycle | `published`, `approved_for_global=true` |
| Slots | 3 |

Version 2 is **not** an idempotent retry or replacement of version 1.

### Version-1 draft retention

Read-only post-test inspection (2026-08-09) confirmed v1 still present:

- `version_number=1`, `lifecycle_status=draft`, hash prefix `0000000000000000`,
  `approved_for_global=false`, `slot_count=3`, prefix `3dd9367f…`
- **Not deleted, rewritten, or concealed**

### Namespace isolation of both imports

Both versions sit under lineage code `PROG-S17E-GATE1` (Gate 1 dedicated).
Athlete enrolment/materialisation/completion/schedule ops used **v2** only
(`assignment` → `f954641a…`). Athlete A/B assignment presence unchanged; Athlete C
not accessed; Athlete D not reused for Gate 1.

---

## 12–14. Redacted I/O, DB effects, rejection atomicity

See §10 tables. Additional atomicity:

- Anon enrol → HTTP 401 (no assignment for anon)
- Athlete PATCH tamper → HTTP 403; materialisation source unchanged
- Bad schedule fingerprint / stale undo → non-`applied` status; revision only
  advances on successful applies recorded in results

---

## 15–18. Preservation, Athlete C, ledger, seed

| Check | Result |
|-------|--------|
| Athlete A assignments | 1 (unchanged presence) |
| Athlete B assignments | 1 (unchanged presence) |
| Athlete D | Auth fixture still present (`d_auth=1`); not reused for Gate 1; `athlete_d_changed=false` |
| Athlete C personal access | **false** (harness flag; no C personal SELECT in post-checks) |
| Athlete C modified | **false** |
| Historical completions rewritten | **Not observed** for other athletes; E has exactly one outcome |
| Migration ledger | count **43**, max **`20260803180000`**, nine present, later_than_max **0** |
| Phase 3.1F seed | **Absent** (`seed_n=0`, seed migration not in ledger) |
| Field Manual mutation | **false** |
| Namespace escape | **false** |

Preflight aggregates (before Athlete E): assignments/versions/lineages/tsr =
6/6/6/3; auth_users=7. Post Gate 1 growth is consistent with E + Gate 1 package
activity (ledger/seed unchanged).

---

## 19. Automated validation results (local-only)

Hosted T1–T12 were **not** re-executed for this finalisation.

| Suite | Result |
|-------|--------|
| `s17e_athlete_e_bootstrap_test.py` | **11 passed** / 0 failed / 0 skipped |
| `s17e_athlete_e_bootstrap_dart_test.dart` | **3 passed** / 0 failed / 0 skipped |
| `s17_staging_guard_test.dart` | **12 passed** / 0 failed / 0 skipped |
| `s17e_gate1_harness_guard_test.py` | **15 passed** / 0 failed / 0 skipped |
| `s17e_write_gate1_payload_test.dart` | **1 passed** / 0 failed / 0 skipped |
| Package/compiler identity + import migration contracts | **76 passed** / 0 failed / 0 skipped |
| Catalogue/enrolment contracts | **17 passed** / 0 failed / 0 skipped |
| Materialisation/write-guard contracts | **19 passed** / 0 failed / 0 skipped |
| Completion/advancement contracts | **15 passed** / 0 failed / 0 skipped |
| Python harness syntax compilation | **1 passed** / 0 failed / 0 skipped |
| Prerequisites-recorded Phase 2 safety gate | **6/6 PASS** (from prerequisite evidence; not re-run here) |
| Prerequisites-recorded focused suite | **257 passed** (from prerequisite doc; not fully re-run here) |

No local suite contacted hosted projects for mutation.

---

## 20–22. Application code, deployment, Field Manual

| Item | Result |
|------|--------|
| Production runtime application code changed for Gate 1 | **false** (test-only tooling + docs uncommitted) |
| Application deployed | **false** |
| Field Manual mutated | **false** |
| CLI final link | Cohort Field Manual |

---

## 23–24. Retained Athlete E; product-UI Gate 2

| Item | Result |
|------|--------|
| Athlete E retained | **true** |
| Cleanup | **false** |
| Product-UI Gate 2 | **Not verified / not authorised** |

---

## 25. Risks, discrepancies, evidence limitations

1. **Incorrect early malformed probe (zero-hash)** created retained v1 draft; final
   malformed probe is empty `sessions` (correct). Documented in §11; T1 remains PASS
   under locked RPC format semantics.
2. **RPC does not enforce semantic hash = canonical SHA-256** — product/architecture
   intent lives in compiler; founders may later decide whether to tighten RPC.
3. **Final `gate1_results.json` T5** records resume/`already_committed` rather than the
   first-commit RPC body; durable outcome count proves completion occurred.
4. **Schedule ops volume** (`ops_e=14`) includes iterative harness attempts within the
   authorised Gate 1 window before the final all-PASS run; not cleaned up.
5. **Athlete D “unchanged”** is presence/non-reuse evidence, not a full row-hash of all
   D tables.
6. Report filename canonicalised to
   `Phase_1_2_to_1_7_Staging_Gate_1_Verification_v1.md` (underscore form).
7. **Post-verification harness hardening:** before permanent commitment, the
   reusable harness received local-only guards requiring the typed compiled
   identity `PROG-S17E-GATE1` version 2, the bootstrap-defined Athlete E marker
   and identity binding, and an explicit service-role operation allow-list.
   Full protected-athlete identifiers and exact private runtime paths were
   removed. These guards were **not** retrospectively claimed to have existed
   during the completed hosted run.
8. No hosted operation was rerun during remediation. The original Gate 1
   evidence and outcome were not rewritten: the retained v1 zero-hash draft and
   the separate accepted v2 package remain documented exactly as observed.

---

## 26. Exact next founder decision

**Founder acceptance** of the recovered worktree and committed Phase 1.2–1.7
Staging Gate 1 evidence, followed by a separate decision on the next authorised
operation.

Do **not** begin Field Manual uplift, Phase 3.1F seed apply,
`founder_programme_yaml_import`, product-UI Gate 2, application deployment, or
Athlete E cleanup without new authorisation.

---

## Related documents

- [`Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md`](./Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md)
- [`Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md`](./Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md)
- [`Phase_1_2_to_1_7_Staging_Uplift_Plan_v1.md`](./Phase_1_2_to_1_7_Staging_Uplift_Plan_v1.md)
- [`Authored_Plan_Package_v1.md`](./Authored_Plan_Package_v1.md)
