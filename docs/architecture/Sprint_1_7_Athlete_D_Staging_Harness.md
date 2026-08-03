# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.2 local diagnosis complete. Another B4d dry/live retry is **not**
authorised by B4d.2. Choose the next authority from the diagnosis classification.

**Harness tip (B4a):** `c9bf996`  
**B4c remediation:** `f58f55c`  
**B4d.1 remediation:** `4ae9ba1` (`codex/b4d-preparation-remediation`)  
**B4d.2 diagnosis branch (local):** `codex/b4d2-materialisation-diagnosis`

## B4d retry result (hosted)

Retained marker: `s17_stage_20260803T065749Z_55ec68c6`

| Item | Result |
|------|--------|
| Catalogue / target | Reached `PROG-S15A-STAGING` |
| Enrol/switch | Success path + assignment postcondition |
| **First failing boundary** | **`materialisation`** |
| C/D/F–K | Cascading prep FAIL (not meaningfully executed) |
| Journey E | NOT RUN (prerequisite-only) — corrected |
| PREREQ_A | Opaque FAIL (`Isolation/auth scope failed`) — ambiguous |

Assignment success is **not** materialisation success. After B4d retry Athlete D
is likely in a **mid-switch** state: active enrolment on `PROG-S15A-STAGING`
without successful materialisation (previous S13 reassigned).

## B4d.2 diagnosis (local + optional read-only)

### Materialisation

**Call path:** `S17PlanMaterialiseAdapter` →
`AthletePlanMaterialisationService.startProgramme` →
RPC `materialise_athlete_plan_from_enrolment`.

**Reporting defect (proven tooling):** the adapter previously collapsed the typed
result to `bool`, discarding `status` / stable `code` (e.g.
`timezone_unavailable`, `invalid_package_integrity`,
`active_materialised_programme_exists`).

**Likely tooling cause (strong, pending status capture on next authorised run):**
enrol/materialise adapters omitted timezone. Creator fixture used `UTC`. Product
RPC fails closed with `validation_failure` / `timezone_unavailable` when both
`p_timezone` and `assignment.timezone` are null. B4d.2 wires `UTC` into the
staging adapters and retains safe status/code in `PREP_FAIL` detail.

**Product defect proven?** No — typed rejection without captured code is not
enough to prove a product contract break.

### PREREQ_A isolation ambiguity

Prior check collapsed auth + own-row + foreign-probe into one FAIL string.

Corrected semantics (independent components):

| Component | Meaning |
|-----------|---------|
| AUTH | Sign-in / Athlete D session |
| OWN | Active own assignment visible and owned |
| FOREIGN | Athlete-only empty probe for `athlete_id != self` |

- `PASS` only when AUTH+OWN+FOREIGN all pass.
- Foreign probe empty under athlete SELECT policy ⇒ FOREIGN PASS.
- Foreign row visible ⇒ FOREIGN FAIL (isolation breach suspected; stop).
- Coach/dual-role ⇒ FOREIGN/OWN **UNSUPPORTED** (coach policy can see athletes);
  overall **BLOCKED**, never PASS.
- Probe error ⇒ FOREIGN **UNCERTAIN**; overall **BLOCKED**, never PASS.

The foreign probe must not enumerate athletes, print foreign ids, or use
Athlete C.

### Safe materialisation status capture

Future prep failures report:

```text
PREP_FAIL stage=materialisation kind=<…> status=<…> code=<stable> …
```

Never log credentials, tokens, emails, full UUIDs, or raw exception bodies.

## Read-only diagnostic (B4d.2)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  ./tool/staging/diagnose_s17_athlete_d_readonly.sh
```

Read-only. No enrol/switch/materialise/prepare/projection. Creator forbidden.

## Next authority (choose one; do not improvise)

| Classification | Next step |
|----------------|-----------|
| Tooling (timezone / status capture) — implemented locally | Separately authorise **one** B4d retry after reviewing B4d.2 |
| Staging-state (partial S15A enrolment) | Athlete D state repair / resume materialisation only |
| Staging-data (package ineligible) | Representative data repair (not catalogue mutation ad hoc) |
| Product defect | Product remediation with contract tests |
| Isolation/security | Security remediation; stop staging athlete work |

**Do not** run another B4d retry under B4d.2. B4e remains blocked.

## Resume workflow (retained Athlete D)

Do **not** rerun the live creator.

### Prerequisites

1. `CONFIRM_COHORT_STAGING=1`
2. Private `flutter_dart_defines.json` mode `600`, outside Git, not a symlink
3. Cohort Staging identity confirmed by runner guards
4. Classified PREREQ_A + preparation postconditions

### Proposed dry-run / live (separate founder authority only)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=C,D,F,G,H,I,J,K \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run

CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=C,D,F,G,H,I,J,K \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume
```

## Report / exit semantics

1. `S17_FLUTTER_JOURNEY_JSON {...}`
2. `S17_FLUTTER_COMPLETE exit=<0|1>`
3. Runner exits `0` only if selected journeys PASS; missing sentinel → `3`

## Retention / cleanup

Retain until separately authorised:

* Athlete D identity and private credential directory
* B4b / B4d / B4d-retry / B4d.2 evidence under `/tmp/b4*`
* B3a backup — do not open/restore/delete
* B4a / B4c / B4d.1 / B4d.2 harness worktrees

Production remains rejected. No migration, schema, or deployment from this harness.
