# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.12 local harness baseline-semantics remediation (no staging
contact).

**B4d.8 diagnosis SHA:** `bc972e6e3f97d6706370abc9e4a530fac9b5246b`  
**B4d.9 branch:** `codex/b4d9-undo-cursor-bind`  
**B4d.9 SHA:** `5f5ab26962b2e31cc30f898267e49a31780870d1`  
**B4d.12 branch:** `codex/b4d12-baseline-labels`

## Baseline semantics (B4d.12)

Authored executable slot count and current uncompleted executable occurrence
count are different values.

* **Authored executable slots** — executable slots defined by the authored
  programme/package. Reported only from an authoritative authored-plan source.
  When unavailable: `authored_executable_slot_count: null` with
  `authored_executable_slot_count_status: notEvaluated`. Never derived from
  projected, executable, remaining, scheduled, completed, skipped, or
  uncompleted occurrence counts.
* **Current uncompleted executable occurrences** —
  `current_uncompleted_executable_occurrence_count` on the live assignment.
  This is the value the I→J preparation gate evaluates.

The I→J baseline gate requires at least two current uncompleted executable
occurrences. A baseline insufficiency does **not** prove an authored programme
insufficiency.

### Typed classification

| Situation | Cause |
| --- | --- |
| Authored count known and `< 2` | `authoredProgrammeInsufficientSlots` |
| Current uncompleted executable occurrences `< 2` (authored not proven insufficient) | `currentBaselineInsufficientExecutableOccurrences` |

S13 Self-Test 1 one-slot wording is emitted only when lineage is
`PROG-S13-ELIG` and authored insufficiency is independently known. S15A live
identity must not emit that wording merely because the current uncompleted
count is one.

Report fields (PREREQ_BASELINE detail / snapshot `toReportFields()`):

```text
authored_executable_slot_count
authored_executable_slot_count_status
current_uncompleted_executable_occurrence_count
projected_occurrence_count
completed_or_skipped_count
lineage_code
```

B4d.12 is a local harness labeling/classification remediation. It is **not**
Journey J staging evidence (`J_STAGING_VERIFIED = false`).

## B4d.8 accepted conclusions

* Primary: `HARNESS_REQUEST_CONSTRUCTION` — J `reloadSnapshot()` omitted cursor
* Secondary: `HARNESS_TYPED_RESULT_COLLAPSED`
* Product Skip/Undo defects: not proven
* Staging retry: unsafe until remediation

## B4d.9 remediation

### Cursor bind (primary)

Journey J now:

1. Reloads current assignment projection after I PASS
2. Loads authoritative live assignment cursor coordinates
3. Resolves to exactly one occurrence (`resolveAuthoritativeLiveCursor`)
4. Fail-closes on missing / malformed / unresolvable / ambiguous / stale
5. Binds cursor into the Undo snapshot before preview/apply
6. Uses the same snapshot for preview fingerprint and apply command

Revision contract unchanged: Undo expected revision = post-Skip current
(B4d.7-shaped: **6**).

### Typed reporting (secondary)

Journey J detail preserves `status=`, `code=`, `apply_invoked=`,
`cursor_bound=`, `expected_revision=`, and typed classification. Opaque
`apply unsuccessful` is not emitted when a typed result exists.

## Next authority

```text
Under a separate authority, run exactly one fresh cursor-aligned I→J staging
evidence chain against the restored Athlete D baseline: one Skip, one immediate
Undo, no retries, with complete typed restoration evidence.
Do not combine that run with Journey D.
```

Do not combine with Journey D. B4e remains blocked until J and D have valid
staging evidence. Production rejected.
