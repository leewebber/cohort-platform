# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.5 targeted reverification of corrected G/H and isolated I→J.
Another retry beyond the single authorised B4d.5 dry+live pair is **not**
authorised.

**B4d.3 live-assignment bind:** `1607d7d`  
**B4d.4 journey diagnosis:** `c4c655f`  
**B4d.5 targeted reverification branch:** `codex/b4d5-targeted-reverification`

## B4d.4 conclusions (accepted)

| Journey | Classification |
|---------|----------------|
| G | Harness/order contamination (same-date after F Move+1) |
| H | Harness invalid probe wrong under NULL unbounded horizon |
| I | Skip passed |
| J | Residual Undo boundary (incomplete inverse vs revision) |
| D | Expected `noSafeAdaptation` fixture eligibility — **do not run in B4d.5** |

## B4d.5 targeted matrix

```text
Selected: G,H,I,J
Order:    G → H → I → J
```

F, C, K, D must not execute. Adaptation must not execute.

### Contracts

* **G:** reload; distinct-date uncompleted pair; invalid (A,A) atomic; valid
  swaps both dates; stop downstream if G does not PASS.
* **H:** report bounded vs `UNBOUNDED_NULL_HORIZON`; valid +1 push; invalid
  probe **`dayDelta <= 0` only** (never large positive under NULL horizon).
* **I:** fresh Skip; record redacted source + pre-Skip revision + latest undo type.
* **J:** reload; require latest undo == that Skip; typed failure classes:
  `NO_UNDO_RECORD`, `LATEST_NOT_SKIP`, `INCOMPLETE_INVERSE_SNAPSHOT`,
  `REVISION_MISMATCH`, `UNDO_REJECTED`, `UNDO_APPLIED_POSTCONDITION_FAILED`.

### Preparation

Resume binds live `PROG-S15A-STAGING`. Enrol/switch/`replaceActive` forbidden.
If already materialised, **do not rematerialise** — reuse and validate only.

## Dry-run / live (B4d.5 only)

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=G,H,I,J \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run

CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=G,H,I,J \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume
```

Exactly one dry run and at most one live run. No retry.

## Next authority (after B4d.5)

| Result | Next |
|--------|------|
| G/H/I/J all PASS | B4d.6 adaptation-eligible fixture + Journey D only |
| J = `INCOMPLETE_INVERSE_SNAPSHOT` | Local Skip inverse product remediation; no staging retry |
| J revision/postcondition | Smallest local diagnosis of that typed boundary |
| G or H FAIL | Diagnose corrected contract; no retry |

B4e remains blocked until D and all required release journeys have passing
staging evidence. Production remains rejected.
