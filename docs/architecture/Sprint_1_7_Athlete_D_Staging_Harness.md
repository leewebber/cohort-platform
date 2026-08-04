# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.7 cursor-aligned Skip→Undo staging reverification.
Exactly one dry run + one live run for `I,J` only.

**B4d.6 skip diagnosis:** `ade38b8`  
**B4d.7 branch:** `codex/b4d7-cursor-skip-undo`

## B4d.6 accepted conclusions

* Primary: `HARNESS_INELIGIBLE_SELECTION` (first-uncompleted + null cursor)
* Secondary: typed-result collapse
* Product Skip defect: not proven
* Local remediation: cursor into snapshot, prefer cursor, typed I failures

## B4d.7 matrix

```text
Selected: I,J
Order:    I → J
```

G/H/D/C/F/K must not execute.

### Contracts

* **I:** reload; require non-null cursor; select cursor occurrence only;
  refuse first-uncompleted fallback; typed preview/apply; pass only if exact
  cursor occurrence is skipped and unrelated occurrences unchanged.
* **J:** only if I PASS; latest undo must be the **fresh** B4d.7 Skip
  (type + base/result revision + slot); restore **complete** pre-I state.

### Dry-run / live

```bash
CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=I,J \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run

CONFIRM_COHORT_STAGING=1 \
  S17_DART_DEFINES_FILE=<private>/flutter_dart_defines.json \
  S17_SELECTED_JOURNEYS=I,J \
  ./tool/staging/run_s17_flutter_staging_verify.sh --resume
```

Exactly one dry + at most one live. No retry. No product Skip/Undo change.

## Next authority

| Result | Next |
|--------|------|
| I+J PASS | B4d.8 adaptation-eligible fixture + Journey D |
| I typed product failure | Local diagnosis/remediation; no staging retry |
| J typed failure after I PASS | Local Undo diagnosis; no staging retry |
| Cursor absent/ineligible | Separately authorised deterministic-state prep |

B4e remains blocked. Production rejected.
