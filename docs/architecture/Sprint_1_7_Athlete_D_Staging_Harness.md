# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.1 local preparation remediation complete. A single B4d retry
requires separate founder authorisation. Do not execute another live run from
this document alone.

**Harness tip (B4a):** `c9bf996`  
**B4c remediation:** `f58f55c` (`codex/b4c-staging-harness-remediation`)  
**B4d.1 remediation branch (local):** `codex/b4d-preparation-remediation`

## B4b partial result

| Journey | Result | Cause class |
|---------|--------|-------------|
| A | PASS | — |
| B | PASS | — |
| C | BLOCKED | Tooling — previous-performance not automated |
| D | BLOCKED | Tooling — accept/reject not automated |
| E | PASS | — |
| F–J | BLOCKED | Fixture — `<2` uncompleted occurrences |
| K | BLOCKED | Tooling — completion path not automated |

## B4d blocked result (hosted resume)

Retained Athlete D marker: `s17_stage_20260803T065749Z_55ec68c6`

| Item | Observed |
|------|----------|
| Intended preparation programme | `PROG-S15A-STAGING` |
| Observed programme after B4d | `PROG-S13-ELIG` (version prefix `e9bd7e19…`) |
| Uncompleted occurrences | 1 |
| PREREQ_IDENTITY | PASS |
| PREREQ_BASELINE | FAIL (`authoredProgrammeInsufficientSlots`) |
| Selected journeys C/D/F–K | FAIL |
| Journey E in resume report | Incorrectly recorded PASS (should be prerequisite-only) |

Multi-slot preparation **did not take effect**. Creator was never invoked.
Production untouched. No cleanup authorised.

### Diagnosed first failing boundary (B4d.1)

**Classification: harness/tooling defect.**

B4c added `S17SchedulePreparation` with fail-closed stages, but
`lib/main_s17_staging_verify.dart` used an **inline** enrol/switch path that:

1. Looked up `PROG-S15A-STAGING` in the athlete catalogue.
2. On empty match, enrol failure, or ignored materialisation result, **silently
   continued** on `PROG-S13-ELIG`.
3. Reported only the downstream baseline failure — no preparation stage,
   no enrol/switch classification, no assignment/package/materialisation
   postconditions.
4. Still entered C/D/K after baseline failure.
5. Always wrote journey **E** as PASS, including in resume mode.

Retained B4d evidence therefore cannot distinguish catalogue absence from
enrol rejection; the harness omitted the failure. Staging catalogue presence of
`PROG-S15A-STAGING` remains to be confirmed by a fail-closed retry (read-only
Athlete D diagnostics were not used: private defines must not be opened under
B4d.1, and no alternate read-only boundary was available without that file).

## Required preparation postconditions (fail-closed)

Preparation must stop before C/D/F–K unless every stage passes:

| Stage | Postcondition |
|-------|----------------|
| Catalogue | Exact lineage `PROG-S15A-STAGING` visible and eligible |
| Target identity | Version ≠ current one-slot; not `PROG-S13-ELIG` |
| Enrol/switch | Response success classified; reject/malformed → fail |
| Assignment | Active assignment lineage/version = intended programme |
| Package | Materialised package hash belongs to intended version |
| Materialisation | Start Programme success |
| Prepared execution | Prepare resolves intended assignment/version |
| Projection/restore | Reconstruction retains intended lineage |
| Occurrences | ≥2 uncompleted |
| Fallback guard | Never silently continue on `PROG-S13-ELIG` |

Failures report `PREP_FAIL stage=<name> …` under `PREREQ_PREP` /
`PREREQ_BASELINE`. Journey E must **not** appear as PASS in resume mode.

## Resume-only workflow (retained Athlete D)

Do **not** rerun the live creator. B4d.1 does **not** authorise a retry.

Retained marker: `s17_stage_20260803T065749Z_55ec68c6`  
Private defines file path only (never inspect/edit contents in chat).

### Prerequisites

1. `CONFIRM_COHORT_STAGING=1`
2. Private `flutter_dart_defines.json` mode `600`, outside Git, not a symlink
3. Cohort Staging identity confirmed by runner guards
4. Identity + preparation postconditions inside the Flutter entrypoint

### Proposed dry-run resume (do not execute under B4d.1)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run
```

### Proposed single live resume (separate founder authority only)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=C,D,F,G,H,I,J,K \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume
```

Resume mode:

* never invokes `create_s17_athlete_d_fixture.sh`
* never searches for athletes by email/name/marker
* authenticates only from the supplied private config
* records `PREREQ_A`, `PREREQ_B`, `PREREQ_E`, `PREREQ_PREP`, `PREREQ_BASELINE`
  separately from journey results
* never records journey E as PASS unless E was explicitly selected under
  separate non-resume authority
* default order F→G→H→I→J→K→C→D (K before C for prior-result dependency)
* stops before C/D/F–K when any preparation postcondition fails

## Report / exit semantics

1. App prints `S17_FLUTTER_JOURNEY_JSON {...}`
2. App prints `S17_FLUTTER_COMPLETE exit=<0|1>`
3. Runner captures JSON, terminates Flutter, exits:
   * `0` — all selected journeys PASS
   * `1` — report ok=false
   * `2` — refused
   * `3` — timeout / missing sentinel
   * `4` — malformed report

## Retention / cleanup

Retain until separately authorised:

* Athlete D identity and private credential directory
* B4b / B4d evidence under `/tmp/b4b_*`, `/tmp/b4d_*`, `/tmp/s17_flutter_staging_report_b4*.txt`
* B3a backup (`/private/tmp/cohort_staging_p1_b3a_backup.JGk5Mbqd`) — do not open/restore/delete
* staging operations worktree
* B4a / B4c / B4d.1 harness worktrees

Do not delete Athlete C. Production remains rejected (`otnhhdxs…` /
Cohort Field Manual). No migration, schema, or deployment from this harness.
