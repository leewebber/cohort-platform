# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.3 binds resume to Athlete D’s authenticated live
`PROG-S15A-STAGING` assignment. One dry-run + one live resume for
`C,D,F,G,H,I,J,K` is authorised under B4d.3 only.

**Harness tip (B4a):** `c9bf996`  
**B4c remediation:** `f58f55c`  
**B4d.1 remediation:** `4ae9ba1` (`codex/b4d-preparation-remediation`)  
**B4d.2 diagnosis:** `9e175f3` (`codex/b4d2-materialisation-diagnosis`)  
**B4d.3 live-assignment retry branch:** `codex/b4d3-live-assignment-retry`

## B4d.2 established facts (accepted)

| Item | Fact |
|------|------|
| First failed boundary | materialisation |
| Primary classification | tooling/reporting (missing timezone; discarded typed status) |
| Athlete D active programme | `PROG-S15A-STAGING` |
| Enrolled / materialised | true / false |
| Isolation AUTH/OWN/FOREIGN | PASS (breach disproven) |
| Private defines | may still contain stale S13 assignment identities |

## B4d.3 resume design — live-assignment binding

Resume mode must:

1. Authenticate only as retained Athlete D.
2. Read Athlete D’s own active enrolment via supported application interfaces.
3. Require live programme code exactly `PROG-S15A-STAGING`.
4. Bind assignment / version / lineage from that live state in memory.
5. Supersede stale S13 define assignment/package identities (do not rewrite the
   private file).
6. Refuse any fallback to `PROG-S13-ELIG`.
7. Skip creator, athlete discovery, enrol, switch, and `replaceActive`.
8. Materialise **only** the existing S15A enrolment with explicit timezone `UTC`.
9. Continue to C/D/F–K only after positive materialisation and prepared-execution
   postconditions.

Private defines remain the guarded source for authentication and connection
configuration only.

## Resume workflow (retained Athlete D)

Do **not** rerun the live creator. Do **not** edit private defines.

### Prerequisites

1. `CONFIRM_COHORT_STAGING=1`
2. Private `flutter_dart_defines.json` mode `600`, outside Git, not a symlink
3. Cohort Staging identity confirmed by runner guards
4. Live assignment must be `PROG-S15A-STAGING` (enrolled-but-not-materialised OK)
5. Classified PREREQ_A / AUTH / OWN / FOREIGN + preparation postconditions

### Dry-run then live (B4d.3)

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

Dry-run must print (among identity guards):

```text
LIVE_ASSIGNMENT_BINDING=enabled
STALE_DEFINE_IDENTITIES=non_authoritative
TARGET_LINEAGE=PROG-S15A-STAGING
EXISTING_ENROLMENT_MATERIALISATION_PATH=selected
ENROL_SWITCH_REPLACE_ACTIVE=forbidden
TIMEZONE_CONTRACT=UTC_required
FAIL_CLOSED_PREPARATION=enabled
```

Exactly **one** live resume is authorised. Do not retry on failure.

## Prerequisites vs journeys

Report separately:

```text
PREREQ_A / PREREQ_AUTH / PREREQ_OWN / PREREQ_FOREIGN
PREREQ_B / PREREQ_E / PREREQ_PREPARATION / PREREQ_BASELINE
```

A/B/E are prerequisite-only in resume mode and must never appear as selected
journey passes. Selected matrix is exactly `C,D,F,G,H,I,J,K`.

## Report / exit semantics

1. `S17_FLUTTER_JOURNEY_JSON {...}`
2. `S17_FLUTTER_COMPLETE exit=<0|1>`
3. Runner exits `0` only if selected journeys PASS; missing sentinel → `3`;
   malformed report → `4`

## Retention / cleanup

Retain until separately authorised:

* Athlete D identity and private credential directory
* B4b / B4d / B4d-retry / B4d.2 / B4d.3 evidence under `/tmp/b4*`
* B3a backup — do not open/restore/delete
* B4a / B4c / B4d.1 / B4d.2 / B4d.3 harness worktrees

Production remains rejected. No migration, schema, or deployment from this harness.
