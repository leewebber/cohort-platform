# Sprint 1.7 Athlete D Staging Harness

**Status:** B4c local remediation complete. Hosted resume verification remains
separately authorised (B4d).

**Harness tip (B4a):** `c9bf996`  
**Remediation branch (local):** `codex/b4c-staging-harness-remediation`

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

Flutter also remained alive after JSON capture (runner termination defect).

## Diagnosed causes (B4c)

### `<2` scheduled occurrences (F–J)

**Root cause: authored programme insufficient slots (harness/fixture).**

`PROG-S13-ELIG` is the Self-Test 1 **one-slot** package. Ensure/restore
correctly projects one occurrence. Horizon/date filtering did **not** exclude
rows. This is not classified as a product scheduling defect.

**Remediation:** Athlete D-owned preparation enrols/switches onto the published
multi-slot catalogue lineage `PROG-S15A-STAGING` through athlete-authenticated
catalogue APIs, then re-asserts ≥2 uncompleted occurrences. Fail closed if
preparation cannot establish the baseline. Does **not** mutate published
programmes or create another athlete.

### C / D / K

Previously intentionally non-automated. B4c adds headless automation through
the same application services the athlete UI uses (completion submit, previous
performance resolver, adaptation propose/accept/reject).

### Runner hang

B4c requires `S17_FLUTTER_COMPLETE exit=<n>` after JSON, then runner-owned
graceful SIGTERM / forced SIGKILL. Missing sentinel → non-zero exit even if
JSON was captured.

## Resume-only workflow (retained Athlete D)

Do **not** rerun the live creator.

Retained marker: `s17_stage_20260803T065749Z_55ec68c6`  
Private defines file path only (never inspect/edit contents in chat).

### Prerequisites

1. `CONFIRM_COHORT_STAGING=1`
2. Private `flutter_dart_defines.json` mode `600`, outside Git, not a symlink
3. Cohort Staging identity confirmed by runner guards
4. Identity + assignment isolation prerequisites inside the Flutter entrypoint

### Dry-run resume (no Flutter)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run
```

### Execute resume (B4d only)

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
* records `PREREQ_*` separately from journey results
* default order F→G→H→I→J→K→C→D (K before C for prior-result dependency)

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
* B4b evidence under `/tmp/b4b_*`
* B3a backup
* staging operations worktree
* B4a/B4c harness worktrees

Do not delete Athlete C. Production remains rejected (`otnhhdxs…` /
Cohort Field Manual).
