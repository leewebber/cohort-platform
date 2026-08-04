# Sprint 1.7 Athlete D Staging Harness

**Status:** B4d.14 local Journey J Undo revision-contract + aggregate
restoration-reporting remediation (no staging contact).

**B4d.8 diagnosis SHA:** `bc972e6e3f97d6706370abc9e4a530fac9b5246b`  
**B4d.9 SHA:** `5f5ab26962b2e31cc30f898267e49a31780870d1`  
**B4d.12 SHA:** `f66f0b45cc25918bc6accb6c1fb20b8fb3a8ceca`  
**B4d.14 branch:** `codex/b4d14-undo-revision-contract`

## Undo revision and restoration (B4d.14)

Undo restores logical schedule state through a **new** authoritative schedule
revision. The product contract
(`Athlete_Controlled_Programme_Scheduling_v1` +
`apply_programme_schedule_undo`) advances revision as **N→N+1**, where N is the
expected/current post-Skip revision used for Undo apply.

The verifier must **not** require the post-Undo revision identifier to equal
the pre-Skip revision identifier. Revision correctness and logical state
restoration are independent required postconditions.

### Revision rule

```text
expected apply revision == authoritative post-Skip revision
apply result schedule_revision == expected apply revision + 1
post-J reload schedule_revision == apply result schedule_revision
```

Legacy `post-J revision == pre-I revision` must not determine PASS.

### Aggregate restoration reporting

After successful reload and reconstruction, all restoration comparisons are
evaluated and reported without first-failure short-circuiting:

```text
revision_contract_ok
target_identity_restored
target_disposition_restored
target_date_restored
target_reversible_state_restored
cursor_restored
unrelated_occurrences_unchanged
assignment_identity_unchanged
programme_version_identity_unchanged
lineage_identity_unchanged
complete_restoration_ok
failed_postconditions
expected_apply_revision
apply_result_revision
reloaded_revision
```

`J_STAGING_VERIFIED` requires positive Undo apply, successful reload and
reconstruction, valid revision-contract behavior, and complete logical
restoration. Apply success alone is insufficient.

B4d.13 remains `I_STAGING_VERIFIED` with
`J_STAGING_APPLIED_POSTCONDITION_FAILED`. B4d.14 does **not** convert B4d.13
into Journey J staging PASS (`J_STAGING_VERIFIED = false` until a fresh
staging chain).

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

## B4d.8 accepted conclusions

* Primary: `HARNESS_REQUEST_CONSTRUCTION` — J `reloadSnapshot()` omitted cursor
* Secondary: `HARNESS_TYPED_RESULT_COLLAPSED`
* Product Skip/Undo defects: not proven

## B4d.9 remediation

### Cursor bind (primary)

Journey J now:

1. Reloads current assignment projection after I PASS
2. Loads authoritative live assignment cursor coordinates
3. Resolves to exactly one occurrence (`resolveAuthoritativeLiveCursor`)
4. Fail-closes on missing / malformed / unresolvable / ambiguous / stale
5. Binds cursor into the Undo snapshot before preview/apply
6. Uses the same snapshot for preview fingerprint and apply command

Undo expected revision = post-Skip current. Successful Undo then advances
revision N→N+1 (B4d.14).

### Typed reporting (secondary)

Journey J detail preserves `status=`, `code=`, `apply_invoked=`,
`cursor_bound=`, `expected_revision=`, and typed classification. Opaque
`apply unsuccessful` is not emitted when a typed result exists.

## Next authority

```text
Under a separate authority, first perform a non-mutating Athlete D preflight.
If and only if the deterministic baseline still contains at least two suitable
uncompleted executable S15A occurrences, run exactly one fresh contiguous I→J
staging chain: one Skip, one immediate Undo, no retries, with complete aggregate
restoration reporting.
Do not repair, rematerialise, or mutate Athlete D during preflight.
Do not combine this run with Journey D.
```

B4e remains blocked until Journey J and Journey D both have valid staging
evidence. Production rejected.
