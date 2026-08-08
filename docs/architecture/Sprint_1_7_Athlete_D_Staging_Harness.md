# Sprint 1.7 Athlete D Staging Harness

**Status:** Phase 1 Release Gate **B4e complete**. Athlete D staging matrix
evidence satisfies the B4 contract; Phase 1 is closed.

```text
PHASE_1_GO=true
PHASE_1_CLOSED=true
B4e=complete
```

**Closing harness HEAD reviewed (B4e):** `7ba84557a4f0706e82db6ad6c7b4edf9252b4f20`  
**B4d.15 I→J SHA:** `e4785ab839b579264ebfeb06589e03e696b95ec8`  
**Journey D marker:** `s17_jd_adapt_20260808T065203Z_cbe6b6cf`

Production rejected throughout. No further Phase 1 staging, fixture or
hardening task is required.

## B4e closure summary

| Journey | Evidence | Result |
|---------|----------|--------|
| A–B, E | B4b Athlete D create/verify | PASS (prior) |
| C, F, K | Earlier B4d resume runs | PASS (prior) |
| G, H | B4d.5 | PASS (prior) |
| I, J | B4d.15 fresh contiguous I→J (`/tmp/b4d15_journey_report.json`) | PASS (`complete_restoration_ok=true`) |
| D | Dedicated PROG-S17-JD-ADAPT fixture + execute + outcome @ `7ba8455` | PASS (`outcome_verified=true`) |

Journey D was verified on a dedicated adaptation fixture (not combined with the
Athlete D I→J chain), matching the prior authority that forbade combining D
with I→J on the same run.

### Journey D proof boundary

Canonical Phase 1 persistence
([`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)):
accepted adaptation is stored with the **local prepared package**; Sprint 1.6
does **not** require a new server adaptation table.

Therefore:

```text
adaptation_state_count=0
hosted evidence write=1
prepared-package apply invoked once
outcome_verified=true
```

is the intended staging proof boundary, not a missing hosted adaptation-state
defect.

Closure-path Journey D entry attempts before success: **3** (freshness, then
StateError observability/integrity repairs, then verified success). Historical
failed attempts are retained in `/tmp/jd_staging_validation_evidence/`.

Final Journey D harness repairs on the reviewed tip:

- `b7cf0f4` — acceptance freshness uses curated knowledge parity
- `43e0e69` — staged failure observability; GoTrue evidence PUT 200\|201
- `7ba8455` — LATER integrity uses `protocol_id` / `session_id=protocol_id`

## Undo revision and restoration (B4d.14 retained)

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
```

B4d.15 confirmed `complete_restoration_ok=true` with
`legacy_rewind_would_pass=false`.

## Next authority

```text
Phase 2 — Architecture Consolidation
No further Phase 1 validation, staging, fixture or hardening task is required.
```

Optional separately authorised non-Phase-1 cleanup: realign stale Journey D
shell/diagnosis tests with poisoned-marker fail-closed precedence. Production
remains rejected unless explicitly authorised.
